#!/usr/bin/env python3
"""Organiza el repo de TellMAP en GitHub con gh: datos del repo, etiquetas, versiones (milestones), un issue por cada
tarea pendiente de PROGRESO.md, el tablero del proyecto, GitHub Pages, la seguridad gratuita y la release 0.1.

Uso:  python3 tools/github/organizar.py              muestra lo que haría, sin tocar nada
      python3 tools/github/organizar.py --aplicar    lo hace

Necesita gh con sesión iniciada en la cuenta dueña del repo y permiso para proyectos:
      gh auth login        (una vez)
      gh auth refresh -s project
Se puede correr de nuevo cuando se sumen tareas a PROGRESO.md: solo crea lo que falta (los issues se reconocen por
el título).
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = "bafif/tmap"
DUENO = "bafif"
PROYECTO = "TellMAP"
PAGINA = "https://bafif.github.io/tmap/"
RAIZ = Path(__file__).resolve().parents[2]
APLICAR = "--aplicar" in sys.argv

DESCRIPCION = "Atlas histórico interactivo: fronteras, pueblos y fuentes ordenadas en el espacio y el tiempo (Godot)."
TEMAS = ["history", "historia", "atlas", "map", "historical-maps", "godot", "godot4", "gdscript", "education",
         "primary-sources", "encyclopedia", "open-data", "digital-humanities"]

ETIQUETAS = {
    "error": ("c0583f", "Algo no anda o se ve mal"),
    "mejora": ("d4ab62", "Algo nuevo o mejor"),
    "datos": ("7b9cc2", "Fuentes, personas, hechos, lugares, cifras"),
    "documentación": ("a99e88", "README, guías y comentarios"),
    "herramientas": ("6b7f5a", "Puente, pruebas, pipeline, GitHub"),
    "área: mapa": ("3d4a5c", "Mapa, shader, fronteras, nombres"),
    "área: interfaz": ("3d4a5c", "Panel, leyenda, línea de tiempo, ajustes"),
    "área: enciclopedia": ("3d4a5c", "Paquetes, esquema, Wikipedia, IA"),
    "área: rendimiento": ("3d4a5c", "Velocidad, memoria, otros equipos"),
    "área: 3D": ("3d4a5c", "Vista 3D"),
    "prioridad alta": ("e06c3c", "Va primero"),
    "good first issue": ("7cc07c", "Buena para empezar a colaborar"),
    "help wanted": ("a77bb8", "Se agradece ayuda"),
}

VERSIONES = {
    "0.2": "Que todo lo que se ve se pueda tocar; mapa nítido de cerca; ejecutables",
    "0.3": "Enciclopedia progresiva: editor, Wikipedia y Wikidata, IA con revisión",
    "0.4": "Datos abiertos a escala: Pleiades, Wikidata, HYDE, vasallaje",
    "0.5": "Movimiento: migraciones, rutas, campañas y difusión animadas",
    "0.6": "Vista 3D con relieve, agua y efectos",
    "1.0": "Versiones descargables y web, guía para sumar paquetes, revisión por especialistas",
}

# Bloque de PROGRESO.md → etiquetas de sus issues
ETIQUETAS_BLOQUE = [
    ("Ahora", ["mejora", "área: interfaz", "prioridad alta"]),
    ("Mapa, rendimiento", ["mejora", "área: mapa"]),
    ("Enciclopedia progresiva", ["datos", "área: enciclopedia"]),
    ("Datos abiertos", ["datos", "área: enciclopedia"]),
    ("Movimiento", ["mejora", "área: mapa"]),
    ("Vista 3D", ["mejora", "área: 3D"]),
    ("Versión 1.0", ["mejora"]),
]


def gh(*args: str, leer: bool = False, entrada: str | None = None) -> str:
    """Corre gh. Las consultas (leer=True) corren siempre; los cambios, solo con --aplicar."""
    if not leer and not APLICAR:
        print("  [simulado] gh " + " ".join(a if " " not in a else repr(a) for a in args))
        return ""
    r = subprocess.run(["gh", *args], capture_output=True, text=True, input=entrada)
    if r.returncode != 0 and not leer:
        print(f"  ! gh {' '.join(args[:3])}…: {r.stderr.strip()[:300]}")
    return r.stdout if r.returncode == 0 else ""


def tareas_pendientes() -> list[dict]:
    """Lee «Por hacer» de PROGRESO.md: cada «- [ ]» con sus líneas de continuación es una tarea."""
    texto = (RAIZ / "PROGRESO.md").read_text(encoding="utf-8")
    texto = texto.split("\n## Hecho", 1)[0]
    tareas, actual, bloque, version, etiquetas = [], None, "", "", []
    for linea in texto.splitlines():
        if linea.startswith("### "):
            bloque = linea[4:].strip()
            m = re.search(r"\((\d\.\d)\)|Versión (\d\.\d)", bloque)
            version = (m.group(1) or m.group(2)) if m else ""
            etiquetas = next((e for clave, e in ETIQUETAS_BLOQUE if bloque.startswith(clave)), ["mejora"])
            actual = None
        elif linea.startswith("Datos que necesita"):
            etiquetas = ["datos", "área: enciclopedia", "prioridad alta"]
            actual = None
        elif linea.startswith("- [ ] "):
            actual = {"texto": linea[6:].strip(), "bloque": bloque, "version": version, "etiquetas": list(etiquetas)}
            tareas.append(actual)
        elif actual and linea.startswith("  "):
            actual["texto"] += ("\n" if linea.lstrip().startswith("- ") else " ") + linea.strip()
        elif not linea.strip():
            actual = None
    for t in tareas:
        m = re.match(r"\*\*(.+?)\*\*", t["texto"])
        titulo = m.group(1) if m else re.split(r"(?<=[a-záéíóú)])[.:](\s|$)", t["texto"])[0]
        t["titulo"] = titulo.strip().rstrip(".")[:90]
        t["cuerpo"] = (t["texto"] + f"\n\n---\nViene de [PROGRESO.md](https://github.com/{REPO}/blob/main/"
                       f"PROGRESO.md), bloque «{t['bloque']}».")
    return tareas


def main() -> int:
    print("Modo:", "APLICAR" if APLICAR else "simulación (agregá --aplicar para hacerlo)")
    if subprocess.run(["gh", "auth", "status"], capture_output=True).returncode != 0:
        print("gh no tiene sesión iniciada: corré «gh auth login» y «gh auth refresh -s project».")
        return 1

    print("\n1. Datos del repo, Issues, Discusiones y Proyectos")
    gh("repo", "edit", REPO, "--description", DESCRIPCION, "--homepage", PAGINA, "--enable-issues",
       "--enable-discussions", "--enable-projects", *[x for t in TEMAS for x in ("--add-topic", t)])

    print("\n2. Etiquetas")
    for nombre, (color, desc) in ETIQUETAS.items():
        gh("label", "create", nombre, "--repo", REPO, "--color", color, "--description", desc, "--force")

    print("\n3. Versiones (milestones)")
    existentes = {m["title"] for m in json.loads(gh("api", f"repos/{REPO}/milestones?state=all&per_page=100",
                                                       leer=True) or "[]")}
    for v, desc in VERSIONES.items():
        if v not in existentes:
            gh("api", f"repos/{REPO}/milestones", "-f", f"title={v}", "-f", f"description={desc}")

    print("\n4. Issues desde PROGRESO.md")
    ya = {i["title"]: i["url"] for i in json.loads(gh("issue", "list", "--repo", REPO, "--state", "all", "--limit",
                                                       "500", "--json", "title,url", leer=True) or "[]")}
    urls = []
    for t in tareas_pendientes():
        if t["titulo"] in ya:
            urls.append(ya[t["titulo"]])
            continue
        args = ["issue", "create", "--repo", REPO, "--title", t["titulo"], "--body", t["cuerpo"]]
        for e in t["etiquetas"]:
            args += ["--label", e]
        if t["version"]:
            args += ["--milestone", t["version"]]
        print(f"  + [{t['version'] or '—'}] {t['titulo']}")
        url = gh(*args).strip()
        if url:
            urls.append(url)

    print("\n5. Tablero del proyecto")
    proyectos = json.loads(gh("project", "list", "--owner", DUENO, "--format", "json", leer=True) or "{}")
    numero = next((p["number"] for p in proyectos.get("projects", []) if p["title"] == PROYECTO), None)
    if numero is None:
        creado = gh("project", "create", "--owner", DUENO, "--title", PROYECTO, "--format", "json")
        numero = json.loads(creado)["number"] if creado else None
    if numero is not None:
        gh("project", "link", str(numero), "--owner", DUENO, "--repo", REPO)
        for url in urls:
            gh("project", "item-add", str(numero), "--owner", DUENO, "--url", url)
        print(f"  Tablero: https://github.com/users/{DUENO}/projects/{numero} (en la web: «New view» → Board)")

    print("\n6. GitHub Pages desde main/docs")
    if gh("api", f"repos/{REPO}/pages", leer=True):
        print("  Pages ya está activado.")
    else:
        gh("api", "-X", "POST", f"repos/{REPO}/pages", "-f", "source[branch]=main", "-f", "source[path]=/docs")
    print(f"  Landing: {PAGINA}")

    print("\n7. Seguridad gratuita (repos públicos)")
    gh("api", "-X", "PATCH", f"repos/{REPO}", "--input", "-", entrada=json.dumps({"security_and_analysis": {
        "secret_scanning": {"status": "enabled"}, "secret_scanning_push_protection": {"status": "enabled"}}}))
    gh("api", "-X", "PATCH", f"repos/{REPO}/code-scanning/default-setup", "-f", "state=configured")

    print("\n8. Release 0.1")
    if gh("release", "view", "v0.1.0", "--repo", REPO, leer=True):
        print("  Ya existe.")
    else:
        notas = ("Primera versión que funciona de punta a punta: mapa 2D con fronteras de 3400 a. C. a 2024, línea de "
                 "tiempo, panel con fuentes y Wikipedia, enciclopedia piloto del antiguo Egipto, tres temas visuales. "
                 f"Detalle en [PROGRESO.md](https://github.com/{REPO}/blob/main/PROGRESO.md).")
        gh("release", "create", "v0.1.0", "--repo", REPO, "--target", "main", "--title", "TellMAP 0.1",
           "--notes", notas)

    print("\nA mano en la web (GitHub no lo deja hacer por gh):")
    print("  - Settings → General → Social preview: subir docs/img/social.jpg")
    print("  - En el tablero, cambiar la vista a «Board» y agrupar por Status")
    return 0


if __name__ == "__main__":
    sys.exit(main())
