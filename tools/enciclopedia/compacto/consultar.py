"""Consultas rápidas para verificar datos mientras se escribe un tema.

Uso: python3 -I consultar.py <orden> <argumentos>
  resumen <Título en inglés> [es]   introducción del artículo (en.wikipedia; con «es», es.wikipedia), con su QID
  buscar <texto> [es]               los 8 primeros resultados de búsqueda en en.wikipedia (o es)
  titulos <T1> ;; <T2> ;; ...       comprueba títulos de en.wikipedia: redirección, desambiguación, QID y título es
  wd <QID>                          nacimiento, muerte, lugares y coordenadas de Wikidata
  url <https://...>                 código HTTP de una dirección
  ws <lengua> <texto>               búsqueda en <lengua>.wikisource.org
  pg <texto>                        búsqueda en el Proyecto Gutenberg (número de libro y título)
"""
import json
import re
import sys
import urllib.parse
import urllib.request

UA = "TellMAP/0.4 (https://bafif.github.io/tmap; datos de la enciclopedia)"


def pedir(url, params=None, crudo=False):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=40) as r:
        b = r.read()
    return b.decode("utf-8", "replace") if crudo else json.loads(b)


def api(lengua, **p):
    p.update({"format": "json", "formatversion": 2})
    return pedir(f"https://{lengua}.wikipedia.org/w/api.php", p)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    orden, args = sys.argv[1], sys.argv[2:]
    if orden == "resumen":
        lengua = "es" if args[-1] == "es" and len(args) > 1 else "en"
        titulo = " ".join(args[:-1] if lengua == "es" else args)
        d = api(lengua, action="query", prop="extracts|pageprops", exintro=1, explaintext=1, redirects=1,
                titles=titulo, ppprop="wikibase_item")
        for p in d["query"]["pages"]:
            print(f"== {p.get('title')} ({p.get('pageprops', {}).get('wikibase_item', 'sin QID')})"
                  f"{' FALTA' if p.get('missing') else ''}")
            print(p.get("extract", "")[:3000])
    elif orden == "buscar":
        lengua = "es" if args[-1] == "es" and len(args) > 1 else "en"
        texto = " ".join(args[:-1] if lengua == "es" else args)
        d = api(lengua, action="query", list="search", srsearch=texto, srlimit=8)
        for r in d["query"]["search"]:
            print(f"{r['title']} — {re.sub('<[^>]+>', '', r['snippet'])[:140]}")
    elif orden == "titulos":
        ts = [t.strip() for t in " ".join(args).split(";;") if t.strip()]
        for k in range(0, len(ts), 40):
            d = api("en", action="query", titles="|".join(ts[k:k + 40]), redirects=1, prop="pageprops",
                    ppprop="wikibase_item|disambiguation")
            q = d["query"]
            alias = {r["from"]: r["to"] for r in q.get("normalized", []) + q.get("redirects", [])}
            pags = {p["title"]: p for p in q["pages"]}
            qids = []
            for t in ts[k:k + 40]:
                f = t
                for _ in range(3):
                    f = alias.get(f, f)
                p = pags.get(f, {})
                qids.append(p.get("pageprops", {}).get("wikibase_item"))
            es = {}
            qq = [x for x in qids if x]
            for j in range(0, len(qq), 50):
                e = pedir("https://www.wikidata.org/w/api.php", {"action": "wbgetentities", "ids": "|".join(qq[j:j + 50]),
                                                                  "props": "sitelinks", "sitefilter": "eswiki", "format": "json"})
                for qid, ent in e.get("entities", {}).items():
                    es[qid] = ent.get("sitelinks", {}).get("eswiki", {}).get("title")
            for t, qid in zip(ts[k:k + 40], qids):
                f = t
                for _ in range(3):
                    f = alias.get(f, f)
                p = pags.get(f, {})
                estado = "FALTA" if (p.get("missing") or not p) else ("DESAMBIGUACIÓN" if "disambiguation" in p.get("pageprops", {}) else "ok")
                print(f"{estado:15} {t} → {f} | {qid} | es: {es.get(qid)}")
    elif orden == "wd":
        e = pedir("https://www.wikidata.org/w/api.php", {"action": "wbgetentities", "ids": args[0], "format": "json",
                                                          "props": "claims|labels|sitelinks", "languages": "es|en"})
        ent = e["entities"][args[0]]
        print(ent.get("labels", {}).get("es", ent.get("labels", {}).get("en", {})).get("value"))
        for prop, nombre in (("P569", "nacimiento"), ("P570", "muerte"), ("P19", "lugar de nacimiento"),
                             ("P20", "lugar de muerte"), ("P571", "fundación"), ("P577", "publicación"), ("P625", "coordenadas")):
            for c in ent.get("claims", {}).get(prop, []):
                v = c["mainsnak"].get("datavalue", {}).get("value")
                if isinstance(v, dict) and "time" in v:
                    v = v["time"]
                elif isinstance(v, dict) and "id" in v:
                    v = v["id"]
                elif isinstance(v, dict) and "latitude" in v:
                    v = f"{v['longitude']:.3f},{v['latitude']:.3f}"
                print(f"{nombre}: {v}")
    elif orden == "url":
        try:
            req = urllib.request.Request(args[0], headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=40) as r:
                print(r.status, r.geturl())
        except Exception as ex:  # noqa: BLE001
            print(getattr(ex, "code", ex))
    elif orden == "ws":
        lengua, texto = args[0], " ".join(args[1:])
        d = pedir(f"https://{lengua}.wikisource.org/w/api.php", {"action": "query", "list": "search", "srsearch": texto,
                                                                  "srlimit": 10, "format": "json", "srnamespace": 0})
        for r in d["query"]["search"]:
            print(r["title"])
    elif orden == "pg":
        d = pedir("https://gutendex.com/books/", {"search": " ".join(args)})
        for b in d.get("results", [])[:10]:
            print(b["id"], "|", b["title"][:90], "|", ", ".join(a["name"] for a in b.get("authors", [])), "|",
                  ",".join(b.get("languages", [])), "| dp" if not b.get("copyright") else "| con derechos")
    else:
        print(__doc__)


main()
