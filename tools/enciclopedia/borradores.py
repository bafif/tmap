"""Arma borradores de la enciclopedia con Wikipedia y Wikidata para lo más consultado sin ficha.

Uso:
  python3 tools/enciclopedia/borradores.py                   # los 3 más consultados de la cola local
  python3 tools/enciclopedia/borradores.py -n 5
  python3 tools/enciclopedia/borradores.py --cola pendientes.json   # una cola copiada desde Ajustes
  python3 tools/enciclopedia/borradores.py --wikidata Q12560        # una entidad puntual, sin mirar la cola

La cola es la que anota la app en user://pendientes.json (Ajustes → Enciclopedia): qué lugares se consultaron sin
ficha y cuántas veces. Por cada entrada con Wikidata, el script junta:

- de Wikidata: la capital (con coordenadas), personas clave (jefes de Estado, fundadores) con sus fechas y lugares
  de nacimiento y muerte, y los hechos importantes con fecha y lugar;
- de Wikipedia (en español; si no hay, en inglés): el resumen y el artículo completo por secciones;
- de Cliopatria (data/mapa/politico.json): los años de la entidad.

Y escribe data/enciclopedia/paquetes/borradores/<id>.json: un paquete con una región (sin área de estudio: se calcula
en el editor con el territorio de Cliopatria), lugares, personas y hechos, más una sección `borrador` con el origen,
el estado «sin revisar» y el artículo por secciones (lo usa redactar.py). La app no carga los borradores: se revisan y
aprueban en el editor (Ajustes → Abrir el editor → Borradores). Nada se publica solo.

Corre a mano y en lotes chicos. Respeta la política de Wikimedia: User-Agent propio, pedidos de a uno, pausas y
reintentos si el servidor pide esperar (429). Sin dependencias: solo la biblioteca estándar de Python.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DIR_BORRADORES = RAIZ / "data" / "enciclopedia" / "paquetes" / "borradores"
UA = "TellMAP-borradores/0.3 (https://github.com/bafif/tmap; tools/enciclopedia/borradores.py)"
PAUSA = 0.6
# Secciones de Wikipedia que no aportan a la ficha.
SECCIONES_FUERA = {"véase también", "referencias", "notas", "bibliografía", "enlaces externos", "fuentes",
                   "see also", "references", "notes", "bibliography", "external links", "further reading", "sources",
                   "citations", "notas y referencias", "lecturas adicionales"}
MAX_TEXTO = 60000
MAX_PERSONAS = 8
MAX_HECHOS = 10
# Tipo de hecho según la clase en Wikidata (etiqueta en español o en inglés).
TIPOS_HECHO = [("batalla", "batalla"), ("battle", "batalla"), ("naval", "batalla"), ("campa", "batalla"), ("asedio", "batalla"), ("siege", "batalla"),
               ("guerra", "batalla"), ("war", "batalla"), ("conquista", "batalla"), ("tratado", "tratado"),
               ("treaty", "tratado"), ("paz", "tratado"), ("revoluci", "revolucion"), ("revolution", "revolucion"),
               ("rebeli", "revolucion"), ("rebellion", "revolucion"), ("fundaci", "fundacion"), ("terremoto", "desastre"),
               ("earthquake", "desastre"), ("epidemia", "desastre"), ("epidemic", "desastre"), ("genocid", "desastre"),
               ("masacre", "desastre"), ("concilio", "religioso"), ("council", "religioso"), ("coronaci", "politico")]


# ---------------------------------------------------------------------------------------------------------------
# Red


def pedir(url: str, params: dict) -> dict:
    url = url + "?" + urllib.parse.urlencode(params)
    for intento in range(5):
        time.sleep(PAUSA)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code in (429, 503) and intento < 4:
                espera = int(e.headers.get("Retry-After") or 0) or 5 * 2 ** intento
                print(f"  el servidor pide esperar ({e.code}): {espera} s", file=sys.stderr)
                time.sleep(min(espera, 120))
                continue
            raise
    raise RuntimeError("sin respuesta")


def wikidata(ids: list[str]) -> dict:
    """Entidades de Wikidata por id, de a 50."""
    out = {}
    ids = [i for i in dict.fromkeys(ids) if re.fullmatch(r"Q\d+", i or "")]
    for k in range(0, len(ids), 50):
        d = pedir("https://www.wikidata.org/w/api.php", {
            "action": "wbgetentities", "ids": "|".join(ids[k:k + 50]), "format": "json",
            "props": "labels|descriptions|claims|sitelinks", "languages": "es|en", "sitefilter": "eswiki|enwiki"})
        out.update(d.get("entities", {}))
    return out


def notables(consulta: str) -> list[str]:
    """Ids de Wikidata de una consulta SPARQL que devuelve ?x, ordenados por cantidad de artículos en Wikipedia."""
    try:
        d = pedir("https://query.wikidata.org/sparql", {"format": "json", "query": consulta})
    except Exception as e:  # una consulta lenta no frena el borrador: se arma con lo demás
        print(f"  la consulta a Wikidata falló ({e}); sigo sin ella", file=sys.stderr)
        return []
    return [f["x"]["value"].rsplit("/", 1)[1] for f in d.get("results", {}).get("bindings", [])]


def wikipedia(lengua: str, params: dict) -> dict:
    return pedir(f"https://{lengua}.wikipedia.org/w/api.php", {"format": "json", "formatversion": 2, **params})


def articulo(lengua: str, titulo: str) -> list[dict]:
    """El artículo completo en texto plano, por secciones: [{titulo, nivel, texto}]."""
    d = wikipedia(lengua, {"action": "query", "prop": "extracts", "explaintext": 1, "exsectionformat": "wiki",
                           "redirects": 1, "titles": titulo})
    paginas = d.get("query", {}).get("pages", [])
    texto = paginas[0].get("extract", "") if paginas else ""
    secciones = [{"titulo": "Introducción", "nivel": 1, "texto": ""}]
    for linea in texto.split("\n"):
        m = re.fullmatch(r"(={2,6})\s*(.*?)\s*\1", linea.strip())
        if m:
            secciones.append({"titulo": m.group(2), "nivel": len(m.group(1)) - 1, "texto": ""})
        elif linea.strip():
            secciones[-1]["texto"] += linea.strip() + "\n"
    out, total, fuera = [], 0, 99
    for s in secciones:
        if s["titulo"].lower() in SECCIONES_FUERA:
            fuera = s["nivel"]
            continue
        if s["nivel"] > fuera:
            continue
        fuera = 99
        s["texto"] = s["texto"].strip()
        if not s["texto"] or total > MAX_TEXTO:
            continue
        total += len(s["texto"])
        out.append(s)
    return out


def resumenes(lengua: str, titulos: list[str]) -> dict:
    """Las primeras oraciones de varios artículos: {título pedido: texto}."""
    out = {}
    titulos = [t for t in dict.fromkeys(titulos) if t]
    for k in range(0, len(titulos), 20):
        d = wikipedia(lengua, {"action": "query", "prop": "extracts", "exintro": 1, "explaintext": 1,
                               "exsentences": 2, "exlimit": 20, "redirects": 1, "titles": "|".join(titulos[k:k + 20])})
        q = d.get("query", {})
        alias = {r["to"]: r["from"] for r in q.get("redirects", []) + q.get("normalized", [])}
        for p in q.get("pages", []):
            t = p.get("title", "")
            out[alias.get(t, t)] = re.sub(r"\s+", " ", p.get("extract", "")).strip()
    return out


# ---------------------------------------------------------------------------------------------------------------
# Wikidata → esquema


def valores(e: dict, prop: str) -> list[dict]:
    """Afirmaciones de una propiedad (sin las desaprobadas), con sus calificadores."""
    out = []
    for s in e.get("claims", {}).get(prop, []):
        if s.get("rank") == "deprecated":
            continue
        dv = s.get("mainsnak", {}).get("datavalue", {}).get("value")
        if dv is not None:
            out.append({"v": dv, "q": s.get("qualifiers", {}), "rank": s.get("rank")})
    out.sort(key=lambda x: x["rank"] != "preferred")
    return out


def anio(valor: dict | None) -> tuple[int | None, bool]:
    """Año de un valor de tiempo de Wikidata y si es aproximado (precisión de década o menos)."""
    if not isinstance(valor, dict) or "time" not in valor:
        return None, False
    m = re.match(r"([+-])(\d+)-", valor["time"])
    if not m:
        return None, False
    n = int(m.group(2)) * (-1 if m.group(1) == "-" else 1)
    if n == 0:  # no existe el año 0: Wikidata a veces lo usa para el 1 a. C.
        return -1, True
    return n, valor.get("precision", 9) < 9


def primer_anio(e: dict, props: list[str]) -> tuple[int | None, bool]:
    for p in props:
        for v in valores(e, p):
            a, aprox = anio(v["v"])
            if a is not None:
                return a, aprox
    return None, False


def coordenadas(e: dict) -> tuple[float, float] | None:
    for v in valores(e, "P625"):
        c = v["v"]
        if isinstance(c, dict) and c.get("globe", "").endswith("Q2"):
            return round(c["longitude"], 3), round(c["latitude"], 3)
    return None


def ids(e: dict, prop: str) -> list[str]:
    return [v["v"]["id"] for v in valores(e, prop) if isinstance(v["v"], dict) and "id" in v["v"]]


def etiqueta(e: dict) -> str:
    lab = e.get("labels", {})
    return (lab.get("es") or lab.get("en") or {}).get("value", e.get("id", ""))


def titulos_wiki(e: dict) -> dict:
    sl = e.get("sitelinks", {})
    return {k[:2]: sl[k]["title"] for k in ("eswiki", "enwiki") if k in sl}


def slug(texto: str) -> str:
    s = unicodedata.normalize("NFKD", texto.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]", "-", s)).strip("-")[:60]


def oraciones(texto: str, n: int) -> str:
    partes = re.split(r"(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ¿¡])", texto.strip())
    return " ".join(partes[:n]).strip()


# ---------------------------------------------------------------------------------------------------------------
# Borrador


def borrador(entrada: dict, entidades_clio: dict, nombres_es: dict) -> dict | None:
    q = entrada["wikidata"]
    principal = wikidata([q]).get(q)
    if not principal or "missing" in principal:
        print(f"  {q}: no está en Wikidata", file=sys.stderr)
        return None
    crudo = entrada.get("entidad", "")
    clio = entidades_clio.get(crudo, {})
    nombre = nombres_es.get(crudo) or etiqueta(principal)
    rid = slug(nombre)
    wiki = titulos_wiki(principal)
    lengua = "es" if "es" in wiki else "en"
    print(f"  {nombre} ({q}): artículo «{wiki.get(lengua, '—')}» en {lengua}.wikipedia")

    # Lo relacionado, en un solo pedido: capitales, personas y hechos.
    capitales = ids(principal, "P36")[:5]
    gente = []
    for p, rol in (("P112", "fundador"), ("P35", "jefe de Estado"), ("P6", "jefe de gobierno"), ("P1037", "dirigente")):
        gente += [(i, rol) for i in ids(principal, p)]
    unicos: dict[str, str] = {}
    for i, rol in gente:
        unicos.setdefault(i, rol)
    # Para los estados históricos, Wikidata casi nunca tiene esas propiedades: se suman las personas más conocidas
    # con esa ciudadanía y los hechos fechados en los que participó (por cantidad de artículos en Wikipedia).
    # Primero quienes ocuparon un cargo de esa entidad (soberanos, visires…); después, quienes nacieron con su
    # ciudadanía al menos 20 años antes de que terminara (si no, aparecen personas famosas por lo que hicieron después).
    fin = clio.get("b") or 2100
    if len(unicos) < MAX_PERSONAS:
        for i in notables(f"SELECT DISTINCT ?x ?n WHERE {{ ?x wdt:P39 ?c. ?c wdt:P1001 wd:{q}. ?x wdt:P31 wd:Q5; "
                          f"wikibase:sitelinks ?n. }} ORDER BY DESC(?n) LIMIT {MAX_PERSONAS}"):
            unicos.setdefault(i, "")
    if len(unicos) < MAX_PERSONAS:
        for i in notables(f"SELECT ?x ?n WHERE {{ ?x wdt:P27 wd:{q}; wdt:P31 wd:Q5; wdt:P569 ?b; wikibase:sitelinks ?n. "
                          f"FILTER(YEAR(?b) < {fin - 20}) }} ORDER BY DESC(?n) LIMIT {MAX_PERSONAS * 2}"):
            unicos.setdefault(i, "")
    gente = list(unicos.items())[:MAX_PERSONAS * 2]
    hechos_ids = ids(principal, "P793")
    if len(hechos_ids) < MAX_HECHOS:
        hechos_ids += notables(f"SELECT DISTINCT ?x ?n WHERE {{ {{ ?x wdt:P710 wd:{q}; wdt:P585|wdt:P580 ?t }} UNION "
                               f"{{ ?x wdt:P17 wd:{q}; wdt:P585 ?t }} ?x wikibase:sitelinks ?n. "
                               f"FILTER NOT EXISTS {{ ?x wdt:P31 wd:Q5 }} }} "
                               f"ORDER BY DESC(?n) LIMIT {MAX_HECHOS * 2}")
    hechos_ids = list(dict.fromkeys(hechos_ids))[:MAX_HECHOS * 2]
    rel = wikidata(capitales + [g[0] for g in gente] + hechos_ids)
    # Segundo pedido: los lugares de nacimiento, muerte y de los hechos, para sus coordenadas.
    lugares_ids = []
    for e in rel.values():
        lugares_ids += ids(e, "P19")[:1] + ids(e, "P20")[:1] + ids(e, "P276")[:1]
    for i in hechos_ids:
        lugares_ids += ids(rel.get(i, {}), "P31")[:3]
    sitios = wikidata(lugares_ids)
    todos = {**rel, **sitios}

    titulos_res = [titulos_wiki(rel[i]).get(lengua) for i in capitales + [g[0] for g in gente] + hechos_ids if i in rel]
    res = resumenes(lengua, titulos_res + [wiki.get(lengua)])
    secciones = articulo(lengua, wiki[lengua]) if lengua in wiki else []

    def resumen_de(e: dict) -> str:
        t = titulos_wiki(e).get(lengua)
        return oraciones(res.get(t, ""), 2) if t else ""

    def punto(e: dict | None) -> dict:
        if not e:
            return {}
        c = coordenadas(e)
        out = {"lugar": etiqueta(e)}
        if c:
            out.update({"lon": c[0], "lat": c[1]})
        return out

    lugares = []
    for i in capitales:
        e = rel.get(i)
        c = coordenadas(e) if e else None
        if not c:
            continue
        fundado, aprox = primer_anio(e, ["P571"])
        lugares.append({"id": slug(etiqueta(e)), "nombre": etiqueta(e), "lon": c[0], "lat": c[1],
                        "fundacion": fundado, "abandono": None, "aprox": True if fundado is None else aprox,
                        "tipo": "capital", "importancia": 3, "resumen": resumen_de(e), "regiones": [rid],
                        "wikipedia": titulos_wiki(e)})

    personas = []
    for i, rol in gente:
        e = rel.get(i)
        if not e or len(personas) >= MAX_PERSONAS:
            continue
        nace, nace_aprox = primer_anio(e, ["P569"])
        muere, muere_aprox = primer_anio(e, ["P570"])
        if nace is None and muere is None:
            continue
        def vida(a, aprox, lugar_id):
            if a is None:
                return None
            return {"anio": a, "aprox": aprox, **punto(todos.get(lugar_id))}
        personas.append({"id": slug(etiqueta(e)), "nombre": etiqueta(e),
                         "nacimiento": vida(nace, nace_aprox, (ids(e, "P19") or [None])[0]),
                         "muerte": vida(muere, muere_aprox, (ids(e, "P20") or [None])[0]),
                         "roles": [r for r in [rol or e.get("descriptions", {}).get("es", {}).get("value", "")] if r],
                         "resumen": resumen_de(e), "obras": [], "wikipedia": titulos_wiki(e),
                         "wikidata": i})

    hechos = []
    for i in hechos_ids:
        e = rel.get(i)
        if not e or len(hechos) >= MAX_HECHOS:
            continue
        a, aprox = primer_anio(e, ["P585", "P580", "P571"])
        if a is None:
            continue
        hasta, _ = primer_anio(e, ["P582"])
        lugar = next((x for x in ids(e, "P276") if x != q), None)
        sitio = punto(todos.get(lugar)) if lugar else {}
        if "lon" not in sitio and coordenadas(e):
            c = coordenadas(e)
            sitio = {"lugar": sitio.get("lugar", ""), "lon": c[0], "lat": c[1]}
        clases = " ".join(etiqueta(todos[x]).lower() for x in ids(e, "P31") if x in todos)
        tipo = next((t for clave, t in TIPOS_HECHO if clave in clases), "politico")
        hechos.append({"id": slug(etiqueta(e)), "titulo": etiqueta(e), "anio": a,
                       "anio_hasta": hasta if hasta and hasta != a else None, "aprox": aprox, **sitio,
                       "tipo": tipo, "resumen": resumen_de(e), "regiones": [rid], "fuentes": [],
                       "wikipedia": titulos_wiki(e)})

    desde = clio.get("a") or primer_anio(principal, ["P571"])[0]
    hasta = clio.get("b") or primer_anio(principal, ["P576"])[0]
    intro = res.get(wiki.get(lengua), "") if lengua in wiki else ""
    region = {"id": rid, "nombre": nombre, "padre": None, "poligono": [], "resumen": oraciones(intro, 3), "eras": []}
    if desde is not None:
        region["eras"].append({"desde": desde, "hasta": hasta, "nombre": nombre, "resumen": oraciones(intro, 1)})

    sugerencias = []
    for p, que in (("P37", "Idioma oficial"), ("P140", "Religión"), ("P38", "Moneda")):
        nombres = [etiqueta(x) for x in wikidata(ids(principal, p)[:5]).values()] if ids(principal, p) else []
        if nombres:
            sugerencias.append(f"{que} según Wikidata: {', '.join(nombres)}. Si corresponde, cargarlo en la región con su familia.")
    if lengua == "en":
        sugerencias.append("No hay artículo en español: los resúmenes están en inglés y hay que traducirlos.")

    return {
        "paquete": f"borrador-{rid}",
        "descripcion": f"Borrador automático: {nombre}",
        "borrador": {
            "titulo": nombre,
            "estado": "sin revisar",
            "generado": date.today().isoformat(),
            "por": "tools/enciclopedia/borradores.py",
            "origen": {"entidad": crudo, "wikidata": q, "veces": entrada.get("veces"), "anios": entrada.get("anios", []),
                       "lon": entrada.get("lon"), "lat": entrada.get("lat")},
            "fuentes": {"wikidata": f"https://www.wikidata.org/wiki/{q}",
                        "wikipedia": f"https://{lengua}.wikipedia.org/wiki/{urllib.parse.quote(wiki[lengua].replace(' ', '_'))}" if lengua in wiki else None},
            "licencia": "Los textos tomados de Wikipedia son CC BY-SA 4.0; los datos de Wikidata, CC0.",
            "sugerencias": sugerencias,
            "articulo": {"lengua": lengua, "titulo": wiki.get(lengua), "secciones": secciones},
        },
        "regiones": [region],
        "fuentes": [],
        "personas": personas,
        "hechos": hechos,
        "lugares": lugares,
    }


def cola_por_defecto() -> Path:
    if sys.platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", "~")) / "Godot"
    elif sys.platform == "darwin":
        base = Path("~/Library/Application Support/Godot")
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", "~/.local/share")) / "godot"
    return (base / "app_userdata" / "TellMAP" / "pendientes.json").expanduser()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("-n", type=int, default=3, help="cuántas entradas de la cola (las más consultadas)")
    ap.add_argument("--cola", type=Path, default=None, help="archivo de la cola (por defecto, el de la app)")
    ap.add_argument("--wikidata", nargs="*", default=[], help="ids de Wikidata puntuales, en vez de la cola")
    ap.add_argument("--salida", type=Path, default=DIR_BORRADORES)
    ap.add_argument("--rehacer", action="store_true", help="volver a armar los que ya tienen borrador")
    a = ap.parse_args()

    politico = json.loads((RAIZ / "data/mapa/politico.json").read_text(encoding="utf-8"))
    clio = {e["n"]: e for e in politico["entidades"]}
    por_q = {}
    for e in politico["entidades"]:
        por_q.setdefault(e["d"], e)
    nombres_es = json.loads((RAIZ / "data/mapa/nombres_es.json").read_text(encoding="utf-8"))

    if a.wikidata:
        entradas = [{"wikidata": q, "entidad": por_q.get(q, {}).get("n", ""), "veces": 0, "anios": []} for q in a.wikidata]
    else:
        ruta = a.cola or cola_por_defecto()
        if not ruta.exists():
            print(f"No encontré la cola de consultas en {ruta}. Usá --cola o --wikidata.", file=sys.stderr)
            return 1
        cola = json.loads(ruta.read_text(encoding="utf-8"))
        entradas = []
        for clave, item in cola.items():
            if clave.startswith("entidad:") and re.fullmatch(r"Q\d+", str(item.get("wikidata", ""))):
                entradas.append({**item, "entidad": clave[8:]})
        entradas.sort(key=lambda x: -int(x.get("veces", 0)))

    a.salida.mkdir(parents=True, exist_ok=True)
    hechos_q = set()
    for f in a.salida.glob("*.json"):
        hechos_q.add(json.loads(f.read_text(encoding="utf-8")).get("borrador", {}).get("origen", {}).get("wikidata"))
    hechos = 0
    for entrada in entradas:
        if hechos >= a.n:
            break
        if entrada["wikidata"] in hechos_q and not a.rehacer:
            print(f"  {entrada['wikidata']}: ya tiene borrador (--rehacer para volver a armarlo)")
            continue
        b = borrador(entrada, clio, nombres_es)
        if not b:
            continue
        destino = a.salida / f"{b['regiones'][0]['id']}.json"
        destino.write_text(json.dumps(b, ensure_ascii=False, indent=2), encoding="utf-8")
        n = {s: len(b[s]) for s in ("personas", "hechos", "lugares")}
        print(f"  → {destino.relative_to(RAIZ) if destino.is_relative_to(RAIZ) else destino}: "
              f"{n['personas']} personas, {n['hechos']} hechos, {n['lugares']} lugares, "
              f"{len(b['borrador']['articulo']['secciones'])} secciones del artículo")
        hechos += 1
    print(f"{hechos} borrador(es). Revisalos en la app: Ajustes → Abrir el editor → Borradores.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
