"""Arma los paquetes temáticos de la época contemporánea desde temas/<tema>/ y los verifica contra Wikipedia y Wikidata.

Uso: python3 tools/enciclopedia/compacto/construir.py <carpeta de temas> [--tema <tema>] [--escribir]

- Con --tema verifica y arma solo ese tema (para iterar mientras se escribe); igual lee los demás temas para resolver
  referencias cruzadas (autores, fuentes, lugares) y detectar ids repetidos. Deja temas/<tema>/salida.json e
  informe.txt. No toca el repo.
- Sin --tema arma todos. Con --escribir copia los paquetes a data/enciclopedia/paquetes/, suma las familias nuevas y
  agrega las obras nuevas a los autores que ya estaban en otros paquetes.

Formato de cada tema: ver FORMATO.md, en esta carpeta. La carpeta de temas tiene una subcarpeta por tema (con su
meta.txt) y puede vivir fuera del repo: los paquetes JSON que salen de acá son la versión que vale.
"""
import importlib.util
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
TEMAS = Path(sys.argv[1]).resolve()
ACT = TEMAS
ESCRIBIR = "--escribir" in sys.argv
SOLO = sys.argv[sys.argv.index("--tema") + 1] if "--tema" in sys.argv else None
sys.path.insert(0, str(RAIZ / "tools" / "enciclopedia"))
import borradores as B  # noqa: E402

PAQ = RAIZ / "data" / "enciclopedia" / "paquetes"
CACHE_GLOBAL = TEMAS / "cache-comun.json"
CACHE = (TEMAS / SOLO / "cache.json") if SOLO else (ACT / "cache.json")
cache = {"wp": {}, "wd": {}, "url": {}}
for f in [CACHE_GLOBAL, ACT / "cache.json"] + sorted(TEMAS.glob("*/cache.json")) + [CACHE]:
    if f.exists():
        try:
            c = json.loads(f.read_text())
        except json.JSONDecodeError:
            continue
        for k in cache:
            cache[k].update(c.get(k, {}))

GENEROS = {"religioso", "historia", "cronica", "literatura", "poesia", "filosofia", "legal", "administrativo",
           "epistolar", "inscripcion", "geografia", "ciencia", "medicina", "sabiduria", "viajes", "ensayo",
           "arqueologia", "economia", "politica", "manifiesto", "discurso", "tecnologia", "periodismo"}
TIPOS_HECHO = {"politico", "batalla", "fundacion", "religioso", "cultural", "cientifico", "economico", "desastre",
               "tratado", "construccion", "exploracion", "revolucion", "judicial"}
TIPOS_LUGAR = {"ciudad", "capital", "templo", "puerto", "sitio-arqueologico", "biblioteca", "universidad",
               "laboratorio", "institucion", "sitio-historico"}

informes: dict[str, list[str]] = {}
tema_actual = [""]
CTX = [""]


def guardar_cache():
    CACHE.write_text(json.dumps(cache, ensure_ascii=False))


def aviso(t):
    informes.setdefault(tema_actual[0], []).append(t)


# ---------------------------------------------------------------------------------------------------------------
# Lectura


def lineas(dirt, patron):
    for f in sorted(dirt.glob(patron)):
        for n, l in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if l.strip() and not l.startswith("#"):
                yield [x.strip() for x in l.split("|")], f"{f.name}:{n}"


def bloques(dirt, patron):
    for f in sorted(dirt.glob(patron)):
        actual = None
        for n, l in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if l.startswith("## "):
                actual = {"id": l[3:].strip(), "_donde": f"{f.name}:{n}"}
                yield actual
            elif actual is not None and re.match(r"^[a-z]+: ", l):
                k, v = l.split(": ", 1)
                actual[k] = v.strip()


def anios(s):
    s = s.strip()
    aprox = s.endswith("~")
    s = s.rstrip("~")
    m = re.fullmatch(r"(-?\d+)(?:-(-?\d+))?", s)
    if not m:
        raise ValueError(f"años inválidos: {s!r}")
    a = int(m.group(1))
    b = int(m.group(2)) if m.group(2) else None
    return a, b, aprox


def wiki_campo(campo):
    """'Title', 'Title ;; Título es', 'es:Título' (artículo solo en español) o '-'. Devuelve (clave de caché, es forzado)."""
    if not campo or campo == "-":
        return None, None
    if campo.startswith("es:"):
        return "es:" + campo[3:].strip(), None
    if " ;; " in campo:
        en, es = campo.split(" ;; ", 1)
        return en.strip(), es.strip()
    return campo.strip(), None


# ---------------------------------------------------------------------------------------------------------------
# Wikipedia y Wikidata


def resolver_titulos(claves):
    for lengua in ("en", "es"):
        pref = "es:" if lengua == "es" else ""
        faltan = [c for c in dict.fromkeys(claves) if c and c not in cache["wp"] and c.startswith("es:") == (lengua == "es")]
        for k in range(0, len(faltan), 40):
            grupo = faltan[k:k + 40]
            titulos = [c[len(pref):] for c in grupo]
            d = B.wikipedia(lengua, {"action": "query", "titles": "|".join(titulos), "redirects": 1, "prop": "pageprops",
                                     "ppprop": "wikibase_item|disambiguation"})
            if "error" in d:
                raise RuntimeError(d["error"])
            q = d.get("query", {})
            alias = {r["from"]: r["to"] for r in q.get("normalized", []) + q.get("redirects", [])}
            paginas = {p["title"]: p for p in q.get("pages", [])}
            for c, t in zip(grupo, titulos):
                final = t
                for _ in range(3):
                    final = alias.get(final, final)
                p = paginas.get(final, {})
                cache["wp"][c] = {"titulo": final, "falta": bool(p.get("missing")) or not p,
                                  "qid": p.get("pageprops", {}).get("wikibase_item"),
                                  "desamb": "disambiguation" in p.get("pageprops", {})}
            guardar_cache()


def recortar(e):
    out = {"sl": {k: v["title"] for k, v in e.get("sitelinks", {}).items() if k in ("eswiki", "enwiki")},
           "lab": {k: v["value"] for k, v in e.get("labels", {}).items()}, "c": {}}
    for p in ("P625", "P569", "P570", "P19", "P20", "P571", "P577", "P585", "P580"):
        if p in e.get("claims", {}):
            out["c"][p] = [{"v": v["v"], "rank": v["rank"]} for v in B.valores(e, p)]
    return out


def traer_entidades(qids):
    faltan = [q for q in dict.fromkeys(qids) if q and cache["wd"].get(q, {}).get("_v") != 2]
    for k in range(0, len(faltan), 50):
        for q, e in B.wikidata(faltan[k:k + 50]).items():
            cache["wd"][q] = recortar(e)
            cache["wd"][q]["_v"] = 2
        guardar_cache()


def ent(q):
    return cache["wd"].get(q or "", {})


def coords_ent(q):
    for v in ent(q).get("c", {}).get("P625", []):
        c = v["v"]
        if isinstance(c, dict) and str(c.get("globe", "")).endswith("Q2"):
            return float(round(c["longitude"], 3)), float(round(c["latitude"], 3))
    return None


def anio_ent(q, p):
    for v in ent(q).get("c", {}).get(p, []):
        a, aprox = B.anio(v["v"])
        if a is not None:
            return a, aprox
    return None, False


def lugar_ent(q, p):
    for v in ent(q).get("c", {}).get(p, []):
        if isinstance(v["v"], dict) and "id" in v["v"]:
            return v["v"]["id"]
    return None


def etiqueta(q):
    lab = ent(q).get("lab", {})
    return lab.get("es") or lab.get("en") or q


def wikipedia_de(clave, es_forzado=None, donde=""):
    if not clave:
        return {}, None
    r = cache["wp"].get(clave)
    if not r or r["falta"]:
        aviso(f"SIN ARTÍCULO en {'es' if clave.startswith('es:') else 'en'}.wikipedia: «{clave}» ({donde})")
        return {}, None
    if r["desamb"]:
        aviso(f"DESAMBIGUACIÓN: «{clave}» ({donde})")
    out = {}
    sl = ent(r["qid"]).get("sl", {})
    if clave.startswith("es:"):
        out["es"] = r["titulo"]
        if sl.get("enwiki"):
            out["en"] = sl["enwiki"]
    else:
        es = es_forzado or sl.get("eswiki")
        if es:
            out["es"] = es
        out["en"] = r["titulo"]
    return out, r["qid"]


# ---------------------------------------------------------------------------------------------------------------
# Geometría


def dentro(lon, lat, poli):
    n, adentro = len(poli), False
    j = n - 1
    for i in range(n):
        xi, yi = poli[i]
        xj, yj = poli[j]
        if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi) + xi:
            adentro = not adentro
        j = i
    return adentro


def area(poli):
    return abs(sum(poli[i][0] * poli[i - 1][1] - poli[i - 1][0] * poli[i][1] for i in range(len(poli)))) / 2


# ---------------------------------------------------------------------------------------------------------------


def leer_tema(dirt):
    meta = {}
    for l in (dirt / "meta.txt").read_text(encoding="utf-8").splitlines():
        if ": " in l and not l.startswith("#"):
            k, v = l.split(": ", 1)
            meta[k.strip()] = v.strip()
    t = {"dir": dirt, "nombre": meta.get("paquete", dirt.name), "descripcion": meta.get("descripcion", ""),
         "fam": list(lineas(dirt, "familias*.txt")), "lug": list(lineas(dirt, "lugares*.txt")),
         "gaz": list(lineas(dirt, "gaz*.txt")), "per": list(lineas(dirt, "personas*.txt")),
         "hec": list(lineas(dirt, "hechos*.txt")), "fue": list(bloques(dirt, "fuentes*.txt")),
         "leer": list(lineas(dirt, "leer*.txt")), "reg": None}
    if (dirt / "regiones.py").exists():
        spec = importlib.util.spec_from_file_location(f"reg_{dirt.name}", dirt / "regiones.py")
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        t["reg"] = m
    return t


def main():
    temas = {d.name: leer_tema(d) for d in sorted(TEMAS.iterdir()) if d.is_dir() and (d / "meta.txt").exists()}
    if SOLO and SOLO not in temas:
        sys.exit(f"no existe el tema {SOLO} (falta temas/{SOLO}/meta.txt)")
    nombres_nuevos = {t["nombre"] + ".json" for t in temas.values()}
    existentes = {}
    for f in sorted(PAQ.glob("*.json")):
        if f.name not in nombres_nuevos:
            existentes[f.name] = json.loads(f.read_text(encoding="utf-8"))

    regiones_todas = {}
    for d in existentes.values():
        for r in d.get("regiones", []):
            regiones_todas[r["id"]] = r["poligono"]
    for t in temas.values():
        if t["reg"]:
            regiones_todas.update(t["reg"].POLIGONOS)
    orden_regiones = sorted(regiones_todas, key=lambda k: area(regiones_todas[k]))

    def regiones_de(lon, lat):
        return [k for k in orden_regiones if dentro(lon, lat, regiones_todas[k])]

    construir = [SOLO] if SOLO else list(temas)

    # ---- títulos a resolver (solo de los temas que se construyen)
    claves = []
    for n in construir:
        t = temas[n]
        claves += [wiki_campo(x[5])[0] for x, _ in t["fam"]] + [wiki_campo(x[6])[0] for x, _ in t["lug"] if len(x) > 6]
        claves += [wiki_campo(x[2])[0] for x, _ in t["gaz"] if len(x) > 2]
        claves += [wiki_campo(x[6])[0] for x, _ in t["per"] if len(x) > 6]
        claves += [wiki_campo(x[6])[0] for x, _ in t["hec"] if len(x) > 6]
        claves += [wiki_campo(b.get("w", ""))[0] for b in t["fue"]]
    resolver_titulos([c for c in claves if c])
    traer_entidades([cache["wp"][c]["qid"] for c in claves if c and cache["wp"].get(c, {}).get("qid")])
    qids_per = [cache["wp"].get(wiki_campo(x[6])[0] or "", {}).get("qid") for n in construir for x, _ in temas[n]["per"] if len(x) > 6]
    traer_entidades([lugar_ent(q, p) for q in qids_per if q for p in ("P19", "P20")])

    # ---- nomenclátor global: lugares existentes, gaz y lugares de todos los temas
    lugar_pt = {}
    for d in existentes.values():
        for l in d.get("lugares", []):
            if "lon" in l:
                lugar_pt[l["id"]] = {"lugar": l["nombre"], "lon": l["lon"], "lat": l["lat"]}
    gaz_dueno = {}
    for n, t in temas.items():
        tema_actual[0] = n
        for x, donde in t["gaz"]:
            if len(x) < 2:
                if n in construir:
                    aviso(f"LÍNEA INCOMPLETA [{donde}]")
                continue
            clave, nombre = x[0], x[1]
            en = wiki_campo(x[2])[0] if len(x) > 2 else None
            r = cache["wp"].get(en or "", {})
            c = coords_ent(r.get("qid")) if r and not r.get("falta") else None
            if len(x) > 3 and x[3]:
                c = tuple(float(v) for v in x[3].strip("[] ").split(","))
            if not c:
                if n in construir:
                    aviso(f"SIN COORDENADAS: nomenclátor «{clave}» ({en}) [{donde}]")
                continue
            if clave in gaz_dueno and gaz_dueno[clave] != n and n in construir:
                aviso(f"CLAVE DE NOMENCLÁTOR TAMBIÉN EN {gaz_dueno[clave]}: {clave} (vale, si es el mismo lugar)")
            gaz_dueno.setdefault(clave, n)
            lugar_pt.setdefault(clave, {"lugar": nombre, "lon": c[0], "lat": c[1]})

    lugares_por_tema = {}
    for n, t in temas.items():
        tema_actual[0] = n
        lugares_por_tema[n] = []
        for x, donde in t["lug"]:
            if len(x) < 8:
                if n in construir:
                    aviso(f"LÍNEA INCOMPLETA [{donde}]")
                continue
            iid, nombre, fund, aband, tipo, imp, en, resumen = x[:8]
            clave, esf = wiki_campo(en)
            if n in construir:
                w, q = wikipedia_de(clave, esf, donde=f"lugar {iid}")
            else:
                r = cache["wp"].get(clave or "", {})
                w, q = {}, r.get("qid")
            c = coords_ent(q)
            if len(x) > 8 and x[8]:
                c = tuple(float(v) for v in x[8].strip("[] ").split(","))
            if not c:
                if n in construir:
                    aviso(f"SIN COORDENADAS: lugar «{iid}» ({en}) [{donde}]")
                continue
            lugar_pt[iid] = {"lugar": nombre, "lon": c[0], "lat": c[1]}
            if n not in construir:
                continue
            try:
                anios(fund) if fund != "-" else None
                anios(aband) if aband != "-" else None
                int(imp)
            except ValueError as e:
                aviso(f"LÍNEA INVÁLIDA [{donde}]: {e}")
                continue
            if tipo not in TIPOS_LUGAR:
                aviso(f"TIPO DE LUGAR NO PREVISTO: {tipo} ({iid})")
            fa, _, fax = anios(fund) if fund != "-" else (None, None, False)
            ab = anios(aband)[0] if aband != "-" else None
            regs = regiones_de(*c)
            if not regs:
                aviso(f"FUERA DE TODA REGIÓN: lugar «{iid}» en {c}")
            el = {"id": iid, "nombre": nombre, "lon": c[0], "lat": c[1], "fundacion": fa, "abandono": ab, "aprox": fax,
                  "tipo": tipo, "importancia": int(imp), "resumen": resumen, "regiones": regs}
            if w:
                el["wikipedia"] = w
            lugares_por_tema[n].append(el)

    def punto(ref, donde, q_articulo=None):
        ref = ref.strip()
        if ref.startswith("="):
            return {"lugar": ref[1:]}
        if not ref.startswith("@"):
            raise ValueError(f"{donde}: lugar inválido {ref!r}")
        clave, _, texto = ref[1:].partition("=")
        if clave == "":
            c = coords_ent(q_articulo)
            if not c:
                aviso(f"SIN COORDENADAS en el artículo: {donde} ({texto})")
                return {"lugar": texto}
            return {"lugar": texto, "lon": c[0], "lat": c[1]}
        if clave not in lugar_pt:
            aviso(f"LUGAR DESCONOCIDO: «{clave}» ({donde})")
            return {"lugar": texto or clave}
        p = dict(lugar_pt[clave])
        if texto:
            p["lugar"] = texto
        return p

    # ---- ids de todos los temas (para referencias cruzadas)
    personas_exist = {p["id"]: p for d in existentes.values() for p in d.get("personas", [])}
    nombres_personas = {x[0]: x[1] for t in temas.values() for x, _ in t["per"] if len(x) > 1}
    fuentes_ids = {f["id"] for d in existentes.values() for f in d.get("fuentes", [])}
    fuentes_ids |= {b["id"] for t in temas.values() for b in t["fue"]}
    regiones_ids = set(regiones_todas)

    paquetes = {}
    obras_por_autor = {}
    for n in construir:
        t = temas[n]
        tema_actual[0] = n
        # ---- personas
        personas, por_id = [], {}
        for x, donde in t["per"]:
            CTX[0] = f"{n} {donde}"
            if len(x) < 8:
                aviso(f"LÍNEA INCOMPLETA [{donde}]")
                continue
            iid, nombre, nac, mue, act, roles, en, resumen = x[:8]
            clave, esf = wiki_campo(en)
            w, q = wikipedia_de(clave, esf, donde=f"persona {iid}")
            el = {"id": iid, "nombre": nombre}
            for k, campo, prop_a, prop_l in (("nacimiento", nac, "P569", "P19"), ("muerte", mue, "P570", "P20")):
                if not campo:
                    continue
                partes = campo.split(" ", 1)
                a, _, ax = anios(partes[0])
                v = {"anio": a, "aprox": ax}
                if len(partes) > 1:
                    ref = partes[1].strip()
                    if ref == "@wd":
                        lq = lugar_ent(q, prop_l)
                        c = coords_ent(lq)
                        if lq and c:
                            v.update({"lugar": etiqueta(lq), "lon": c[0], "lat": c[1]})
                        elif lq:
                            aviso(f"LUGAR DE WIKIDATA SIN COORDENADAS: {iid} {k} = {etiqueta(lq)}")
                        else:
                            aviso(f"WIKIDATA NO TIENE LUGAR: {iid} {k}")
                    else:
                        v.update(punto(ref, f"persona {iid} {k}"))
                wa, wax = anio_ent(q, prop_a)
                if wa is not None and abs(wa - a) > (15 if ax or wax else 0):
                    aviso(f"FECHA DISTINTA: {iid} {k} {a}{'~' if ax else ''} vs Wikidata {wa}{'~' if wax else ''}")
                el[k] = v
            if not mue:
                wa, _ = anio_ent(q, "P570")
                if wa is not None:
                    aviso(f"WIKIDATA DA MUERTE Y NO LA PUSISTE: {iid} murió en {wa}")
            if act:
                # los años van al final; el lugar puede tener espacios (`=Dos palabras 1900-1910`)
                partes = act.rsplit(" ", 1)
                if len(partes) > 1 and not re.fullmatch(r"-?\d+(?:-(-?\d+))?~?", partes[1].strip()):
                    partes = [act]
                v = punto(partes[0], f"persona {iid} activo")
                if len(partes) > 1:
                    a, b, ax = anios(partes[1])
                    v["desde"] = a
                    v["hasta"] = b if b is not None else a
                    v["aprox"] = ax
                el["activo"] = v
            el["roles"] = [r.strip() for r in roles.split(",") if r.strip()]
            el["resumen"] = resumen
            el["obras"] = []
            if w:
                el["wikipedia"] = w
            if q:
                el["wikidata"] = q
            personas.append(el)
            por_id[iid] = el

        # ---- fuentes
        fuentes = []
        for b in t["fue"]:
            iid = b["id"]
            CTX[0] = f"{n} {b['_donde']}"
            faltan = [k for k in ("t", "k", "e", "tr", "r") if k not in b]
            if faltan:
                aviso(f"FUENTE INCOMPLETA {iid}: falta {faltan} [{b['_donde']}]")
                continue
            tipo, genero = b["k"].split()
            if genero not in GENEROS:
                aviso(f"GÉNERO NO PREVISTO: {genero} ({iid})")
            clave, esf = wiki_campo(b.get("w", ""))
            w, q = wikipedia_de(clave, esf, donde=f"fuente {iid}")
            autor, autor_id = None, None
            if b.get("a", "").startswith("="):
                autor = b["a"][1:]
            elif b.get("a"):
                autor_id = b["a"]
                if autor_id in por_id:
                    autor = por_id[autor_id]["nombre"]
                elif autor_id in personas_exist:
                    autor = personas_exist[autor_id]["nombre"]
                elif autor_id in nombres_personas:
                    autor = nombres_personas[autor_id]
                else:
                    aviso(f"AUTOR DESCONOCIDO: {autor_id} (fuente {iid})")
                    autor_id = None
                if autor_id:
                    obras_por_autor.setdefault(autor_id, []).append(iid)
            ea, eb, eax = anios(b["e"].split(" ", 1)[0])
            esc = {"anio": ea}
            if eb is not None:
                esc["anio_hasta"] = eb
            esc["aprox"] = eax
            if " " in b["e"]:
                esc.update(punto(b["e"].split(" ", 1)[1], f"fuente {iid} escrita"))
            for prop in ("P577", "P571"):
                wa, wax = anio_ent(q, prop)
                if wa is not None and not eax and abs(wa - ea) > 1 and (eb is None or not (ea <= wa <= eb)):
                    aviso(f"AÑO DISTINTO: fuente {iid} {ea} vs Wikidata {prop} {wa} (revisar: puede ser otra edición)")
                    break
            regs_t, rango = b["tr"].split(" ", 1) if " " in b["tr"] else (b["tr"], None)
            regs_t = [] if regs_t == "-" else [r.strip() for r in regs_t.split(",")]
            for r in regs_t:
                if r not in regiones_ids:
                    aviso(f"REGIÓN DESCONOCIDA: {r} (fuente {iid})")
            regs_t = [r for r in regs_t if r in regiones_ids]
            if rango:
                ta, tb, _ = anios(rango)
            else:
                ta, tb = ea, eb
            el = {"id": iid, "titulo": b["t"], "titulo_original": b.get("to"), "autor": autor, "autor_id": autor_id,
                  "tipo": tipo, "genero": genero, "escrita": esc,
                  "trata": {"regiones": regs_t, "desde": ta, "hasta": tb if tb is not None else ta},
                  "idioma_original": b.get("io"), "soporte": b.get("so"), "resumen": b["r"],
                  "por_que_importa": b.get("p"), "leer": []}
            if w:
                el["wikipedia"] = w
            el["confianza"] = b.get("c", "alta")
            fuentes.append(el)

        # ---- enlaces de lectura, comprobados (200)
        por_fuente = {f["id"]: f for f in fuentes}
        for x, donde in t["leer"]:
            fid, ref, desc, lengua = x[:4]
            dp = True
            if fid not in por_fuente:
                aviso(f"LEER: fuente desconocida {fid} [{donde}]")
                continue
            if ref.startswith("pg:"):
                url = "https://www.gutenberg.org/ebooks/" + ref[3:]
            elif ref.startswith("url:"):
                url = ref[4:]
                dp = len(x) > 4 and x[4] == "dp"
            elif ref.startswith("ws:"):
                _, lw, titulo = ref.split(":", 2)
                url = f"https://{lw}.wikisource.org/wiki/" + urllib.parse.quote(titulo.replace(" ", "_"))
            else:
                aviso(f"LEER: referencia inválida {ref} [{donde}]")
                continue
            if url not in cache["url"] or cache["url"][url] != 200:
                try:
                    req = urllib.request.Request(url, headers={"User-Agent": B.UA})
                    with urllib.request.urlopen(req, timeout=60) as r:
                        cache["url"][url] = r.status
                except Exception as e:  # noqa: BLE001
                    cache["url"][url] = getattr(e, "code", str(e))
                guardar_cache()
            if cache["url"][url] != 200:
                aviso(f"LEER: {url} respondió {cache['url'][url]} ({fid})")
                continue
            por_fuente[fid]["leer"].append({"titulo": desc, "url": url, "idioma": lengua, "dominio_publico": dp})

        # ---- hechos
        hechos = []
        for x, donde in t["hec"]:
            CTX[0] = f"{n} {donde}"
            if len(x) < 8:
                aviso(f"LÍNEA INCOMPLETA [{donde}]")
                continue
            iid, titulo, an, lug, tipo, fts, en, resumen = x[:8]
            extra = [r.strip() for r in x[8].split(",")] if len(x) > 8 and x[8] else []
            if tipo not in TIPOS_HECHO:
                aviso(f"TIPO DE HECHO NO PREVISTO: {tipo} ({iid})")
            clave, esf = wiki_campo(en)
            w, q = wikipedia_de(clave, esf, donde=f"hecho {iid}")
            a, b, ax = anios(an)
            for prop in ("P585", "P580"):
                wa, _ = anio_ent(q, prop)
                if wa is not None and not ax and abs(wa - a) > 0 and (b is None or not (a <= wa <= b)):
                    aviso(f"AÑO DISTINTO: hecho {iid} {a} vs Wikidata {prop} {wa}")
                    break
            p = punto(lug, f"hecho {iid}", q)
            el = {"id": iid, "titulo": titulo, "anio": a, "anio_hasta": b, "aprox": ax, "lugar": p.get("lugar")}
            regs = []
            if "lon" in p:
                el["lon"], el["lat"] = p["lon"], p["lat"]
                regs = regiones_de(p["lon"], p["lat"])
            for r in extra:
                if r not in regiones_ids:
                    aviso(f"REGIÓN DESCONOCIDA: {r} (hecho {iid})")
                elif r not in regs:
                    regs.append(r)
            if not regs:
                aviso(f"HECHO SIN REGIÓN: {iid}")
            fl = [f.strip() for f in fts.split(",") if f.strip() and f.strip() != "-"]
            for f in fl:
                if f not in fuentes_ids:
                    aviso(f"FUENTE DESCONOCIDA: {f} (hecho {iid})")
            fl = [f for f in fl if f in fuentes_ids]
            el.update({"tipo": tipo, "resumen": resumen, "regiones": regs, "fuentes": fl})
            if w:
                el["wikipedia"] = w
            hechos.append(el)

        # ---- familias
        familias = []
        for x, donde in t["fam"]:
            capa, iid, nombre, padre, color, en = x[:6]
            nota = x[6] if len(x) > 6 and x[6] else None
            w, _ = wikipedia_de(wiki_campo(en)[0], donde=f"familia {capa}/{iid}")
            el = {"capa": capa, "id": iid, "nombre": nombre, "padre": None if padre == "-" else padre, "color": color}
            if nota:
                el["nota"] = nota
            if w:
                el["wikipedia"] = w
            familias.append(el)

        # ---- regiones (opcionales)
        regiones = []
        if t["reg"]:
            R = t["reg"]
            for r in R.REGIONES:
                el = {"id": r["id"], "nombre": r["nombre"], "padre": getattr(R, "PADRES", {}).get(r["id"]),
                      "poligono": R.POLIGONOS[r["id"]], "resumen": r["resumen"], "eras": r["eras"]}
                for k in ("demografia", "religiones", "culturas", "idiomas"):
                    if r.get(k):
                        el[k] = r[k]
                regiones.append(el)

        paquetes[n] = {"paquete": t["nombre"], "descripcion": t["descripcion"], "regiones": regiones,
                       "fuentes": fuentes, "personas": personas, "hechos": hechos, "lugares": lugares_por_tema[n],
                       "_familias": familias}

    # ---- obras: los autores de cada tema y los de otros temas o paquetes
    personas_nuevas = {p["id"]: p for pk in paquetes.values() for p in pk["personas"]}
    tocados = set()
    for autor, obras in obras_por_autor.items():
        if autor in personas_nuevas:
            for o in obras:
                if o not in personas_nuevas[autor]["obras"]:
                    personas_nuevas[autor]["obras"].append(o)
    for nombre_paq, d in existentes.items():
        for p in d.get("personas", []):
            for o in obras_por_autor.get(p["id"], []):
                if o not in p.get("obras", []):
                    p.setdefault("obras", []).append(o)
                    tocados.add(nombre_paq)

    # ---- ids repetidos: dentro de cada tema, entre temas y con los paquetes existentes
    for seccion in ("regiones", "fuentes", "personas", "hechos", "lugares"):
        otros = {x["id"]: n for n, d in existentes.items() for x in d.get(seccion, [])}
        de_temas = {}
        for n, t in temas.items():
            clave_ids = {"fuentes": [b["id"] for b in t["fue"]], "personas": [x[0] for x, _ in t["per"]],
                         "hechos": [x[0] for x, _ in t["hec"]], "lugares": [x[0] for x, _ in t["lug"]],
                         "regiones": [r["id"] for r in t["reg"].REGIONES] if t["reg"] else []}[seccion]
            for i in clave_ids:
                de_temas.setdefault(i, []).append(n)
        for n in construir:
            tema_actual[0] = n
            vistos = set()
            for x in paquetes[n][seccion]:
                if x["id"] in vistos:
                    aviso(f"ID REPETIDO en {seccion}: {x['id']}")
                vistos.add(x["id"])
                if x["id"] in otros:
                    aviso(f"ID QUE YA EXISTE en {otros[x['id']]} ({seccion}): {x['id']} — usá ese id sin redefinirlo")
                if len(set(de_temas.get(x["id"], []))) > 1:
                    aviso(f"ID TAMBIÉN EN OTRO TEMA ({seccion}): {x['id']} en {sorted(set(de_temas[x['id']]))}")

    total = {}
    for n in construir:
        pk = paquetes[n]
        tema_actual[0] = n
        familias = pk.pop("_familias")
        cuenta = {k: len(pk[k]) for k in ("regiones", "fuentes", "personas", "hechos", "lugares")}
        cuenta["enlaces"] = sum(len(f["leer"]) for f in pk["fuentes"])
        cuenta["avisos"] = len(informes.get(n, []))
        total[n] = cuenta
        dirt = temas[n]["dir"]
        (dirt / "salida.json").write_text(json.dumps(pk, ensure_ascii=False, indent=2), encoding="utf-8")
        (dirt / "familias-nuevas.json").write_text(json.dumps(familias, ensure_ascii=False, indent=2), encoding="utf-8")
        (dirt / "informe.txt").write_text("\n".join(informes.get(n, [])) + "\n", encoding="utf-8")
        print(n, cuenta)
        pk["_familias"] = familias

    if ESCRIBIR and not SOLO:
        fam = existentes["familias.json"]
        ya = {(f["capa"], f["id"]) for f in fam["familias"]}
        for n, pk in paquetes.items():
            familias = pk.pop("_familias")
            fam["familias"] += [f for f in familias if (f["capa"], f["id"]) not in ya]
            (PAQ / f"{pk['paquete']}.json").write_text(json.dumps(pk, ensure_ascii=False, indent=2), encoding="utf-8")
        (PAQ / "familias.json").write_text(json.dumps(fam, ensure_ascii=False, indent=2), encoding="utf-8")
        for nombre_paq in tocados:
            (PAQ / nombre_paq).write_text(json.dumps(existentes[nombre_paq], ensure_ascii=False, indent=2), encoding="utf-8")
        print("escrito en", PAQ, "; se tocan", sorted(tocados))


try:
    main()
except (ValueError, IndexError, KeyError) as e:
    sys.exit(f"ERROR en {CTX[0]}: {e!r}")
