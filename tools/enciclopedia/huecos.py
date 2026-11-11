#!/usr/bin/env python3
"""Huecos de la enciclopedia: lo que falta en cada tema dentro del lugar y la época que ya se investigaron.

Cada paquete es un tema investigado en un lugar y una época: su «alcance» (regiones, años, ejes y profundidad). Este
programa recorre todos los paquetes y lista lo que falta adentro de cada alcance, para rellenarlo por rondas hasta que
no quede ningún hueco. No escribe contenido: lo encuentra, lo ordena por prioridad y lo reparte en lotes. Lo nuevo se
escribe en el formato compacto (tools/enciclopedia/compacto/FORMATO.md) y se suma al paquete con `aplicar`.

Detectores sin red:
  capas        eras, religiones, culturas e idiomas de cada región investigada: años sin era o sin entrada
               mayoritaria, y regiones investigadas sin esas capas
  tramos       tramos de años sin hechos ni fuentes del paquete en una región de su alcance, entre tramos que sí tienen
  referencias  autor sin autor_id, obras sin sincronizar, hechos sin fuentes ni coordenadas, fuentes sin enlace de
               lectura o sin lugar de escritura
Detectores con red (--red: Wikipedia y Wikidata vía QLever, con caché en tools/enciclopedia/huecos/cache/):
  series       cargos (P39) con titulares en tmap: los que faltan entre el primero y el último que están
  sucesiones   hechos y obras encadenados (P155/P156): los eslabones que faltan
  partes       partes (P361) de un conjunto que el tema ya trató parte por parte: las batallas de una guerra…
  obras        obras (P50) de autores que ya tienen ficha, al menos tan notables como las fuentes del paquete
  candidatos   hechos de los ejes del paquete (batallas, tratados, revoluciones…) y personas de sus ocupaciones,
               ubicados en sus regiones y sus años, al menos tan notables como lo que ya tiene

La notabilidad se mide en Wikipedias (los sitelinks de Wikidata). La «profundidad» de un paquete es el cuartil
inferior de las Wikipedias de lo que ya tiene en cada sección: un candidato al menos así de notable es un hueco, uno
menos notable no. Alcance y profundidad se fijan en alcances.json (`alcances --fijar`) para que las rondas converjan:
si se recalcularan después de cada ronda, cada ronda bajaría la vara y la búsqueda no terminaría nunca.

Lo que se decide no rellenar (fuera del tema, sin datos verificables) se anota con `decidir` en decisiones.json y no
vuelve a aparecer. Lo que se rellena desaparece solo: los detectores comparan por QID, por id y por años.

Uso:
  huecos.py informe [--red] [--paquete P]... [--detector D]... [--prioridad alta|media|baja] [--json F] [--todos]
  huecos.py lotes <carpeta> [las mismas opciones]    un .md y un .json por paquete, para quien rellena
  huecos.py alcances [--fijar] [--rehacer P]... [--red]
  huecos.py decidir <clave> <descartado|sin-datos> <motivo>
  huecos.py decidir --archivo <decisiones.json>       lista de {"clave", "decision", "motivo"}
  huecos.py arreglar [--escribir]                     autor_id y obras: lo mecánico y seguro
  huecos.py aplicar <carpeta del tema> <paquete> [--escribir]
               suma al paquete salida.json (de construir.py --tema), familias-nuevas.json y parches.json

--prioridad muestra esa prioridad y las más altas (por defecto, media). --todos muestra también lo ya decidido.
Sin --escribir, `arreglar` y `aplicar` solo muestran lo que harían. Solo usa la biblioteca estándar.
"""

from __future__ import annotations

import hashlib
import json
import re
import socket
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

# IPv4 primero: con IPv6 roto (pasa en algunas redes), urllib espera el timeout entero en cada pedido.
_getaddrinfo = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: sorted(_getaddrinfo(*a, **k), key=lambda r: r[0] != socket.AF_INET)

RAIZ = Path(__file__).resolve().parents[2]
PAQ = RAIZ / "data" / "enciclopedia" / "paquetes"
DIR = Path(__file__).resolve().parent / "huecos"
CACHE = DIR / "cache" / "red.json"
ALCANCES = DIR / "alcances.json"
DECISIONES = DIR / "decisiones.json"
UA = "TellMAP/0.4 (https://bafif.github.io/tmap; datos de la enciclopedia)"
QLEVER = "https://qlever.dev/api/wikidata"
HOY = date.today().year
SECCIONES = ("regiones", "fuentes", "personas", "hechos", "lugares")
CAPAS = ("religiones", "culturas", "idiomas")
PRIORIDADES = ("alta", "media", "baja")
DETECTORES_SIN_RED = ("capas", "tramos", "referencias")
DETECTORES_RED = ("series", "sucesiones", "partes", "obras", "candidatos")
MIN_WIKIS = {"hechos": 5, "fuentes": 5, "personas": 8}  # piso de la profundidad
MAX_TITULARES = 400  # un cargo con más titulares (diputado, senador) no es una serie que se investigue entera
MAX_PARTES = 300
PASOS = (1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000)

# Ejes de los hechos: el `tipo` de tmap y las clases de Wikidata que le corresponden.
EJES_HECHOS = {
    "batalla": ["Q178561", "Q198", "Q188055", "Q831663"],  # batalla, guerra, asedio, campaña militar
    "tratado": ["Q131569"],  # tratado (con sus subclases: de paz, de límites…)
    "revolucion": ["Q10931", "Q45382", "Q124734"],  # revolución, golpe de estado, rebelión
    "desastre": ["Q3839081", "Q7944", "Q44512", "Q8065"],  # desastre, terremoto, epidemia, desastre natural
    "exploracion": ["Q2401485"],  # expedición
    "religioso": ["Q51645"],  # concilio ecuménico
}
# Ocupaciones: el rol de tmap (sin tildes) y las ocupaciones (P106) de Wikidata.
OCUPACIONES = {
    "politico": ["Q82955"], "presidente": ["Q82955"], "gobernador": ["Q82955"], "ministro": ["Q82955"],
    "caudillo": ["Q82955", "Q47064"], "militar": ["Q47064", "Q189290"], "general": ["Q189290"],
    "marino": ["Q10669499"], "escritor": ["Q36180"], "novelista": ["Q6625963"], "ensayista": ["Q11774202"],
    "poeta": ["Q49757"], "filosofo": ["Q4964182"], "historiador": ["Q201788"], "cronista": ["Q201788"],
    "economista": ["Q188094"], "teologo": ["Q1234713"], "periodista": ["Q1930187"], "abogado": ["Q40348"],
    "jurista": ["Q185351"], "juez": ["Q16533"], "medico": ["Q39631"], "fisico": ["Q169470"],
    "matematico": ["Q170790"], "astronomo": ["Q11063"], "quimico": ["Q593644"], "biologo": ["Q864503"],
    "naturalista": ["Q18805"], "ingeniero": ["Q81096"], "informatico": ["Q82594"], "programador": ["Q5482740"],
    "sociologo": ["Q2306091"], "antropologo": ["Q4773904"], "diplomatico": ["Q193391"], "obispo": ["Q29182"],
    "sacerdote": ["Q250867"], "monje": ["Q733786"], "rabino": ["Q133485"], "misionero": ["Q219477"],
    "empresario": ["Q43845", "Q131524"], "pintor": ["Q1028181"], "compositor": ["Q36834"], "musico": ["Q639669"],
    "arquitecto": ["Q42973"], "escultor": ["Q1281618"], "explorador": ["Q11900058"], "conquistador": ["Q11900058"],
    "viajero": ["Q12356615"], "cartografo": ["Q1734662"], "revolucionario": ["Q3242115"], "filologo": ["Q13418253"],
}
PREFIJOS = """PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX p: <http://www.wikidata.org/prop/>
PREFIX ps: <http://www.wikidata.org/prop/statement/>
PREFIX pq: <http://www.wikidata.org/prop/qualifier/>
PREFIX wikibase: <http://wikiba.se/ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX schema: <http://schema.org/>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>
"""


# --------------------------------------------------------------------------------------------------- utilidades
def lin(a: int) -> int:
    """Año de tmap (sin año 0) a una recta continua: -1 (1 a. C.) pasa a 0."""
    return a + 1 if a < 0 else a


def des(x: int) -> int:
    return x - 1 if x <= 0 else x


def texto_anio(a: int | None) -> str:
    if a is None:
        return "hoy"
    return f"{-a} a. C." if a < 0 else str(a)


def texto_tramo(a: int, b: int) -> str:
    return texto_anio(a) if a == b else f"{texto_anio(a)}–{texto_anio(b)}"


def anio_wd(v: str | None) -> int | None:
    """Fecha de Wikidata («-0499-01-01T00:00:00Z», año 0 = 1 a. C.) a año de tmap."""
    if not v:
        return None
    m = re.match(r"^(-?)0*(\d+)-", v)
    if not m:
        return None
    y = int(m[2]) * (-1 if m[1] else 1)
    return y if y > 0 else y - 1


def normal(s: str) -> str:
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return " ".join(re.sub(r"[^a-z0-9]+", " ", s).split())


def rol_canonico(r: str) -> str:
    r = normal(r)
    for fem, masc in (("escritora", "escritor"), ("poetisa", "poeta"), ("filosofa", "filosofo"),
                      ("historiadora", "historiador"), ("abogada", "abogado"), ("medica", "medico"),
                      ("fisica", "fisico"), ("quimica", "quimico"), ("ingeniera", "ingeniero"),
                      ("sociologa", "sociologo"), ("antropologa", "antropologo"), ("politica", "politico")):
        if r == fem:
            return masc
    return r


def cuantil(xs: list[float], q: float) -> float:
    xs = sorted(xs)
    if not xs:
        return 0
    k = (len(xs) - 1) * q
    i = int(k)
    return xs[i] if i + 1 >= len(xs) else xs[i] + (xs[i + 1] - xs[i]) * (k - i)


def dentro(lon: float, lat: float, poli: list) -> bool:
    res = False
    for i in range(len(poli)):
        x1, y1 = poli[i][0], poli[i][1]
        x2, y2 = poli[i - 1][0], poli[i - 1][1]
        if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
            res = not res
    return res


def sin_cubrir(intervalos: list[tuple[int, int]], a: int, b: int) -> list[tuple[int, int]]:
    """Tramos de [a, b] (en la recta de lin) que ningún intervalo cubre."""
    fuera, cur = [], a
    for x, y in sorted(intervalos):
        if y < cur:
            continue
        if x > cur:
            fuera.append((cur, min(x - 1, b)))
        cur = max(cur, y + 1)
        if cur > b:
            break
    if cur <= b:
        fuera.append((cur, b))
    return [(x, y) for x, y in fuera if x <= y]


def args_de(nombre: str) -> list[str]:
    v = []
    for i, a in enumerate(sys.argv):
        if a == nombre and i + 1 < len(sys.argv):
            v.append(sys.argv[i + 1])
    return v


def arg_de(nombre: str, defecto: str | None = None) -> str | None:
    v = args_de(nombre)
    return v[-1] if v else defecto


def leer_json(ruta: Path, defecto):
    return json.loads(ruta.read_text(encoding="utf-8")) if ruta.exists() else defecto


def escribir_json(ruta: Path, d) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def leer_paquetes() -> dict[str, dict]:
    return {f.stem: json.loads(f.read_text(encoding="utf-8")) for f in sorted(PAQ.glob("*.json"))}


def escribir_paquete(nombre: str, d: dict) -> None:
    # El mismo formato que construir.py y el editor: un paquete leído y vuelto a escribir sale idéntico.
    (PAQ / f"{nombre}.json").write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")


def tramo_de(e: dict, seccion: str) -> tuple[int, int] | None:
    """Años (de tmap) que ocupa un elemento en el tiempo."""
    if seccion == "hechos":
        a = e.get("anio")
        return None if a is None else (a, e.get("anio_hasta") or a)
    if seccion == "fuentes":
        t = e.get("trata") or {}
        if t.get("desde") is not None:
            return t["desde"], t.get("hasta") or t["desde"]
        a = (e.get("escrita") or {}).get("anio")
        return None if a is None else (a, (e.get("escrita") or {}).get("anio_hasta") or a)
    if seccion == "personas":
        act = e.get("activo") or {}
        if act.get("desde") is not None:
            return act["desde"], act.get("hasta") or act["desde"]
        n, m = (e.get("nacimiento") or {}).get("anio"), (e.get("muerte") or {}).get("anio")
        if n is None and m is None:
            return None
        return (n + 15 if n is not None else m - 30), (m if m is not None else min(n + 70, HOY))
    return None


class Enciclopedia:
    def __init__(self) -> None:
        self.paquetes = leer_paquetes()
        self.donde: dict[tuple[str, str], str] = {}  # (sección, id) → paquete
        self.elementos: dict[tuple[str, str], dict] = {}
        for nombre, d in self.paquetes.items():
            for s in SECCIONES:
                for e in d.get(s) or []:
                    self.donde.setdefault((s, e["id"]), nombre)
                    self.elementos.setdefault((s, e["id"]), e)
        self.regiones = {i: e for (s, i), e in self.elementos.items() if s == "regiones"}

    def de(self, nombre: str, seccion: str) -> list[dict]:
        return self.paquetes[nombre].get(seccion) or []


# --------------------------------------------------------------------------------------------------- alcances
def inferir_alcance(enc: Enciclopedia, nombre: str) -> dict | None:
    d = enc.paquetes[nombre]
    # Los años salen de los hechos y de cuándo se escribieron las fuentes primarias. El `trata` de la historiografía
    # arrastra siglos de contexto: entra solo si el paquete no tiene otra cosa.
    usar = [lin(x) for h in d.get("hechos") or [] if (t := tramo_de(h, "hechos")) for x in t]
    for f in d.get("fuentes") or []:
        e = f.get("escrita") or {}
        if f.get("tipo") == "primaria" and e.get("anio") is not None:
            usar += [lin(e["anio"]), lin(e.get("anio_hasta") or e["anio"])]
    if len(usar) < 12:
        usar += [lin(x) for f in d.get("fuentes") or [] if (t := tramo_de(f, "fuentes")) for x in t]
    if len(usar) < 6:
        return None  # sin tema propio (familias, regiones del mundo)
    desde, hasta = des(int(cuantil(usar, 0.04))), des(int(cuantil(usar, 0.96)))
    desc = d.get("descripcion") or ""
    m = re.search(r"\((-?\d{3,4})\s*[-–]\s*(-?\d{3,4})\)", desc)
    # el rango que declara la descripción manda, pero sin achicar el de los datos: «El virreinato (1776-1810) y la
    # independencia» declara solo una parte
    if m:
        desde, hasta = min(desde, int(m[1])), max(hasta, int(m[2]))
    elif re.search(r"\b(\d{3,4}) a hoy\b", desc):
        desde, hasta = min(desde, int(re.search(r"\b(\d{3,4}) a hoy\b", desc)[1])), HOY
    desde = desde - desde % 10 if desde > 0 else -((-desde + 9) // 10 * 10)
    hasta = min(HOY, hasta + (-hasta) % 10) if hasta > 0 else -((-hasta) // 10 * 10 or 1)
    refs = Counter()
    for h in d.get("hechos") or []:
        refs.update(h.get("regiones") or [])
    for f in d.get("fuentes") or []:
        refs.update((f.get("trata") or {}).get("regiones") or [])
    for lu in d.get("lugares") or []:
        refs.update(lu.get("regiones") or [])
    total = sum(refs.values())
    propias = {r["id"] for r in d.get("regiones") or []}
    regiones = {r for r, c in refs.items() if c >= max(3, 0.04 * total) and r in enc.regiones} | propias
    # el núcleo: donde pasa el tema, no donde se asoma (Francia y Gran Bretaña entran en Rosas por el bloqueo)
    nucleo, juntas = set(propias), 0
    for r, c in refs.most_common():  # las más citadas, hasta juntar el 60 % de las referencias
        if juntas >= 0.6 * total:
            break
        if r in enc.regiones:
            nucleo.add(r)
        juntas += c
    tipos = Counter(h.get("tipo") for h in d.get("hechos") or [])
    roles = Counter(rol_canonico(r) for p in d.get("personas") or [] for r in set(p.get("roles") or []))
    return {
        "desde": desde, "hasta": hasta, "regiones": sorted(regiones), "nucleo": sorted(nucleo & regiones),
        "hechos": sorted(t for t, c in tipos.items() if c >= 3 and t in EJES_HECHOS),
        "ocupaciones": sorted(r for r, c in roles.items() if c >= 3 and r in OCUPACIONES),
        "profundidad": {},
    }


def alcances(enc: Enciclopedia, red: "Red | None" = None) -> tuple[dict[str, dict], set[str]]:
    """Los alcances fijados en alcances.json y, para los paquetes que no están, los inferidos."""
    fijos = leer_json(ALCANCES, {})
    res, inferidos = {}, set()
    for nombre in enc.paquetes:
        if nombre in fijos:
            res[nombre] = fijos[nombre]
        else:
            al = inferir_alcance(enc, nombre)
            if al:
                res[nombre] = al
                inferidos.add(nombre)
    if red:
        for nombre, al in res.items():
            if not al.get("profundidad"):
                al["profundidad"] = red.profundidad(enc, nombre)
    return res, inferidos


# --------------------------------------------------------------------------------------------------- red
class Red:
    def __init__(self) -> None:
        self.cache = leer_json(CACHE, {"wp": {}, "q": {}})
        self.pendientes = 0
        self._qids: dict[tuple[str, str], str] | None = None
        self.wikis: dict[str, int] = {}

    def guardar(self) -> None:
        if self.pendientes:
            CACHE.parent.mkdir(parents=True, exist_ok=True)
            CACHE.write_text(json.dumps(self.cache, ensure_ascii=False), encoding="utf-8")
            self.pendientes = 0

    def pedir(self, url: str, datos: dict | None = None) -> dict:
        cuerpo = urllib.parse.urlencode(datos).encode() if datos else None
        for intento in range(6):
            req = urllib.request.Request(url, data=cuerpo, headers={
                "User-Agent": UA, "Accept": "application/sparql-results+json, application/json"})
            t0 = time.time()
            try:
                with urllib.request.urlopen(req, timeout=90) as r:
                    res = json.loads(r.read())
                if time.time() - t0 > 20:
                    print(f"  (pedido lento: {time.time() - t0:.0f} s, {url[:60]})", file=sys.stderr)
                return res
            except urllib.error.HTTPError as e:
                if e.code == 400:
                    raise RuntimeError(f"consulta rechazada: {e.read()[:300]!r}") from e
                error = f"HTTP {e.code}"
                if e.code == 429:  # QLever limita los pedidos seguidos
                    espera = int(e.headers.get("Retry-After") or 0) or 30 * 2 ** intento
                    print(f"  (QLever pide esperar: {espera} s)", file=sys.stderr)
                    time.sleep(espera)
                    continue
            except (urllib.error.URLError, TimeoutError) as e:
                error = str(e)[:80]
            espera = 5 * (intento + 1)
            print(f"  (falló un pedido a {url[:60]}: {error}; reintento en {espera} s)", file=sys.stderr)
            time.sleep(espera)
        raise RuntimeError(f"no responde: {url}")

    def sparql(self, consulta: str) -> list[dict]:
        clave = hashlib.sha1(consulta.encode()).hexdigest()[:20]
        if clave not in self.cache["q"]:
            filas = self.pedir(QLEVER, {"query": PREFIJOS + consulta})["results"]["bindings"]
            self.cache["q"][clave] = [{k: v["value"] for k, v in f.items()} for f in filas]
            self.pendientes += 1
            if self.pendientes >= 10:
                self.guardar()
            time.sleep(3)  # QLever responde 429 si se le pide seguido
        return self.cache["q"][clave]

    def en_lotes(self, plantilla: str, qids: list[str], tam: int = 250) -> list[dict]:
        filas = []
        qids = sorted(set(qids))
        for k in range(0, len(qids), tam):
            filas += self.sparql(plantilla.replace("{V}", " ".join("wd:" + q for q in qids[k:k + tam])))
        return filas

    def qids_de_titulos(self, claves: list[str]) -> None:
        """Resuelve «en:Título» o «es:Título» a su QID con la API de Wikipedia (redirecciones incluidas)."""
        faltan = sorted({c for c in claves if c not in self.cache["wp"]})
        for lengua in ("en", "es"):
            ts = [c[3:] for c in faltan if c.startswith(lengua + ":")]
            for k in range(0, len(ts), 40):  # con 50 títulos la API a veces responde «toomanyvalues»
                grupo = ts[k:k + 40]
                d = self.pedir(f"https://{lengua}.wikipedia.org/w/api.php?" + urllib.parse.urlencode({
                    "action": "query", "titles": "|".join(grupo), "redirects": 1, "prop": "pageprops",
                    "ppprop": "wikibase_item", "format": "json", "formatversion": 2}))
                if "query" not in d:  # un error no se guarda como «sin QID»: esas fichas parecerían ausentes
                    print(f"  (la API de Wikipedia respondió {str(d.get('error'))[:120]})", file=sys.stderr)
                    continue
                q = d["query"]
                camino = {x["from"]: x["to"] for x in q.get("normalized", []) + q.get("redirects", [])}
                qid = {p["title"]: p.get("pageprops", {}).get("wikibase_item") for p in q.get("pages", [])}
                for t in grupo:
                    final = t
                    for _ in range(3):
                        final = camino.get(final, final)
                    self.cache["wp"][f"{lengua}:{t}"] = qid.get(final)
                self.pendientes += 1
                time.sleep(0.1)
        self.guardar()

    def qids(self, enc: Enciclopedia) -> dict[tuple[str, str], str]:
        """El QID de cada elemento de tmap: el `wikidata` de las personas o el de su artículo de Wikipedia."""
        if self._qids is not None:
            return self._qids
        claves = {}
        for (s, i), e in enc.elementos.items():
            if s == "regiones":
                continue
            w = e.get("wikipedia") or {}
            if e.get("wikidata"):
                continue
            if w.get("en"):
                claves[(s, i)] = "en:" + w["en"]
            elif w.get("es"):
                claves[(s, i)] = "es:" + w["es"]
        self.qids_de_titulos(list(claves.values()))
        res = {}
        for (s, i), e in enc.elementos.items():
            q = e.get("wikidata") or self.cache["wp"].get(claves.get((s, i), ""))
            if q:
                res[(s, i)] = q
        self._qids = res
        return res

    def traer_wikis(self, qids: list[str]) -> None:
        faltan = [q for q in set(qids) if q not in self.wikis]
        for f in self.en_lotes("SELECT ?x ?sl WHERE { VALUES ?x { {V} } ?x wikibase:sitelinks ?sl }", faltan, 300):
            self.wikis[f["x"].rsplit("/", 1)[1]] = int(f["sl"])
        for q in faltan:
            self.wikis.setdefault(q, 0)

    def etiquetas(self, qids: list[str]) -> dict[str, dict]:
        filas = self.en_lotes("""SELECT ?x ?es ?en ?t WHERE { VALUES ?x { {V} }
          OPTIONAL { ?x rdfs:label ?es FILTER(LANG(?es) = "es") }
          OPTIONAL { ?x rdfs:label ?en FILTER(LANG(?en) = "en") }
          OPTIONAL { ?a schema:about ?x ; schema:isPartOf <https://en.wikipedia.org/> ; schema:name ?t } }""",
                              qids, 200)
        res: dict[str, dict] = {}
        for f in filas:
            q = f["x"].rsplit("/", 1)[1]
            r = res.setdefault(q, {})
            for k in ("es", "en", "t"):
                if f.get(k):
                    r.setdefault(k, f[k])
        return res

    def profundidad(self, enc: Enciclopedia, nombre: str) -> dict[str, int]:
        qids = self.qids(enc)
        res = {}
        for s in ("hechos", "fuentes", "personas"):
            qs = [qids[(s, e["id"])] for e in enc.de(nombre, s) if (s, e["id"]) in qids]
            self.traer_wikis(qs)
            ws = [self.wikis[q] for q in qs]
            res[s] = max(MIN_WIKIS[s], int(cuantil(ws, 0.25))) if len(ws) >= 4 else MIN_WIKIS[s]
            res[s + "_mediana"] = int(cuantil(ws, 0.5)) if ws else MIN_WIKIS[s]
        return res


# --------------------------------------------------------------------------------------------------- huecos
def hueco(detector: str, clave: str, prioridad: str, paquete: str | None, que: str, evidencia: str = "",
          accion: str = "", **extra) -> dict:
    h = {"clave": clave, "detector": detector, "prioridad": prioridad, "paquete": paquete, "que": que,
         "evidencia": evidencia, "accion": accion}
    h.update({k: v for k, v in extra.items() if v not in (None, "", [])})
    return h


def ventanas_de_regiones(als: dict[str, dict]) -> dict[str, list[tuple[int, int]]]:
    """Los años investigados de cada región (en la recta de lin): la unión de los alcances que la incluyen."""
    v: dict[str, list[tuple[int, int]]] = defaultdict(list)
    for al in als.values():
        for r in al["regiones"]:
            v[r].append((lin(al["desde"]), lin(al["hasta"])))
    res = {}
    for r, iv in v.items():
        unidos: list[list[int]] = []
        for a, b in sorted(iv):
            if unidos and a <= unidos[-1][1] + 1:
                unidos[-1][1] = max(unidos[-1][1], b)
            else:
                unidos.append([a, b])
        res[r] = [(a, b) for a, b in unidos]
    return res


QUE_FALTA = {"eras": "era", "religiones": "religión", "culturas": "cultura", "idiomas": "idioma"}


def det_capas(enc: Enciclopedia, als: dict[str, dict]) -> list[dict]:
    """Años investigados en que la región no tiene era o entrada de capa, ni la tiene una región madre.

    Así lee la app: pinta la entrada mayoritaria vigente o, si no hay, la primera vigente de cualquier peso; y una
    región sin datos deja ver los de la región más grande que la contiene."""
    res = []
    for rid, r in enc.regiones.items():
        paq = enc.donde[("regiones", rid)]
        ventanas = ventanas_de_regiones(als).get(rid)
        if not ventanas:
            continue  # región que ningún tema investigó
        cadena, x = [], rid
        while x and x in enc.regiones and x not in cadena:
            cadena.append(x)
            x = enc.regiones[x].get("padre")
        nombre = r.get("nombre", rid)
        investigada = ", ".join(texto_tramo(des(a), des(b)) for a, b in ventanas)
        for capa in ("eras",) + CAPAS:
            def intervalos(region: dict) -> list[tuple[int, int]]:
                iv = []
                for e in region.get(capa) or []:
                    a = e.get("desde") if e.get("desde") is not None else -100000
                    b = e.get("hasta") if e.get("hasta") is not None else HOY
                    iv.append((lin(a), lin(b)))
                return iv
            propios = intervalos(r)
            todos = [i for c in cadena for i in intervalos(enc.regiones[c])]
            if not todos:
                res.append(hueco("capas", f"capa:{rid}:{capa}", "alta" if capa == "eras" else "media", paq,
                                 f"{nombre}: sin {capa} (investigada en {investigada})", accion="capa",
                                 regiones=[rid]))
                continue
            vistos = set()
            if propios:  # agujeros entre las entradas propias: alguien empezó la capa y la dejó cortada
                ea, eb = min(a for a, _ in propios), max(b for _, b in propios)
                for x, y in sin_cubrir(todos, ea, eb):
                    vistos.add((x, y))
                    a, b = des(x), des(y)
                    res.append(hueco("capas", f"capa:{rid}:{capa}:{a}:{b}", "alta" if y - x >= 9 else "media", paq,
                                     f"{nombre}: {texto_tramo(a, b)} sin {QUE_FALTA[capa]}", accion="capa",
                                     regiones=[rid], desde=a, hasta=b))
            for va, vb in ventanas:
                for x, y in sin_cubrir(todos, va, vb):
                    if (x, y) in vistos:
                        continue
                    a, b = des(x), des(y)
                    res.append(hueco("capas", f"capa:{rid}:{capa}:{a}:{b}", "media", paq,
                                     f"{nombre}: {texto_tramo(a, b)} sin {QUE_FALTA[capa]}, dentro de lo investigado "
                                     f"({investigada})", accion="capa", regiones=[rid], desde=a, hasta=b))
    return res


def det_tramos(enc: Enciclopedia, als: dict[str, dict]) -> list[dict]:
    res = []
    for nombre, al in als.items():
        a, b = lin(al["desde"]), lin(al["hasta"])
        paso = next((p for p in PASOS if (b - a + 1) / p <= 20), PASOS[-1])
        cajas = [(x, min(x + paso - 1, b)) for x in range(a, b + 1, paso)]
        for rid in al["regiones"]:
            def cuenta(paquetes: list[str]) -> list[int]:
                c = [0] * len(cajas)
                for pn in paquetes:
                    for s in ("hechos", "fuentes"):
                        for e in enc.de(pn, s):
                            regs = e.get("regiones") if s == "hechos" else (e.get("trata") or {}).get("regiones")
                            t = tramo_de(e, s)
                            if not t or rid not in (regs or []):
                                continue
                            x, y = lin(t[0]), lin(t[1])
                            if s == "fuentes" and y - x > 3 * paso:
                                continue  # una obra que abarca siglos no dice nada de un tramo
                            for k, (ca, cb) in enumerate(cajas):
                                if x <= cb and y >= ca:
                                    c[k] += 1
                return c
            propio = cuenta([nombre])
            if sum(propio) < 8:
                continue
            otros = cuenta([pn for pn in enc.paquetes if pn != nombre])
            llenos = [k for k, n in enumerate(propio) if n]
            k = llenos[0]
            while k < llenos[-1]:
                if propio[k]:
                    k += 1
                    continue
                j = k
                while not propio[j + 1]:
                    j += 1
                ta, tb = des(cajas[k][0]), des(cajas[j][1])
                n_otros = sum(otros[k:j + 1])
                reg = enc.regiones[rid].get("nombre", rid)
                res.append(hueco(
                    "tramos", f"tramo:{nombre}:{rid}:{ta}:{tb}", "baja" if n_otros >= 3 else "media", nombre,
                    f"{reg}, {texto_tramo(ta, tb)}: el tema no tiene ni hechos ni fuentes",
                    f"el paquete tiene {propio[k - 1]} antes y {propio[j + 1]} después (de a {paso} años); "
                    f"otros paquetes tienen {n_otros} en ese tramo", "investigar", regiones=[rid], desde=ta, hasta=tb))
                k = j + 1
    return res


def arreglos(enc: Enciclopedia) -> list[dict]:
    """autor_id que se deduce sin dudas (nombre idéntico y único) y obras que faltan en la ficha del autor."""
    por_nombre = defaultdict(set)
    for (s, i), e in enc.elementos.items():
        if s == "personas":
            por_nombre[normal(e.get("nombre", ""))].add(i)
    res = []
    for (s, i), f in enc.elementos.items():
        if s != "fuentes":
            continue
        autor = f.get("autor_id")
        if not autor and f.get("autor"):
            cand = por_nombre.get(normal(f["autor"]), set())
            if len(cand) == 1:
                autor = next(iter(cand))
                res.append({"tipo": "autor_id", "fuente": i, "persona": autor})
        if autor and ("personas", autor) in enc.elementos:
            if i not in (enc.elementos[("personas", autor)].get("obras") or []):
                res.append({"tipo": "obra", "fuente": i, "persona": autor})
    return res


def det_referencias(enc: Enciclopedia, als: dict[str, dict]) -> list[dict]:
    res = []
    for a in arreglos(enc):
        paq = enc.donde[("fuentes", a["fuente"])]
        if a["tipo"] == "autor_id":
            res.append(hueco("referencias", f"ref:autor:{a['fuente']}", "alta", paq,
                             f"fuente «{a['fuente']}»: el autor tiene ficha ({a['persona']}) pero falta autor_id",
                             accion="arreglar"))
        else:
            res.append(hueco("referencias", f"ref:obra:{a['persona']}:{a['fuente']}", "alta",
                             enc.donde[("personas", a["persona"])],
                             f"persona «{a['persona']}»: falta la obra «{a['fuente']}» en obras", accion="arreglar"))
    for (s, i), e in enc.elementos.items():
        paq = enc.donde[(s, i)]
        if s == "hechos":
            if not e.get("fuentes"):
                res.append(hueco("referencias", f"ref:sin-fuentes:{i}", "baja", paq,
                                 f"hecho «{e.get('titulo')}» ({texto_anio(e.get('anio'))}) sin fuentes",
                                 accion="documentar"))
            if e.get("lon") is None:
                res.append(hueco("referencias", f"ref:sin-coord:{i}", "baja", paq,
                                 f"hecho «{e.get('titulo')}» sin coordenadas (no aparece en el mapa)",
                                 accion="ubicar"))
        elif s == "fuentes":
            if not e.get("leer"):
                res.append(hueco("referencias", f"ref:sin-leer:{i}", "baja", paq,
                                 f"fuente «{e.get('titulo')}» sin enlace de lectura", accion="enlace"))
            if (e.get("escrita") or {}).get("lon") is None:
                res.append(hueco("referencias", f"ref:sin-lugar:{i}", "baja", paq,
                                 f"fuente «{e.get('titulo')}» sin lugar de escritura (no aparece en el mapa)",
                                 accion="ubicar"))
    return res


def paquete_por_anio(als: dict[str, dict], candidatos: list[str], anio: int | None) -> str | None:
    """De varios paquetes, el que tiene el alcance más angosto que contiene el año (el tema más específico)."""
    if not candidatos:
        return None
    if anio is not None:
        con = [p for p in candidatos if p in als and als[p]["desde"] <= anio <= als[p]["hasta"]]
        if con:
            return min(con, key=lambda p: als[p]["hasta"] - als[p]["desde"])
    return Counter(candidatos).most_common(1)[0][0]


def det_series(enc: Enciclopedia, als: dict[str, dict], red: Red) -> list[dict]:
    pers = {e["wikidata"]: i for (s, i), e in enc.elementos.items() if s == "personas" and e.get("wikidata")}
    cargos = defaultdict(set)
    for f in red.en_lotes("SELECT ?p ?c WHERE { VALUES ?p { {V} } ?p wdt:P39 ?c }", list(pers)):
        cargos[f["c"].rsplit("/", 1)[1]].add(f["p"].rsplit("/", 1)[1])
    multi = [c for c, v in cargos.items() if len(v) >= 2]
    tam = {f["c"].rsplit("/", 1)[1]: int(f["n"]) for f in red.en_lotes(
        "SELECT ?c (COUNT(DISTINCT ?p) AS ?n) WHERE { VALUES ?c { {V} } ?p wdt:P39 ?c } GROUP BY ?c", multi, 150)}
    chicos = [c for c in multi if tam.get(c, 0) <= MAX_TITULARES]
    terminos = defaultdict(lambda: defaultdict(list))  # cargo → persona → [(ini, fin)]
    wikis = {}
    for f in red.en_lotes("""SELECT ?c ?p ?ini ?fin ?sl WHERE { VALUES ?c { {V} } ?p p:P39 ?st . ?st ps:P39 ?c .
          OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } OPTIONAL { ?p wikibase:sitelinks ?sl } }""",
                          chicos, 30):
        c, p = f["c"].rsplit("/", 1)[1], f["p"].rsplit("/", 1)[1]
        terminos[c][p].append((anio_wd(f.get("ini")), anio_wd(f.get("fin"))))
        wikis[p] = int(f.get("sl") or 0)
    res, etiquetar = [], set()
    for c, por_persona in terminos.items():
        rango = {}
        for p, ts in por_persona.items():
            inis = [lin(a) for a, _ in ts if a is not None]
            fins = [lin(b if b is not None else a) for a, b in ts if a is not None]
            if inis:
                rango[p] = (min(inis), max(fins))
        presentes = [p for p in rango if p in pers]
        if len(presentes) < 2:
            continue
        va, vb = min(rango[p][0] for p in presentes), max(rango[p][1] for p in presentes)
        en_ventana = [p for p, (a, b) in rango.items() if a <= vb and b >= va]
        cobertura = sum(1 for p in en_ventana if p in pers) / len(en_ventana)
        if cobertura < 0.25:
            continue  # tmap tiene algunos titulares por otros motivos: la serie no se investigó
        prio = "alta" if cobertura >= 0.5 and len(presentes) >= 3 else "media"
        paqs = [enc.donde[("personas", pers[p])] for p in presentes]
        # bordes: titulares fuera de la ventana pero dentro del alcance del tema de los que están
        alc = [als[pq] for pq in set(paqs) if pq in als]
        ba = min((lin(a["desde"]) for a in alc), default=va)
        bb = max((lin(a["hasta"]) for a in alc), default=vb)
        for p, (a, b) in rango.items():
            if p in pers:
                continue
            interior = a <= vb and b >= va
            borde = not interior and a <= bb and b >= ba and cobertura >= 0.5
            if not (interior or borde):
                continue
            antes = max((q for q in presentes if rango[q][0] <= a), key=lambda q: rango[q][0], default=None)
            despues = min((q for q in presentes if rango[q][0] > a), key=lambda q: rango[q][0], default=None)
            res.append(hueco("series", f"serie:{c}:{p}", prio if interior else "baja",
                             paquete_por_anio(als, paqs, des(a)), "", "", "persona", qid=p, cargo=c,
                             wikis=wikis.get(p), desde=des(a), hasta=des(b),
                             _antes=pers.get(antes), _despues=pers.get(despues),
                             _cobertura=f"{sum(1 for q in en_ventana if q in pers)}/{len(en_ventana)}",
                             _borde=borde))
            etiquetar |= {p, c}
    et = red.etiquetas(sorted(etiquetar))
    for h in res:
        cargo = et.get(h["cargo"], {}).get("es") or et.get(h["cargo"], {}).get("en") or h["cargo"]
        h["que"] = f"Falta {nombre_et(et, h['qid'])} ({cargo}, {texto_tramo(h['desde'], h['hasta'])})"
        vecinos = " y ".join(f"«{x}»" for x in (h.pop("_antes", None), h.pop("_despues", None)) if x)
        h["evidencia"] = (f"serie de {h.pop('_cobertura')} titulares en tmap dentro de la ventana; "
                          f"{'borde del alcance del tema' if h.pop('_borde') else 'entre ' + vecinos}")
        h["wikipedia"] = et.get(h["qid"], {}).get("t")
        h["grupo"], h["grupo_nombre"] = f"serie:{h['cargo']}", cargo
    return res


def nombre_et(et: dict, q: str) -> str:
    e = et.get(q, {})
    return f"«{e.get('es') or e.get('en') or q}»"


def fecha_y_wikis(red: Red, qids: list[str]) -> dict[str, tuple[int | None, int]]:
    filas = red.en_lotes("""SELECT ?x (MIN(?d) AS ?f) (MAX(?s) AS ?sl) WHERE { VALUES ?x { {V} }
      OPTIONAL { ?x wdt:P585|wdt:P580|wdt:P577|wdt:P571 ?d } OPTIONAL { ?x wikibase:sitelinks ?s } } GROUP BY ?x""",
                         qids, 200)
    return {f["x"].rsplit("/", 1)[1]: (anio_wd(f.get("f")), int(f.get("sl") or 0)) for f in filas}


def det_sucesiones(enc: Enciclopedia, als: dict[str, dict], red: Red) -> list[dict]:
    qids = red.qids(enc)
    presentes = {q: k for k, q in qids.items() if k[0] in ("hechos", "fuentes")}
    sig, ant = {}, {}
    conocer = set(presentes)
    vistos = set()
    for _ in range(4):  # cuatro eslabones hacia cada lado
        nuevos = sorted(conocer - vistos)
        if not nuevos:
            break
        vistos |= set(nuevos)
        for f in red.en_lotes("""SELECT ?x ?a ?s WHERE { VALUES ?x { {V} }
              OPTIONAL { ?x wdt:P155 ?a } OPTIONAL { ?x wdt:P156 ?s } }""", nuevos):
            x = f["x"].rsplit("/", 1)[1]
            if f.get("a"):
                ant.setdefault(x, f["a"].rsplit("/", 1)[1])
            if f.get("s"):
                sig.setdefault(x, f["s"].rsplit("/", 1)[1])
        conocer = set(vistos) | set(sig.values()) | set(ant.values())
    faltan: dict[str, dict] = {}
    for q, (s, i) in presentes.items():
        for paso in (sig, ant):
            cadena, x = [], q
            for _ in range(4):
                x = paso.get(x)
                if not x or x == q:
                    break
                if x in presentes:
                    for m in cadena:  # eslabones entre dos que están
                        faltan[m] = {"prio": "alta", "desde": i, "hasta": presentes[x][1], "s": s}
                    break
                cadena.append(x)
            else:
                cadena = cadena[:1]
            if cadena and cadena[0] not in faltan:
                faltan.setdefault(cadena[0], {"prio": "media", "desde": i, "hasta": None, "s": s})
    fw = fecha_y_wikis(red, list(faltan))
    et = red.etiquetas(list(faltan))
    res = []
    for m, info in faltan.items():
        anio, wk = fw.get(m, (None, 0))
        paq = enc.donde[(info["s"], info["desde"])]
        al = als.get(paq)
        if info["prio"] == "media":
            if not al or anio is None or not al["desde"] <= anio <= al["hasta"]:
                continue
            if wk < al.get("profundidad", {}).get(info["s"], MIN_WIKIS[info["s"]]):
                continue
        entre = (f"entre «{info['desde']}» y «{info['hasta']}»" if info["hasta"]
                 else f"sigue o precede a «{info['desde']}»")
        res.append(hueco("sucesiones", f"sucesion:{m}", info["prio"], paq,
                         f"Falta {nombre_et(et, m)} ({texto_anio(anio) if anio is not None else 'sin fecha'})",
                         f"cadena de Wikidata (P155/P156): {entre}", "hecho" if info["s"] == "hechos" else "fuente",
                         qid=m, wikis=wk, desde=anio, wikipedia=et.get(m, {}).get("t")))
    return res


def det_partes(enc: Enciclopedia, als: dict[str, dict], red: Red) -> list[dict]:
    """Partes de un conjunto que el tema ya trató parte por parte.

    La cobertura se mide sobre las partes al menos tan notables como el tema: si tmap tiene la guerra entera pero
    ninguna de sus batallas, el tema la trató como un todo y sus 200 batallas no son huecos."""
    qids = red.qids(enc)
    ya = set(qids.values())
    presentes = {q: k for k, q in qids.items() if k[0] == "hechos"}
    contenedores = defaultdict(set)  # conjunto → partes presentes
    for f in red.en_lotes("SELECT ?x ?w WHERE { VALUES ?x { {V} } ?x wdt:P361 ?w }", list(presentes)):
        contenedores[f["w"].rsplit("/", 1)[1]].add(f["x"].rsplit("/", 1)[1])
    candidatos = [w for w, ps in contenedores.items() if len(ps) >= 2 or w in presentes]
    candidatos += [q for q in presentes if q not in contenedores]
    tam = {f["w"].rsplit("/", 1)[1]: int(f["n"]) for f in red.en_lotes(
        "SELECT ?w (COUNT(DISTINCT ?y) AS ?n) WHERE { VALUES ?w { {V} } ?y wdt:P361 ?w } GROUP BY ?w", candidatos, 200)}
    usar = [w for w in candidatos if 0 < tam.get(w, 0) <= MAX_PARTES]
    partes = defaultdict(set)
    for f in red.en_lotes("SELECT ?w ?y WHERE { VALUES ?w { {V} } ?y wdt:P361 ?w }", usar, 100):
        partes[f["w"].rsplit("/", 1)[1]].add(f["y"].rsplit("/", 1)[1])
    fw = fecha_y_wikis(red, sorted({y for ys in partes.values() for y in ys}))
    res, vistos = [], set()
    for w, ys_set in partes.items():
        ys = sorted(ys_set)  # ordenado: con un set, los empates entre paquetes cambiarían de una corrida a otra
        estan = [y for y in ys if y in presentes]
        if len(estan) < 2:
            continue  # con una sola parte (o ninguna) el conjunto no se trató parte por parte
        paqs = sorted(enc.donde[presentes[y]] for y in estan)
        paq = Counter(paqs).most_common(1)[0][0]
        al = als.get(paq, {})
        umbral = al.get("profundidad", {}).get("hechos", MIN_WIKIS["hechos"])
        notables = [y for y in ys if y in presentes or fw.get(y, (None, 0))[1] >= umbral]
        frac = len(estan) / len(notables)
        prio = "alta" if frac >= 0.5 else "media" if frac >= 0.2 else "baja"
        for y in notables:
            if y in ya or y in vistos:
                continue
            anio, wk = fw.get(y, (None, 0))
            if al and anio is not None and not al["desde"] <= anio <= al["hasta"]:
                continue
            vistos.add(y)
            res.append(hueco("partes", f"parte:{w}:{y}", prio, paquete_por_anio(als, paqs, anio), "",
                             f"parte de {w}; tmap tiene {len(estan)} de sus {len(notables)} partes con al menos "
                             f"{umbral} Wikipedias", "hecho", qid=y, wikis=wk, desde=anio, conjunto=w))
    et = red.etiquetas(sorted({h["qid"] for h in res} | {h["conjunto"] for h in res}))
    for h in res:
        anio = h.get("desde")
        h["que"] = f"Falta {nombre_et(et, h['qid'])} ({texto_anio(anio) if anio is not None else 'sin fecha'})"
        h["evidencia"] = h["evidencia"].replace(h["conjunto"], nombre_et(et, h["conjunto"]), 1)
        h["wikipedia"] = et.get(h["qid"], {}).get("t")
        h["grupo"], h["grupo_nombre"] = f"parte:{h['conjunto']}", f"partes de {nombre_et(et, h['conjunto'])}"
    return res


def det_obras(enc: Enciclopedia, als: dict[str, dict], red: Red) -> list[dict]:
    """Obras de autores con ficha, al menos tan notables como las fuentes de su tema y dentro de sus años.

    La prioridad depende de cuánto de ese autor ya tiene tmap: con tres obras o más, su obra es tema; sin ninguna, la
    persona está por otra cosa (un político, un rey) y sus libros son una pista floja."""
    qids = red.qids(enc)
    pers = {e["wikidata"]: i for (s, i), e in enc.elementos.items() if s == "personas" and e.get("wikidata")}
    ya = set(qids.values())
    filas = red.en_lotes("""SELECT ?p ?w ?sl (MIN(?d) AS ?f) WHERE { VALUES ?p { {V} } ?w wdt:P50 ?p .
        ?w wikibase:sitelinks ?sl . FILTER(?sl >= 5) ?w wdt:P31/wdt:P279* wd:Q386724 .
        OPTIONAL { ?w wdt:P577|wdt:P571 ?d } } GROUP BY ?p ?w ?sl""", list(pers), 200)
    res, vistos = [], set()
    for f in sorted(filas, key=lambda f: -int(f["sl"])):
        w, p = f["w"].rsplit("/", 1)[1], f["p"].rsplit("/", 1)[1]
        if w in ya or w in vistos:
            continue
        paq = enc.donde[("personas", pers[p])]
        al = als.get(paq, {})
        prof = al.get("profundidad", {})
        wk, anio = int(f["sl"]), anio_wd(f.get("f"))
        if wk < prof.get("fuentes", MIN_WIKIS["fuentes"]):
            continue
        if al and anio is not None and not al["desde"] <= anio <= al["hasta"]:
            continue
        vistos.add(w)
        n = len(enc.elementos[("personas", pers[p])].get("obras") or [])
        if n == 0:
            prio = "baja"
        elif n >= 3 and wk >= prof.get("fuentes_mediana", 99):
            prio = "alta"
        else:
            prio = "media"
        res.append(hueco("obras", f"obra:{p}:{w}", prio, paq, "",
                         f"obra de «{pers[p]}», que tiene ficha y {n} obras en tmap", "fuente", qid=w, wikis=wk,
                         desde=anio, grupo=f"obra:{p}", grupo_nombre=f"obras de «{pers[p]}»"))
    et = red.etiquetas([h["qid"] for h in res])
    for h in res:
        anio = h.get("desde")
        h["que"] = f"Falta {nombre_et(et, h['qid'])} ({texto_anio(anio) if anio is not None else 'sin fecha'})"
        h["wikipedia"] = et.get(h["qid"], {}).get("t")
    return res


def caja(polis: list[list]) -> tuple[float, float, float, float]:
    xs = [p[0] for poli in polis for p in poli]
    ys = [p[1] for poli in polis for p in poli]
    return min(xs), max(xs), min(ys), max(ys)


def filtro_caja(var: str, c: tuple[float, float, float, float]) -> str:
    return (f"FILTER(geof:longitude({var}) >= {c[0]} && geof:longitude({var}) <= {c[1]} && "
            f"geof:latitude({var}) >= {c[2]} && geof:latitude({var}) <= {c[3]})")


def det_candidatos(enc: Enciclopedia, als: dict[str, dict], red: Red) -> list[dict]:
    ya = set(red.qids(enc).values())
    hallados: dict[str, dict] = {}
    for nombre, al in als.items():
        polis = [enc.regiones[r]["poligono"] for r in al.get("nucleo") or al["regiones"] if r in enc.regiones]
        if not polis:
            continue
        c = caja(polis)
        prof = al.get("profundidad", {})
        a, b = lin(al["desde"]), lin(al["hasta"])
        consultas = []
        clase_eje = {q: eje for eje in al.get("hechos", []) for q in EJES_HECHOS.get(eje, [])}
        if clase_eje:
            consultas.append(("hechos", f"""SELECT ?x ?k ?sl ?d ?c WHERE {{
              VALUES ?k {{ {' '.join('wd:' + q for q in clase_eje)} }}
              ?x wdt:P31/wdt:P279* ?k . ?x wikibase:sitelinks ?sl . FILTER(?sl >= {prof.get('hechos', 5)})
              {{ ?x wdt:P585 ?d }} UNION {{ ?x wdt:P580 ?d }} FILTER(YEAR(?d) >= {a} && YEAR(?d) <= {b})
              {{ ?x wdt:P625 ?c }} UNION {{ ?x wdt:P276 ?l . ?l wdt:P625 ?c }} {filtro_caja('?c', c)}
            }} ORDER BY DESC(?sl) LIMIT 600"""))
        ocup = sorted({q for o in al.get("ocupaciones", []) for q in OCUPACIONES.get(o, [])})
        if ocup:
            # nacer en el núcleo cuenta; morir ahí, solo si fue dentro de los años del tema (no un exilio posterior)
            consultas.append(("personas", f"""SELECT ?x ?sl ?d ?c ?m ?donde WHERE {{
              VALUES ?o {{ {' '.join('wd:' + q for q in ocup)} }} ?x wdt:P106 ?o .
              ?x wikibase:sitelinks ?sl . FILTER(?sl >= {prof.get('personas', 8)})
              ?x wdt:P569 ?d . FILTER(YEAR(?d) >= {a - 80} && YEAR(?d) <= {b - 25})
              OPTIONAL {{ ?x wdt:P570 ?m }} FILTER(!BOUND(?m) || YEAR(?m) >= {a})
              {{ ?x wdt:P19 ?l . BIND("nacio" AS ?donde) }} UNION {{ ?x wdt:P20 ?l . BIND("murio" AS ?donde) }}
              ?l wdt:P625 ?c . {filtro_caja('?c', c)}
            }} ORDER BY DESC(?sl) LIMIT 600"""))
        for seccion, q in consultas:
            for f in red.sparql(q):
                x = f["x"].rsplit("/", 1)[1]
                eje = clase_eje.get(f.get("k", "").rsplit("/", 1)[-1], "personas")
                if x in ya:
                    continue
                m = re.match(r"POINT\(([-\d.eE]+) ([-\d.eE]+)\)", f.get("c", ""))
                if not m or not any(dentro(float(m[1]), float(m[2]), poli) for poli in polis):
                    continue
                if f.get("donde") == "murio" and (anio_wd(f.get("m")) or 99999) > al["hasta"] + 10:
                    continue
                anio, wk = anio_wd(f.get("d")), int(f["sl"])
                previo = hallados.get(x)
                if previo and previo["_ancho"] <= al["hasta"] - al["desde"]:
                    continue
                prio = "media" if wk >= prof.get(seccion + "_mediana", 99) else "baja"
                hallados[x] = hueco("candidatos", f"candidato:{nombre}:{eje}:{x}", prio, nombre, "",
                                    f"{eje} en {texto_tramo(al['desde'], al['hasta'])} dentro de las regiones del "
                                    f"tema, con {wk} Wikipedias (profundidad del paquete: "
                                    f"{prof.get(seccion, '?')})", "persona" if seccion == "personas" else "hecho",
                                    qid=x, wikis=wk, desde=anio, eje=eje, _ancho=al["hasta"] - al["desde"],
                                    grupo=f"candidato:{nombre}:{eje}", grupo_nombre=f"candidatos del eje «{eje}»")
    res = list(hallados.values())
    et = red.etiquetas([h["qid"] for h in res])
    for h in res:
        h.pop("_ancho")
        anio = h.get("desde")
        nacio = "nació en " if h["accion"] == "persona" else ""
        h["que"] = f"Falta {nombre_et(et, h['qid'])} ({nacio}{texto_anio(anio) if anio is not None else 'sin fecha'})"
        h["wikipedia"] = et.get(h["qid"], {}).get("t")
    return res


def detectar(enc: Enciclopedia, red: Red | None, detectores: list[str]) -> tuple[list[dict], set[str]]:
    als, inferidos = alcances(enc, red)
    funciones = {"capas": det_capas, "tramos": det_tramos, "referencias": det_referencias,
                 "series": det_series, "sucesiones": det_sucesiones, "partes": det_partes, "obras": det_obras,
                 "candidatos": det_candidatos}
    res = []
    for d in detectores:
        if d in DETECTORES_RED:
            if not red:
                continue
            try:
                res += funciones[d](enc, als, red)
            except RuntimeError as e:
                print(f"aviso: el detector {d} no pudo consultar Wikidata ({e})", file=sys.stderr)
            red.guardar()
        else:
            res += funciones[d](enc, als)
    # un mismo QID puede salir de dos detectores: queda el de prioridad más alta
    mejor: dict[str, dict] = {}
    sin_qid = []
    for h in res:
        if not h.get("qid"):
            sin_qid.append(h)
            continue
        p = mejor.get(h["qid"])
        if not p or PRIORIDADES.index(h["prioridad"]) < PRIORIDADES.index(p["prioridad"]):
            mejor[h["qid"]] = h
    res = sin_qid + list(mejor.values())
    res.sort(key=lambda h: (PRIORIDADES.index(h["prioridad"]), h.get("paquete") or "", h["detector"],
                            h.get("desde") if h.get("desde") is not None else 99999, -(h.get("wikis") or 0)))
    return res, inferidos


# --------------------------------------------------------------------------------------------------- órdenes
def filtrar(hs: list[dict]) -> tuple[list[dict], int]:
    paquetes = args_de("--paquete")
    tope = PRIORIDADES.index(arg_de("--prioridad", "media"))
    decisiones = leer_json(DECISIONES, {})
    todos = "--todos" in sys.argv
    res, decididos = [], 0
    for h in hs:
        if paquetes and h.get("paquete") not in paquetes:
            continue
        if PRIORIDADES.index(h["prioridad"]) > tope:
            continue
        partes = h["clave"].split(":")
        prefijo = next((":".join(partes[:k]) for k in range(len(partes), 1, -1)
                        if ":".join(partes[:k]) in decisiones), None)
        if prefijo:  # una decisión vale para su clave y para todas las que empiezan con ella (serie:Q123 → la serie)
            decididos += 1
            if not todos:
                continue
            h = dict(h, decision=decisiones[prefijo])
        res.append(h)
    return res, decididos


def preparar() -> tuple[Enciclopedia, Red | None, list[str]]:
    enc = Enciclopedia()
    red = Red() if "--red" in sys.argv else None
    dets = args_de("--detector") or list(DETECTORES_SIN_RED + (DETECTORES_RED if red else ()))
    for d in dets:
        if d not in DETECTORES_SIN_RED + DETECTORES_RED:
            sys.exit(f"detector desconocido: {d}")
    return enc, red, dets


def linea(h: dict) -> str:
    extra = []
    if h.get("qid"):
        extra.append(h["qid"] + (f", {h['wikis']} Wikipedias" if h.get("wikis") else ""))
    if h.get("wikipedia"):
        extra.append(f"en: {h['wikipedia']}")
    s = f"- **{h['que']}**" + (f" ({'; '.join(extra)})" if extra else "")
    if h.get("evidencia"):
        s += f". {h['evidencia']}"
    s += f". `{h['clave']}`"
    if h.get("decision"):
        s += f" — decidido: {h['decision'].get('decision')} ({h['decision'].get('motivo')})"
    return s


def orden_informe() -> int:
    enc, red, dets = preparar()
    hs, inferidos = detectar(enc, red, dets)
    vis, decididos = filtrar(hs)
    if arg_de("--json"):
        escribir_json(Path(arg_de("--json")), vis)
    cuenta = Counter(h["prioridad"] for h in vis)
    print(f"Huecos: {len(vis)} (alta {cuenta['alta']}, media {cuenta['media']}, baja {cuenta['baja']})"
          f"{f'; {decididos} ya decididos no se muestran' if decididos and '--todos' not in sys.argv else ''}"
          f"{'' if red else '; sin --red no corren series, sucesiones, partes, obras ni candidatos'}")
    if inferidos:
        print(f"Alcance inferido, no fijado en alcances.json: {', '.join(sorted(inferidos))}")
    mecanicos = sum(1 for h in vis if h.get("accion") == "arreglar")
    if mecanicos:
        print(f"{mecanicos} arreglos mecánicos (autor_id, obras): huecos.py arreglar --escribir")
    tabla = defaultdict(Counter)
    for h in vis:
        tabla[h.get("paquete") or "-"][h["detector"]] += 1
    cols = [d for d in DETECTORES_SIN_RED + DETECTORES_RED if any(t[d] for t in tabla.values())]
    if cols:
        print("\n" + "paquete".ljust(42) + "".join(c[:11].rjust(12) for c in cols))
        for p in sorted(tabla):
            print(p[:41].ljust(42) + "".join(str(tabla[p][c] or "").rjust(12) for c in cols))
    if "--resumen" not in sys.argv:
        for prio in PRIORIDADES:
            grupo = [h for h in vis if h["prioridad"] == prio and h["detector"] != "referencias"]
            if grupo:
                print(f"\n## Prioridad {prio}\n")
                for h in grupo[:200]:
                    print(f"[{h.get('paquete')}] " + linea(h)[2:])
                if len(grupo) > 200:
                    print(f"… y {len(grupo) - 200} más (--json para todos)")
    return 0


def orden_lotes() -> int:
    if len(sys.argv) < 3 or sys.argv[2].startswith("--"):
        sys.exit("uso: huecos.py lotes <carpeta> [opciones]")
    carpeta = Path(sys.argv[2])
    enc, red, dets = preparar()
    hs, _ = detectar(enc, red, dets)
    als, _ = alcances(enc, red)
    vis, _ = filtrar(hs)
    por_paquete = defaultdict(list)
    for h in vis:
        por_paquete[h.get("paquete") or "sin-paquete"].append(h)
    carpeta.mkdir(parents=True, exist_ok=True)
    titulos = {"capas": "Capas de las regiones (eras, religiones, culturas, idiomas)",
               "series": "Series de cargos", "sucesiones": "Sucesiones (lo que sigue o precede)",
               "partes": "Partes de un conjunto", "obras": "Obras de autores con ficha",
               "candidatos": "Candidatos del lugar, la época y los ejes del tema",
               "tramos": "Tramos vacíos (qué pasó ahí en este tema)", "referencias": "Mantenimiento"}
    for paq, grupo in sorted(por_paquete.items()):
        al = als.get(paq)
        out = [f"# Huecos de «{paq}»", ""]
        if al:
            regs = ", ".join(enc.regiones[r].get("nombre", r) for r in al["regiones"] if r in enc.regiones)
            nuc = ", ".join(enc.regiones[r].get("nombre", r) for r in al.get("nucleo") or [] if r in enc.regiones)
            out += [f"Alcance: {texto_tramo(al['desde'], al['hasta'])}; regiones: {regs}; núcleo: {nuc or '-'}.",
                    f"Ejes: hechos {', '.join(al.get('hechos') or ['-'])}; personas "
                    f"{', '.join(al.get('ocupaciones') or ['-'])}. Profundidad (Wikipedias): "
                    f"{json.dumps(al.get('profundidad') or {}, ensure_ascii=False)}.", ""]
        for det in DETECTORES_SIN_RED[:2] + DETECTORES_RED + ("referencias",):
            g = [h for h in grupo if h["detector"] == det]
            if not g:
                continue
            out += [f"## {titulos[det]} ({len(g)})", ""]
            grupos: dict[str, list[dict]] = defaultdict(list)
            for h in g:
                grupos[h.get("grupo") or ""].append(h)
            # sueltos primero; después cada grupo (una serie, un conjunto, un autor): se descarta entero con su clave
            for clave_grupo, hs_g in sorted(grupos.items(), key=lambda x: (x[0] != "", -len(x[1]))):
                if clave_grupo:
                    out += [f"### {hs_g[0].get('grupo_nombre', clave_grupo)} ({len(hs_g)}; el grupo entero: "
                            f"`{clave_grupo}`)", ""]
                for prio in PRIORIDADES:
                    out += [linea(h) + f" [{prio}]" for h in hs_g if h["prioridad"] == prio]
                out.append("")
        (carpeta / f"{paq}.md").write_text("\n".join(out), encoding="utf-8")
        escribir_json(carpeta / f"{paq}.json", grupo)
        print(f"{paq}: {len(grupo)} huecos → {carpeta / (paq + '.md')}")
    return 0


def orden_alcances() -> int:
    enc = Enciclopedia()
    red = Red() if "--red" in sys.argv or "--fijar" in sys.argv else None
    fijos = leer_json(ALCANCES, {})
    rehacer = set(args_de("--rehacer"))
    if "todo" in rehacer:
        rehacer = set(fijos)
    for p in rehacer:
        fijos.pop(p, None)
    if "--fijar" in sys.argv:
        ALCANCES.write_text(json.dumps(fijos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    als, inferidos = alcances(enc, red)
    for nombre, al in als.items():
        marca = "inferido" if nombre in inferidos else "fijado"
        print(f"{nombre} ({marca}): {texto_tramo(al['desde'], al['hasta'])}; {len(al['regiones'])} regiones "
              f"({', '.join(al['regiones'][:8])}{'…' if len(al['regiones']) > 8 else ''}); hechos "
              f"{','.join(al.get('hechos') or []) or '-'}; ocupaciones {','.join(al.get('ocupaciones') or []) or '-'}; "
              f"profundidad {json.dumps(al.get('profundidad') or {})}")
    if "--fijar" in sys.argv:
        for n in inferidos:
            fijos[n] = als[n]
        escribir_json(ALCANCES, dict(sorted(fijos.items())))
        print(f"fijados: {', '.join(sorted(inferidos)) or 'ninguno nuevo'} → {ALCANCES.relative_to(RAIZ)}")
    if red:
        red.guardar()
    return 0


def orden_decidir() -> int:
    decisiones = leer_json(DECISIONES, {})
    if arg_de("--archivo"):
        nuevas = json.loads(Path(arg_de("--archivo")).read_text(encoding="utf-8"))
    elif len(sys.argv) >= 5:
        nuevas = [{"clave": sys.argv[2], "decision": sys.argv[3], "motivo": " ".join(sys.argv[4:])}]
    else:
        sys.exit("uso: huecos.py decidir <clave> <descartado|sin-datos> <motivo>  o  --archivo <json>")
    for n in nuevas:
        if n.get("decision") not in ("descartado", "sin-datos") or not n.get("motivo") or not n.get("clave"):
            sys.exit(f"decisión inválida (va descartado o sin-datos, con motivo): {n}")
        decisiones[n["clave"]] = {"decision": n["decision"], "motivo": n["motivo"],
                                  "fecha": date.today().isoformat()}
    escribir_json(DECISIONES, dict(sorted(decisiones.items())))
    print(f"{len(nuevas)} decisiones anotadas en {DECISIONES.relative_to(RAIZ)}")
    return 0


def orden_arreglar() -> int:
    enc = Enciclopedia()
    tocados = set()
    lista = arreglos(enc)
    for a in lista:
        f = enc.elementos[("fuentes", a["fuente"])]
        p = enc.elementos[("personas", a["persona"])]
        if a["tipo"] == "autor_id":
            print(f"autor_id: {a['fuente']} → {a['persona']} («{f.get('autor')}»)")
            f["autor_id"] = a["persona"]
            tocados.add(enc.donde[("fuentes", a["fuente"])])
        else:
            print(f"obras: {a['persona']} + {a['fuente']}")
            p.setdefault("obras", [])
            if a["fuente"] not in p["obras"]:
                p["obras"].append(a["fuente"])
            tocados.add(enc.donde[("personas", a["persona"])])
    print(f"{len(lista)} arreglos en {len(tocados)} paquetes")
    if "--escribir" in sys.argv:
        for n in sorted(tocados):
            escribir_paquete(n, enc.paquetes[n])
        print("escritos:", ", ".join(sorted(tocados)) or "ninguno")
    return 0


def orden_aplicar() -> int:
    if len(sys.argv) < 4:
        sys.exit("uso: huecos.py aplicar <carpeta del tema> <paquete> [--escribir]")
    carpeta, destino = Path(sys.argv[2]), sys.argv[3]
    enc = Enciclopedia()
    if destino not in enc.paquetes:
        sys.exit(f"no existe el paquete {destino}")
    salida = leer_json(carpeta / "salida.json", {})
    familias = leer_json(carpeta / "familias-nuevas.json", [])
    parches = leer_json(carpeta / "parches.json", [])
    if salida.get("paquete") in enc.paquetes:
        sys.exit(f"salida.json se llama como un paquete existente ({salida['paquete']}): en meta.txt va otro nombre, "
                 f"como huecos-{destino}, para que construir.py vea el paquete al resolver referencias")
    tocados, errores = set(), []
    d = enc.paquetes[destino]
    nuevos = {}
    for s in SECCIONES:
        for e in salida.get(s) or []:
            if (s, e["id"]) in enc.elementos:
                errores.append(f"{s} «{e['id']}» ya existe en {enc.donde[(s, e['id'])]}")
                continue
            d.setdefault(s, []).append(e)
            nuevos[(s, e["id"])] = e
            tocados.add(destino)
            print(f"+ {s} {e['id']}")
    for (s, i), f in nuevos.items():
        if s == "fuentes" and f.get("autor_id"):
            k = ("personas", f["autor_id"])
            p = nuevos.get(k) or enc.elementos.get(k)
            if p is not None and i not in (p.get("obras") or []):
                p.setdefault("obras", []).append(i)
                if k in enc.donde:
                    tocados.add(enc.donde[k])
    if familias:
        fam = enc.paquetes["familias"]
        ya = {(f["capa"], f["id"]) for f in fam["familias"]}
        for f in familias:
            if (f["capa"], f["id"]) not in ya:
                fam["familias"].append(f)
                tocados.add("familias")
                print(f"+ familia {f['capa']}/{f['id']}")
    ordenar = {"eras": "desde", "religiones": "desde", "culturas": "desde", "idiomas": "desde", "demografia": "anio"}
    for par in parches:
        k = (par.get("seccion"), par.get("id"))
        e = nuevos.get(k) or enc.elementos.get(k)
        if e is None:
            errores.append(f"parche: no existe {k[0]} «{k[1]}»")
            continue
        for campo, valor in (par.get("poner") or {}).items():
            print(f"~ {k[0]} {k[1]}: {campo} = {json.dumps(valor, ensure_ascii=False)[:100]}")
            e[campo] = valor
        for campo, valores in (par.get("agregar") or {}).items():
            lista = e.setdefault(campo, [])
            for v in valores:
                if v not in lista:
                    lista.append(v)
                    print(f"~ {k[0]} {k[1]}: {campo} + {json.dumps(v, ensure_ascii=False)[:100]}")
            if campo in ordenar:
                lista.sort(key=lambda x: lin(x.get(ordenar[campo])) if x.get(ordenar[campo]) is not None else -10 ** 6)
        if k in enc.donde:
            tocados.add(enc.donde[k])
    for err in errores:
        print("ERROR:", err)
    if errores:
        print("no se escribió nada: corregí los errores (un id que ya existe se usa, no se redefine)")
        return 1
    print(f"se tocan: {', '.join(sorted(tocados)) or 'ninguno'}")
    if "--escribir" in sys.argv:
        for n in sorted(tocados):
            escribir_paquete(n, enc.paquetes[n])
        print("escrito. Después: validar.py, cobertura.py y la traducción (tools/traduccion/enciclopedia.py)")
    return 0


def main() -> int:
    ordenes = {"informe": orden_informe, "lotes": orden_lotes, "alcances": orden_alcances,
               "decidir": orden_decidir, "arreglar": orden_arreglar, "aplicar": orden_aplicar}
    if len(sys.argv) < 2 or sys.argv[1] not in ordenes:
        print(__doc__)
        return 0
    return ordenes[sys.argv[1]]()


if __name__ == "__main__":
    sys.exit(main())
