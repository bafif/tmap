#!/usr/bin/env python3
"""La documentación en los dos idiomas: que cada documento tenga su par y que sus enlaces lleguen a algo que existe.

Pares:
- `docs/es/<nombre>.md` y `docs/en/<name>.md`: el nombre cambia con el idioma, así que el par es el que cada uno
  enlaza en sus primeras líneas (`[English](../en/<name>.md)` y `[Español](../es/<nombre>.md)`), y los dos tienen que
  apuntarse entre sí.
- En el resto del repo, `X.md` (español) y `X.en.md` (inglés), y cada uno enlaza al otro.
Quedan afuera `CLAUDE.md`, `LICENSE*`, `CHANGELOG*` y las plantillas de `.github/`, que tienen los dos idiomas adentro.

En todos los `.md` versionados controla además:
- que cada enlace relativo (de Markdown o un `src`/`href` de HTML) apunte a un archivo que existe y, si lleva ancla
  hacia un `.md`, a un título que existe;
- que un documento en inglés no enlace a uno en español que tiene su versión en inglés, ni al revés (salvo el enlace
  a su propio par).

Uso: python3 tools/traduccion/documentos.py      sale con 1 si encuentra algún problema
Solo usa la biblioteca estándar.
"""

from __future__ import annotations

import posixpath
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
LINEAS_DEL_PAR = 8  # el enlace al otro idioma va arriba de todo, debajo del título

ENLACE_MD = re.compile(r"\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
ENLACE_HTML = re.compile(r"\b(?:src|href)=\"([^\"]+)\"")
ESQUEMA_URL = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:|^//")
CERCO = re.compile(r"^\s*(```|~~~)")
TITULO = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def versionados() -> list[str]:
    r = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "*.md"],
                       cwd=RAIZ, capture_output=True, text=True, check=True)
    return sorted(p for p in r.stdout.split("\0") if p and (RAIZ / p).is_file())


def excluido(ruta: str) -> bool:
    nombre = posixpath.basename(ruta)
    return ruta.startswith(".github/") or nombre == "CLAUDE.md" or nombre.startswith(("LICENSE", "CHANGELOG"))


def idioma(ruta: str) -> str:
    if ruta.startswith("docs/en/") or ruta.endswith(".en.md"):
        return "en"
    return "es"


def sin_codigo(texto: str) -> list[str]:
    """Las líneas del documento sin los bloques de código ni el código en línea, donde un enlace no es un enlace."""
    lineas, dentro = [], False
    for linea in texto.splitlines():
        if CERCO.match(linea):
            dentro = not dentro
            lineas.append("")
            continue
        lineas.append("" if dentro else re.sub(r"`[^`]*`", "", linea))
    return lineas


def slug(titulo: str) -> str:
    """El ancla que GitHub le da a un título."""
    t = re.sub(r"<[^>]+>", "", titulo)
    t = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"[^\w\- ]", "", t.lower())
    return t.replace(" ", "-")


def anclas(texto: str) -> set[str]:
    vistas: dict[str, int] = {}
    out = set()
    dentro = False
    for linea in texto.splitlines():
        if CERCO.match(linea):
            dentro = not dentro
            continue
        m = None if dentro else TITULO.match(linea)
        if m:
            s = slug(m.group(2))
            n = vistas.get(s, 0)
            vistas[s] = n + 1
            out.add(s if n == 0 else f"{s}-{n}")
    out.update(re.findall(r"\b(?:id|name)=\"([^\"]+)\"", texto))
    return out


def enlaces(ruta: str, lineas: list[str]) -> list[tuple[int, str]]:
    out = []
    for i, linea in enumerate(lineas, 1):
        for patron in (ENLACE_MD, ENLACE_HTML):
            out += [(i, m.group(1)) for m in patron.finditer(linea)]
    return out


def resolver(ruta: str, objetivo: str) -> tuple[str, str]:
    """(ruta desde la raíz, ancla) de un enlace relativo de `ruta`."""
    camino, _, ancla = objetivo.partition("#")
    if not camino:
        return ruta, ancla
    base = "" if camino.startswith("/") else posixpath.dirname(ruta)
    return posixpath.normpath(posixpath.join(base, camino.lstrip("/"))), ancla


def main() -> int:
    docs = versionados()
    textos = {d: (RAIZ / d).read_text(encoding="utf-8") for d in docs}
    lineas = {d: sin_codigo(t) for d, t in textos.items()}
    enl = {d: enlaces(d, lineas[d]) for d in docs}
    problemas: list[str] = []

    # pares
    par: dict[str, str] = {}
    for d in docs:
        if excluido(d):
            continue
        carpeta = re.match(r"docs/(es|en)/", d)
        if carpeta:
            otro = "en" if carpeta.group(1) == "es" else "es"
            arriba = [resolver(d, o)[0] for i, o in enl[d] if i <= LINEAS_DEL_PAR and not ESQUEMA_URL.match(o)]
            candidatos = [r for r in arriba if r.startswith(f"docs/{otro}/") and r.endswith(".md")]
            if not candidatos:
                etiqueta = "English" if otro == "en" else "Español"
                problemas.append(f"{d}: falta arriba de todo el enlace a su versión en docs/{otro}/ "
                                 f"([{etiqueta}](../{otro}/...))")
                continue
            par[d] = candidatos[0]
        elif d.endswith(".en.md"):
            par[d] = d[: -len(".en.md")] + ".md"
        elif d.endswith(".es.md"):
            par[d] = d[: -len(".es.md")] + ".md"
        else:
            hermanos = [d[:-3] + ".en.md", d[:-3] + ".es.md"]
            par[d] = next((h for h in hermanos if h in textos), hermanos[0])

    for d, p in sorted(par.items()):
        if p not in textos:
            problemas.append(f"{d}: le falta su versión en {'inglés' if idioma(d) == 'es' else 'español'}, {p}")
            continue
        if d.startswith("docs/") and par.get(p) not in (None, d):
            problemas.append(f"{d}: enlaza a {p} como su par, pero {p} enlaza a {par[p]}")
        if not any(resolver(d, o)[0] == p for _, o in enl[d] if not ESQUEMA_URL.match(o)):
            problemas.append(f"{d}: no tiene un enlace a su versión en el otro idioma, {p}")

    # enlaces
    anclas_de: dict[str, set[str]] = {}
    for d in docs:
        for i, o in enl[d]:
            if ESQUEMA_URL.match(o) or o.startswith("{{"):
                continue
            destino, ancla = resolver(d, o)
            if not (RAIZ / destino).exists():
                donde = "" if o.lstrip("/") == destino else f" ({destino})"
                problemas.append(f"{d}:{i}: el enlace {o}{donde} apunta a un archivo que no existe")
                continue
            if ancla and destino.endswith(".md"):
                if destino not in anclas_de:
                    texto = textos.get(destino) or (RAIZ / destino).read_text(encoding="utf-8")
                    anclas_de[destino] = anclas(texto)
                if ancla not in anclas_de[destino]:
                    problemas.append(f"{d}:{i}: el enlace {o} apunta a #{ancla}, que no es un título de {destino}")
            if (destino in par and destino != par.get(d) and idioma(destino) != idioma(d)
                    and idioma(par[destino]) == idioma(d) and par[destino] in textos):
                problemas.append(f"{d}:{i}: el enlace {o} lleva a la versión en el otro idioma; "
                                 f"en este documento va {par[destino]}")

    for p in problemas:
        print(p)
    if problemas:
        print(f"\n{len(problemas)} problema(s) en la documentación.")
        return 1
    n_pares = sum(1 for d in par if idioma(d) == "es")
    print(f"{len(docs)} documentos, {n_pares} pares en español e inglés: todos con su par y sus enlaces en orden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
