#!/usr/bin/env python3
"""Catálogo de la interfaz de TellMAP en inglés: traducciones/en.po.

Los textos de la interfaz se escriben en español en el código, dentro de tr(), tr_n(), Idioma.t() o Idioma.tn(), y el
español es la clave: en inglés, Godot busca ese texto en traducciones/en.po. Algunos textos viven en constantes (los
modos del mapa, los temas, las pestañas) o en los datos (los indicadores de Our World in Data) y se traducen al
mostrarlos; están en CONSTANTES y DATOS, más abajo.

Uso:  python3 tools/traduccion/interfaz.py revisar
          Sale con 1 si a un texto del código le falta la traducción, si en.po tiene textos que ya no se usan, si los
          marcadores (%s, %d, [b]…) no coinciden o si hay textos de la interfaz escritos fuera de tr().
      python3 tools/traduccion/interfaz.py actualizar [--con traducciones.json]
          Rehace en.po en el orden del código: suma los textos nuevos (sin traducir), saca los que ya no se usan y
          conserva el resto. Con --con suma las traducciones de un JSON {"texto en español": "English text"}; para
          los plurales, {"singular": ["singular", "plural"]}.
      python3 tools/traduccion/interfaz.py faltan
          Lista los textos sin traducir en JSON, con el formato que acepta --con.

`revisar` controla también la página del proyecto (docs/index.html): cada elemento marcado con data-t o data-t-alt
tiene que tener su texto en inglés en el diccionario EN de la página, y no puede sobrar ninguno.

Sin dependencias: Python 3.10 o más nuevo.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PO = RAIZ / "traducciones" / "en.po"
PAGINA = RAIZ / "docs" / "index.html"
CARPETAS = ["scripts"]
# Pruebas y herramientas de desarrollo: lo que escriben va al registro, no a la persona.
EXCLUIDOS = {"scripts/nucleo/recorrido.gd", "scripts/nucleo/prueba_editor.gd"}
# Constantes con textos que se traducen al mostrarlos: archivo → {constante: qué textos son de la interfaz}. None: todos
# los que no son claves de un diccionario; una lista de nombres: los valores de esas claves; una lista de números: las
# posiciones dentro de cada lista interna (["mostrar_nombres", "Nombres de entidades", "acento"] → [1]).
CONSTANTES: dict[str, dict[str, list[str] | list[int] | None]] = {
    "scripts/nucleo/estado.gd": {"MODOS": None},
    "scripts/nucleo/motor.gd": {"OPCIONES": None},
    "scripts/nucleo/enciclopedia.gd": {"NOMBRE_CAPA": None, "NOMBRE_PESO": None},
    "scripts/nucleo/pleiades.gd": {"NOMBRES_CATEGORIA": None},
    "scripts/interfaz/ajustes.gd": {"DESCRIPCION_CALIDAD": None, "NOMBRES_CALIDAD": None, "CREDITOS": None},
    "scripts/interfaz/bienvenida.gd": {"TEXTO": None, "ATAJOS": [0, 1]},
    "scripts/interfaz/panel_info.gd": {"PESTANAS": None, "NOMBRES_TIPO": None, "NOMBRES_GENERO": None,
                                       "NOMBRES_TIPO_HECHO": None, "NOMBRES_TIPO_LUGAR": None, "NOMBRES_CONFIANZA": None},
    "scripts/interfaz/tema.gd": {"TEMAS": ["nombre"]},
    "scripts/interfaz/leyenda.gd": {"CAPAS": [1]},
    "scripts/interfaz/editor_enciclopedia.gd": {"SECCIONES": [1], "TITULO_NUEVO": None, "IMPORTANCIAS": [1], "CAMPOS": [1],
                                                "SUB_CAPA": [1], "SUB_DEMOGRAFIA": [1], "OPCIONES_CAPA": ["ayuda"],
                                                "OPCIONES_DEMOGRAFIA": ["ayuda"]},
    "scripts/interfaz/pista_tiempo.gd": {"ERAS_GLOBALES": [2]},
}
# Textos de los datos que se muestran con tr(): archivo → (lista dentro del JSON, campos).
DATOS = {"data/demografia/paises.json": ("indicadores", ["nombre", "unidad", "descripcion"])}
# Palabras que no se traducen: un texto hecho solo de ellas (nombres propios, siglas) no necesita tr().
SIN_TRADUCIR = {"TellMAP", "TELLMAP", "Bautista", "Fiori", "Wikipedia", "Wikidata", "Pleiades", "Cliopatria", "GitHub", "Godot",
                "Español", "English", "OK", "OpenGL", "Vulkan", "Metal", "ANGLE", "Direct3D"}
LLAMADAS = {"tr": 1, "atr": 1, "tr_n": 2, "Idioma.t": 1, "Idioma.tn": 2}
# Asignaciones y llamadas que ponen texto en la interfaz: si llevan un texto literal, tiene que ir dentro de tr().
PROPIEDADES = {"text", "tooltip_text", "placeholder_text"}
METODOS_TEXTO = {"add_item", "set_item_text", "add_tab", "set_tab_title", "add_check_item", "add_radio_check_item"}


@dataclass
class Texto:
    msgid: str
    plural: str | None = None
    contexto: str | None = None
    lugares: list[str] = field(default_factory=list)
    msgstr: list[str] = field(default_factory=list)

    @property
    def clave(self) -> tuple[str | None, str]:
        return (self.contexto, self.msgid)


# ---------------------------------------------------------------------------------------------------------------
# GDScript


ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\", "0": "\0", "a": "\a", "b": "\b",
           "f": "\f", "v": "\v"}


def _desescapar(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n == "u" and i + 5 < len(s):
                out.append(chr(int(s[i + 2:i + 6], 16)))
                i += 6
                continue
            if n == "\n":
                i += 2
                continue
            out.append(ESCAPES.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


TOKEN = re.compile("|".join([
    r"(?P<comentario>#[^\n]*)",
    r"(?P<cadena>(?P<prefijo>[&^r]?)(?P<comilla>" + '"""' + "|" + "'''" + r"""|"|')"""
    + r"(?P<cuerpo>(?:\\.|(?!(?P=comilla)).)*?)(?P=comilla))",
    r"(?P<nombre>[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*)",
    r"(?P<num>\d[\d_]*(?:\.\d+)?)",
    r"(?P<espacio>[ \t]+|\\\n)",
    r"(?P<linea>\n)",
    r"(?P<signo>.)",
]), re.DOTALL)


@dataclass
class Tok:
    tipo: str
    valor: str
    linea: int


def tokens(codigo: str) -> list[Tok]:
    out: list[Tok] = []
    linea = 1
    for m in TOKEN.finditer(codigo):
        tipo = m.lastgroup
        texto = m.group(0)
        if tipo == "cadena":
            cuerpo = m.group("cuerpo")
            valor = cuerpo if m.group("prefijo") == "r" else _desescapar(cuerpo)
            out.append(Tok("cadena", valor, linea))
        elif tipo in ("nombre", "num", "signo"):
            out.append(Tok(tipo, texto, linea))
        elif tipo == "linea":
            out.append(Tok("linea", texto, linea))
        linea += texto.count("\n")
    return out


def _sin_lineas(toks: list[Tok]) -> list[Tok]:
    """Dentro de paréntesis, corchetes y llaves los saltos de línea no cuentan."""
    out: list[Tok] = []
    profundidad = 0
    for t in toks:
        if t.tipo == "signo" and t.valor in "([{":
            profundidad += 1
        elif t.tipo == "signo" and t.valor in ")]}":
            profundidad = max(profundidad - 1, 0)
        if t.tipo == "linea" and profundidad > 0:
            continue
        out.append(t)
    return out


def _cadena_sola(toks: list[Tok], i: int) -> tuple[str | None, int]:
    """Si en toks[i] empieza un argumento que es solo un texto literal, lo devuelve con el índice que sigue."""
    if i < len(toks) and toks[i].tipo == "cadena" and i + 1 < len(toks) and toks[i + 1].valor in (",", ")"):
        return toks[i].valor, i + 1
    return None, i


def _es_texto(s: str) -> bool:
    sin_marcas = re.sub(r"%[-+ 0#]*\d*(?:\.\d+)?[a-zA-Z]|\[[^\]]*\]", " ", s)
    palabras = re.findall(r"[^\W\d_]{2,}", sin_marcas)
    return any(p not in SIN_TRADUCIR for p in palabras)


def leer_codigo(errores: list[str]) -> list[Texto]:
    textos: dict[tuple[str | None, str], Texto] = {}

    def anotar(msgid: str, plural: str | None, contexto: str | None, lugar: str) -> None:
        clave = (contexto, msgid)
        t = textos.get(clave)
        if t is None:
            textos[clave] = Texto(msgid, plural, contexto, [lugar])
            return
        if t.plural != plural:
            errores.append(f"{lugar}: «{msgid}» se usa con y sin plural; usá un texto distinto o un contexto")
        if lugar not in t.lugares:
            t.lugares.append(lugar)

    archivos = sorted(p for c in CARPETAS for p in (RAIZ / c).rglob("*.gd"))
    for ruta in archivos:
        rel = ruta.relative_to(RAIZ).as_posix()
        if rel in EXCLUIDOS:
            continue
        toks = _sin_lineas(tokens(ruta.read_text(encoding="utf-8")))
        constantes = CONSTANTES.get(rel, {})
        for i, t in enumerate(toks):
            # tr("…"), tr_n("…", "…", n), Idioma.t("…"): el español es la clave
            if t.tipo == "nombre" and t.valor in LLAMADAS and i + 1 < len(toks) and toks[i + 1].valor == "(":
                if i > 0 and toks[i - 1].valor == "func":
                    continue
                lugar = f"{rel}:{t.linea}"
                msgid, j = _cadena_sola(toks, i + 2)
                if msgid is None:
                    if i + 2 < len(toks) and toks[i + 2].tipo == "cadena":
                        errores.append(f"{lugar}: {t.valor}() con un texto armado; tiene que ser un solo texto literal")
                    continue
                plural = None
                if LLAMADAS[t.valor] == 2:
                    plural, j = _cadena_sola(toks, j + 1)
                    if plural is None:
                        errores.append(f"{lugar}: {t.valor}() sin el plural como texto literal")
                        continue
                contexto = None
                if LLAMADAS[t.valor] == 1 and toks[j].valor == ",":
                    contexto, _ = _cadena_sola(toks, j + 1)
                anotar(msgid, plural, contexto, lugar)
            # Constantes que se traducen al mostrarlas
            if t.tipo == "nombre" and t.valor == "const" and i + 1 < len(toks) and toks[i + 1].valor in constantes:
                claves = constantes[toks[i + 1].valor]
                j = i + 2
                posiciones = [0]
                ultima_clave = None
                while j < len(toks):
                    u = toks[j]
                    if u.valor in "([{" and u.tipo == "signo":
                        posiciones.append(0)
                    elif u.valor in ")]}" and u.tipo == "signo":
                        posiciones.pop()
                    elif u.valor == "," and u.tipo == "signo":
                        posiciones[-1] += 1
                    elif u.tipo == "cadena":
                        es_clave = j + 1 < len(toks) and toks[j + 1].valor == ":"
                        if es_clave:
                            ultima_clave = u.valor
                        elif re.search(r"[^\W\d_]", u.valor) and (claves is None or ultima_clave in claves
                                                     or posiciones[-1] in claves):
                            anotar(u.valor, None, None, f"{rel}:{u.linea}")
                    profundidad = len(posiciones) - 1
                    if u.tipo == "linea" and profundidad <= 0:
                        break
                    j += 1
            # Textos de la interfaz escritos a mano, fuera de tr()
            if t.tipo == "cadena" and _es_texto(t.valor) and i >= 2:
                previo, antes = toks[i - 1], toks[i - 2]
                propiedad = previo.valor == "=" and antes.tipo == "nombre" and antes.valor.split(".")[-1] in PROPIEDADES
                metodo = previo.valor == "(" and antes.tipo == "nombre" and antes.valor.split(".")[-1] in METODOS_TEXTO
                if propiedad or metodo:
                    errores.append(f"{rel}:{t.linea}: texto de la interfaz fuera de tr(): «{t.valor[:60]}»")
    for rel, (lista, campos) in DATOS.items():
        datos = json.loads((RAIZ / rel).read_text(encoding="utf-8"))
        for item in datos.get(lista, []):
            for c in campos:
                if isinstance(item.get(c), str) and _es_texto(item[c]):
                    anotar(item[c], None, None, rel)
    return list(textos.values())


# ---------------------------------------------------------------------------------------------------------------
# .po


def _po_escapar(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def _po_cadena(lineas: list[str], i: int) -> tuple[str, int]:
    """Junta un texto de .po que puede seguir en las líneas siguientes ("…")."""
    partes = []
    while i < len(lineas) and lineas[i].strip().startswith('"'):
        partes.append(_desescapar(lineas[i].strip()[1:-1]))
        i += 1
    return "".join(partes), i


CABECERA = (
    'msgid ""\nmsgstr ""\n'
    '"Project-Id-Version: TellMAP\\n"\n'
    '"Language: en\\n"\n'
    '"MIME-Version: 1.0\\n"\n'
    '"Content-Type: text/plain; charset=UTF-8\\n"\n'
    '"Content-Transfer-Encoding: 8bit\\n"\n'
    '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n'
)


def leer_po(ruta: Path = PO) -> dict[tuple[str | None, str], Texto]:
    if not ruta.exists():
        return {}
    lineas = ruta.read_text(encoding="utf-8").splitlines()
    out: dict[tuple[str | None, str], Texto] = {}
    actual: Texto | None = None
    contexto = None
    i = 0
    while i < len(lineas):
        l = lineas[i].strip()
        m = re.match(r'(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d)\])?) (".*)', l)
        if not m:
            i += 1
            continue
        valor, j = _po_cadena([m.group(3)] + lineas[i + 1:], 0)
        i += j
        etiqueta = m.group(1)
        if etiqueta == "msgctxt":
            contexto = valor
        elif etiqueta == "msgid":
            actual = Texto(valor, contexto=contexto)
            contexto = None
            if valor:
                out[actual.clave] = actual
        elif etiqueta == "msgid_plural" and actual:
            actual.plural = valor
        elif actual:
            n = int(m.group(2) or 0)
            while len(actual.msgstr) <= n:
                actual.msgstr.append("")
            actual.msgstr[n] = valor
    return out


def escribir_po(textos: list[Texto], ruta: Path = PO) -> None:
    partes = [CABECERA]
    for t in textos:
        bloque = [f"#: {' '.join(dict.fromkeys(l.split(':')[0] for l in t.lugares))}"]
        if t.contexto:
            bloque.append(f'msgctxt "{_po_escapar(t.contexto)}"')
        bloque.append(f'msgid "{_po_escapar(t.msgid)}"')
        if t.plural is not None:
            bloque.append(f'msgid_plural "{_po_escapar(t.plural)}"')
            s = (t.msgstr + ["", ""])[:2]
            bloque += [f'msgstr[0] "{_po_escapar(s[0])}"', f'msgstr[1] "{_po_escapar(s[1])}"']
        else:
            bloque.append(f'msgstr "{_po_escapar((t.msgstr or [""])[0])}"')
        partes.append("\n".join(bloque) + "\n")
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text("\n".join(partes), encoding="utf-8")


# ---------------------------------------------------------------------------------------------------------------


MARCADOR = re.compile(r"%(?:\d+\$)?[-+ 0#]*(?:\d+|\*)?(?:\.\d+)?[sdifxXoc%]|\[/?[a-z_]+(?:=[^\]]*)?\]|\{\w+\}")


def _marcadores(s: str) -> list[str]:
    return sorted(re.sub(r"\[(url|color)=[^\]]*\]", r"[\1=]", m) for m in MARCADOR.findall(s))


def revisar_pagina(errores: list[str]) -> None:
    html = PAGINA.read_text(encoding="utf-8")
    claves = set(re.findall(r'data-t(?:-alt)?="([^"]+)"', html))
    m = re.search(r"var EN = \{(.*?)\n  \};", html, re.DOTALL)
    if not m:
        errores.append("docs/index.html: no encuentro el diccionario EN")
        return
    en = set(re.findall(r"(?:^|,)\s*(\w+):\s*\"", m.group(1), re.MULTILINE))
    for c in sorted(claves - en):
        errores.append(f"docs/index.html: falta el inglés de «{c}»")
    for c in sorted(en - claves - {"titulo_pagina", "descripcion"}):
        errores.append(f"docs/index.html: «{c}» está en EN pero ningún elemento lo usa")


def revisar() -> int:
    errores: list[str] = []
    revisar_pagina(errores)
    textos = leer_codigo(errores)
    po = leer_po()
    usados = set()
    for t in textos:
        usados.add(t.clave)
        e = po.get(t.clave)
        donde = t.lugares[0]
        if e is None or not any(e.msgstr) or any(not s for s in e.msgstr):
            errores.append(f"{donde}: falta la traducción de «{t.msgid[:70]}»")
            continue
        if (e.plural is None) != (t.plural is None):
            errores.append(f"{donde}: «{t.msgid[:50]}» en en.po {'no ' if e.plural is None else ''}tiene plural")
            continue
        originales = [t.msgid] + ([t.plural] if t.plural else [])
        for k, s in enumerate(e.msgstr):
            original = originales[min(k, len(originales) - 1)]
            if _marcadores(original) != _marcadores(s):
                errores.append(f"{donde}: los marcadores de «{original[:50]}» no coinciden con «{s[:50]}»")
    for clave, e in po.items():
        if clave not in usados:
            errores.append(f"traducciones/en.po: «{e.msgid[:70]}» ya no se usa (corré interfaz.py actualizar)")
    proyecto = (RAIZ / "project.godot").read_text(encoding="utf-8")
    if 'res://traducciones/en.po' not in proyecto:
        errores.append("project.godot no registra traducciones/en.po en internationalization/locale/translations")
    if 'locale/fallback="es"' not in proyecto:
        errores.append('project.godot: internationalization/locale/fallback tiene que ser "es" (el español es la clave)')
    for e in errores:
        print(e)
    print(f"{len(textos)} textos de la interfaz, {len(po)} en traducciones/en.po: "
          + ("todo traducido." if not errores else f"{len(errores)} problema(s)."))
    return 1 if errores else 0


def actualizar(con: Path | None) -> int:
    errores: list[str] = []
    textos = leer_codigo(errores)
    po = leer_po()
    nuevas = json.loads(con.read_text(encoding="utf-8")) if con else {}
    for t in textos:
        previo = po.get(t.clave)
        if previo and previo.plural == t.plural:
            t.msgstr = previo.msgstr
        valor = nuevas.get(t.msgid)
        if valor is not None:
            t.msgstr = valor if isinstance(valor, list) else [valor]
    sobran = [e.msgid for c, e in po.items() if c not in {t.clave for t in textos}]
    escribir_po(textos, PO)
    faltan = [t for t in textos if not any(t.msgstr)]
    print(f"traducciones/en.po: {len(textos)} textos, {len(faltan)} sin traducir, {len(sobran)} quitados.")
    for s in sobran:
        print(f"  quitado: «{s[:70]}»")
    for e in errores:
        print(e)
    return 0


def faltan() -> int:
    errores: list[str] = []
    out = {}
    po = leer_po()
    for t in leer_codigo(errores):
        e = po.get(t.clave)
        if e is None or not all(e.msgstr) or not e.msgstr:
            out[t.msgid] = [t.msgid, t.plural] if t.plural else t.msgid
    print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if args[0] == "revisar":
        return revisar()
    if args[0] == "actualizar":
        con = Path(args[args.index("--con") + 1]) if "--con" in args else None
        return actualizar(con)
    if args[0] == "faltan":
        return faltan()
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
