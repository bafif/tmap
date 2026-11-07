"""Redacta con IA la ficha extendida de un borrador, citando sus fuentes, para revisión humana.

Uso:
  python3 tools/enciclopedia/redactar.py data/enciclopedia/paquetes/borradores/imperio-otomano.json
  python3 tools/enciclopedia/redactar.py --todos            # los borradores que todavía no tienen ficha extendida
  python3 tools/enciclopedia/redactar.py BORRADOR --modelo claude-sonnet-5-5 --esfuerzo medium
  python3 tools/enciclopedia/redactar.py BORRADOR --respuesta respuesta.json   # sin API: verifica una respuesta guardada

Toma un borrador de borradores.py, numera sus fuentes (cada sección del artículo de Wikipedia y la ficha de Wikidata)
y le pide a Claude una ficha extendida en español, por secciones, en la que cada párrafo cite las fuentes de las que
sale. Después, sin confiar en el modelo:

- descarta los párrafos sin citas o con citas a fuentes que no existen;
- marca para revisar los párrafos con años o cifras que no aparecen en las fuentes que citan;
- comprueba cada enlace de las fuentes de lectura que propone (tiene que responder 200) y descarta los que no.

El resultado queda en el mismo borrador: la ficha en `extendida` de la región y, en `borrador.ia`, el modelo, la
fecha, los avisos para la revisión, lo descartado y las fuentes propuestas. Sigue «sin revisar»: solo pasa a la
enciclopedia cuando una persona lo aprueba en el editor (Ajustes → Abrir el editor → Borradores).

Necesita el SDK oficial (`pip install anthropic`) y una credencial de la API (ANTHROPIC_API_KEY o `ant auth login`).
Cada ficha cuesta del orden de 0,15 a 0,40 USD con el modelo por defecto. Corre a mano, de a un borrador o en lotes
chicos: nunca desatendido.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DIR_BORRADORES = RAIZ / "data" / "enciclopedia" / "paquetes" / "borradores"
MODELO = "claude-opus-5-5"
UA = "TellMAP-redactar/0.3 (https://github.com/bafif/tmap; tools/enciclopedia/redactar.py)"

SISTEMA = """Sos redactor de TellMAP, un atlas histórico con una enciclopedia en la que cada dato dice de dónde sale.
Vas a escribir la ficha extendida de una entidad histórica (un estado, un imperio, una región) a partir de fuentes
numeradas que se te dan. Reglas, sin excepción:

- Escribí en español rioplatense neutro, claro y sobrio, de enciclopedia: sin adjetivos de más, sin opiniones.
- Usá solamente lo que dicen las fuentes dadas. Nada de lo que sepas por otro lado: si no está en las fuentes, no va.
- Cada párrafo lleva en "citas" los números de las fuentes de las que sale, y en el texto, después de cada
  afirmación, la marca [n] de su fuente. Un párrafo sin fuente no se escribe.
- Si las fuentes se contradicen o una fecha es incierta, decilo ("hacia", "según", "se discute").
- Años antes de Cristo: "1274 a. C."; no existe el año 0.
- Organizá la historia en 4 a 8 secciones con títulos cortos (orígenes, expansión, organización, economía, cultura y
  religión, decadencia o final, legado), de 1 a 4 párrafos cada una, según lo que den las fuentes.
- En "descartado" anotá, en una línea cada una, las afirmaciones importantes que habrías querido incluir y no pudiste
  respaldar con las fuentes.
- En "fuentes_propuestas" proponé hasta 6 textos para leer: fuentes primarias de la época y estudios modernos que las
  fuentes dadas mencionen (cita obligatoria en "citas"). Poné una URL de lectura solo si es de texto completo y de
  acceso abierto (Wikisource, Proyecto Gutenberg, Perseus, Internet Archive, sitios universitarios); si no conocés
  una, dejala vacía. Las URL se comprueban una por una y las que no respondan se descartan."""

ESQUEMA = {
    "type": "object",
    "properties": {
        "secciones": {"type": "array", "items": {
            "type": "object",
            "properties": {
                "titulo": {"type": "string"},
                "parrafos": {"type": "array", "items": {
                    "type": "object",
                    "properties": {"texto": {"type": "string"}, "citas": {"type": "array", "items": {"type": "integer"}}},
                    "required": ["texto", "citas"], "additionalProperties": False}},
            },
            "required": ["titulo", "parrafos"], "additionalProperties": False}},
        "fuentes_propuestas": {"type": "array", "items": {
            "type": "object",
            "properties": {
                "titulo": {"type": "string"}, "autor": {"type": "string"},
                "tipo": {"type": "string", "enum": ["primaria", "secundaria"]},
                "fecha": {"type": "string"}, "por_que": {"type": "string"},
                "url": {"type": "string"}, "citas": {"type": "array", "items": {"type": "integer"}}},
            "required": ["titulo", "autor", "tipo", "fecha", "por_que", "url", "citas"], "additionalProperties": False}},
        "descartado": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["secciones", "fuentes_propuestas", "descartado"],
    "additionalProperties": False,
}


def fuentes_del(b: dict) -> list[dict]:
    """Las fuentes numeradas del borrador: cada sección del artículo y la ficha de Wikidata."""
    meta = b.get("borrador", {})
    art = meta.get("articulo", {})
    base = meta.get("fuentes", {}).get("wikipedia") or ""
    out = []
    for s in art.get("secciones", []):
        ancla = "" if s["titulo"] == "Introducción" else "#" + urllib.parse.quote(s["titulo"].replace(" ", "_"))
        out.append({"n": len(out) + 1, "titulo": f"Wikipedia ({art.get('lengua')}), «{art.get('titulo')}», {s['titulo']}",
                    "url": base + ancla, "texto": s["texto"]})
    datos = []
    for s in ("personas", "hechos", "lugares"):
        for x in b.get(s, []):
            datos.append(json.dumps({k: v for k, v in x.items() if k not in ("regiones", "fuentes", "obras")},
                                    ensure_ascii=False))
    if meta.get("fuentes", {}).get("wikidata"):
        out.append({"n": len(out) + 1, "titulo": f"Wikidata, {meta['origen'].get('wikidata')}",
                    "url": meta["fuentes"]["wikidata"],
                    "texto": "Datos estructurados (personas, hechos y lugares relacionados):\n" + "\n".join(datos)
                             + "\n" + "\n".join(meta.get("sugerencias", []))})
    return out


def pedido(b: dict, fuentes: list[dict]) -> str:
    region = b["regiones"][0]
    partes = [f"Entidad: {region['nombre']}."]
    if region.get("eras"):
        e = region["eras"][0]
        partes.append(f"Años en el mapa (Cliopatria): {e.get('desde')} a {e.get('hasta')} (negativos = antes de Cristo).")
    partes.append("Fuentes:")
    for f in fuentes:
        partes.append(f"<fuente n=\"{f['n']}\" titulo=\"{f['titulo']}\">\n{f['texto']}\n</fuente>")
    partes.append("Escribí la ficha extendida siguiendo las reglas.")
    return "\n\n".join(partes)


def llamar(modelo: str, esfuerzo: str, texto: str) -> tuple[dict, dict]:
    try:
        import anthropic
    except ImportError:
        sys.exit("Falta el SDK de Anthropic: pip install anthropic (o usá --respuesta para verificar una respuesta guardada).")
    cliente = anthropic.Anthropic()
    try:
        with cliente.beta.messages.stream(
            model=modelo,
            max_tokens=32000,
            system=SISTEMA,
            messages=[{"role": "user", "content": texto}],
            output_config={"effort": esfuerzo, "format": {"type": "json_schema", "schema": ESQUEMA}},
            # Si un filtro de seguridad rechaza el pedido, la API lo reintenta en otro modelo dentro de la misma llamada.
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        ) as flujo:
            msj = flujo.get_final_message()
    except anthropic.AuthenticationError:
        sys.exit("La API rechazó la credencial: revisá ANTHROPIC_API_KEY o `ant auth login`.")
    except anthropic.RateLimitError as e:
        sys.exit(f"Límite de uso de la API; probá de nuevo en {e.response.headers.get('retry-after', 'unos')} segundos.")
    except anthropic.APIStatusError as e:
        sys.exit(f"La API respondió {e.status_code}: {e.message}")
    except anthropic.APIConnectionError:
        sys.exit("No hay conexión con la API.")
    if msj.stop_reason == "refusal":
        sys.exit("El modelo no quiso redactar esta ficha (stop_reason: refusal).")
    if msj.stop_reason == "max_tokens":
        sys.exit("La respuesta se cortó por largo: probá con un borrador con menos secciones.")
    texto_r = next(b.text for b in msj.content if b.type == "text")
    uso = {"modelo": msj.model, "entrada": msj.usage.input_tokens, "salida": msj.usage.output_tokens}
    return json.loads(texto_r), uso


def responde(url: str) -> bool:
    if not url.startswith(("https://", "http://")):
        return False
    for metodo in ("HEAD", "GET"):
        try:
            req = urllib.request.Request(url, method=metodo, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=20) as r:
                if r.status == 200:
                    return True
        except (urllib.error.URLError, TimeoutError, ValueError):
            continue
    return False


def cifras(texto: str) -> set[str]:
    """Años y cifras de un texto (tres dígitos o más, sin separadores de miles)."""
    return {re.sub(r"[.\s]", "", m) for m in re.findall(r"\b\d{1,3}(?:[.\s]\d{3})+\b|\b\d{3,}\b", texto)}


def verificar(r: dict, fuentes: list[dict], comprobar_urls: bool) -> tuple[dict, dict]:
    """Ficha extendida y notas de la IA (avisos, descartado, fuentes propuestas), solo con lo respaldado."""
    por_n = {f["n"]: f for f in fuentes}
    avisos, descartado, citadas, secciones = [], list(r.get("descartado", [])), set(), []
    for s in r.get("secciones", []):
        textos, citas_s = [], []
        for p in s.get("parrafos", []):
            citas = sorted({c for c in p.get("citas", []) if c in por_n})
            marcas = {int(m) for m in re.findall(r"\[(\d+)\]", p.get("texto", ""))}
            if not citas or marcas - set(por_n):
                descartado.append(f"Párrafo sin fuente válida en «{s.get('titulo')}»: {p.get('texto', '')[:120]}…")
                continue
            texto = p["texto"].strip()
            if not marcas:
                texto += " " + "".join(f"[{c}]" for c in citas)
            base = " ".join(por_n[c]["texto"] for c in set(citas) | marcas)
            faltan = sorted(cifras(texto) - cifras(base))
            if faltan:
                avisos.append(f"«{s.get('titulo')}»: {', '.join(faltan)} no aparece en las fuentes que cita el párrafo "
                              f"«{texto[:80]}…»")
            textos.append(texto)
            citas_s += [c for c in citas if c not in citas_s]
            citadas |= set(citas) | marcas
        if textos:
            secciones.append({"titulo": s.get("titulo", ""), "texto": "\n\n".join(textos), "citas": citas_s})
    propuestas = []
    for f in r.get("fuentes_propuestas", []):
        citas = [c for c in f.get("citas", []) if c in por_n]
        if not citas:
            descartado.append(f"Fuente propuesta sin respaldo en las fuentes: {f.get('titulo')}")
            continue
        url = f.get("url", "").strip()
        if url and comprobar_urls and not responde(url):
            avisos.append(f"El enlace de «{f.get('titulo')}» no respondió y se quitó: {url}")
            url = ""
        propuestas.append({**f, "url": url, "citas": citas})
        citadas |= set(citas)
    referencias = [{"n": n, "titulo": por_n[n]["titulo"], "url": por_n[n]["url"]} for n in sorted(citadas)]
    extendida = {"secciones": secciones, "referencias": referencias}
    return extendida, {"avisos": avisos, "descartado": descartado, "fuentes_propuestas": propuestas}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("borradores", nargs="*", type=Path)
    ap.add_argument("--todos", action="store_true", help="todos los borradores sin ficha extendida")
    ap.add_argument("--modelo", default=MODELO)
    ap.add_argument("--esfuerzo", default="high", choices=["low", "medium", "high", "xhigh", "max"])
    ap.add_argument("--respuesta", type=Path, help="usar una respuesta guardada en vez de llamar a la API")
    ap.add_argument("--sin-enlaces", action="store_true", help="no comprobar las URL propuestas")
    a = ap.parse_args()
    rutas = list(a.borradores)
    if a.todos:
        rutas += [p for p in sorted(DIR_BORRADORES.glob("*.json"))
                  if not json.loads(p.read_text(encoding="utf-8")).get("borrador", {}).get("ia")]
    if not rutas:
        ap.print_help()
        return 1
    for ruta in rutas:
        b = json.loads(ruta.read_text(encoding="utf-8"))
        fuentes = fuentes_del(b)
        if not fuentes:
            print(f"{ruta.name}: no tiene artículo ni Wikidata para citar; se saltea.")
            continue
        print(f"{ruta.name}: {len(fuentes)} fuentes, {sum(len(f['texto']) for f in fuentes)} caracteres")
        if a.respuesta:
            respuesta, uso = json.loads(a.respuesta.read_text(encoding="utf-8")), {"modelo": f"{a.modelo} (respuesta guardada)"}
        else:
            respuesta, uso = llamar(a.modelo, a.esfuerzo, pedido(b, fuentes))
        extendida, notas = verificar(respuesta, fuentes, not a.sin_enlaces)
        hoy = date.today().isoformat()
        extendida["ia"] = {"modelo": uso["modelo"], "fecha": hoy}
        b["regiones"][0]["extendida"] = extendida
        b["borrador"]["ia"] = {"modelo": uso["modelo"], "fecha": hoy, "esfuerzo": a.esfuerzo,
                               "tokens": {k: v for k, v in uso.items() if k != "modelo"}, **notas}
        b["borrador"]["estado"] = "sin revisar"
        ruta.write_text(json.dumps(b, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"  {len(extendida['secciones'])} secciones, {len(extendida['referencias'])} referencias, "
              f"{len(notas['avisos'])} avisos, {len(notas['descartado'])} descartados, "
              f"{len(notas['fuentes_propuestas'])} fuentes propuestas. Falta la revisión humana en el editor.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
