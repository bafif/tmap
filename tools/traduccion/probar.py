#!/usr/bin/env python3
"""Prueba de ida y vuelta de las traducciones de la enciclopedia, en una carpeta temporal (no toca la capa del repo):

1. `enciclopedia.py extraer` saca todos los textos traducibles en lotes.
2. Se «traducen» con un prefijo («[EN] …») y se guardan como respuestas, una dentro de un bloque de código.
3. `enciclopedia.py aplicar` las vuelca en una capa de traducción; una segunda extracción ya no tiene nada pendiente.
4. La app, en inglés y leyendo esa capa (--traducciones), carga cada texto traducido; en español, ninguno.
5. Si el español cambia (un hash distinto), `extraer` lo vuelve a pedir.

Uso: python3 tools/traduccion/probar.py [--conservar]     (necesita godot en el PATH; sale con 1 si algo falla)
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import enciclopedia as E

RAIZ = E.RAIZ
HERRAMIENTA = Path(__file__).resolve().parent / "enciclopedia.py"
PREFIJO = "[EN] "
fallas: list[str] = []


def chequear(cond: bool, texto: str, detalle: str = "") -> None:
    print(("bien  " if cond else "MAL   ") + texto)
    if not cond:
        fallas.append(texto)
        if detalle:
            print("      " + detalle[-2500:].replace("\n", "\n      "))


def correr(*args: str) -> tuple[int, str]:
    r = subprocess.run([sys.executable, str(HERRAMIENTA), *args],
                       check=False, capture_output=True, text=True, timeout=300)
    return r.returncode, r.stdout + r.stderr


def volcar(godot: str, idioma: str, capa: Path, salida: Path) -> tuple[int, str, dict]:
    r = subprocess.run([godot, "--headless", "--path", str(RAIZ), "--", f"--idioma={idioma}",
                        f"--traducciones={capa}/", f"--volcar={salida}"],
                       check=False, capture_output=True, text=True, timeout=600)
    datos = json.loads(salida.read_text(encoding="utf-8")) if salida.exists() else {}
    return r.returncode, r.stdout + r.stderr, datos


def valor_en(volcado: dict, clave: str):
    """El valor de «sección/id/campo» en la enciclopedia volcada por la app."""
    seccion, id_, campo = clave.split("/", 2)
    item = next((x for x in volcado.get(seccion, []) if E.id_de(seccion, x) == id_), None)
    for paso in campo.split("."):
        if isinstance(item, list):
            item = item[int(paso)] if paso.isdigit() and int(paso) < len(item) else None
        elif isinstance(item, dict):
            item = item.get(paso)
        else:
            return None
    return item


def main() -> int:
    godot = shutil.which("godot") or shutil.which("godot4")
    if not godot:
        print("No encuentro godot en el PATH.")
        return 2
    tmp = Path(tempfile.mkdtemp(prefix="tmap-traduccion-"))
    capa, lotes, respuestas = tmp / "capa", tmp / "lotes", tmp / "respuestas"
    try:
        # 1. Extraer todo (la capa temporal está vacía)
        rc, sal = correr("extraer", str(lotes), "--capa", str(capa))
        archivos = sorted(lotes.glob("[0-9][0-9][0-9].json"))
        chequear(rc == 0 and archivos and (lotes / E.MANIFIESTO).exists(), f"extraer: {sal.strip().splitlines()[-1]}", sal)
        manifiesto = json.loads((lotes / E.MANIFIESTO).read_text(encoding="utf-8"))
        largos = [sum(len(t) for t in json.loads(a.read_text(encoding="utf-8")).values()) for a in archivos]
        chequear(max(largos) <= 20000, f"ningún lote pasa de 20 000 caracteres (el mayor tiene {max(largos)})")
        claves = [c for a in archivos for c in json.loads(a.read_text(encoding="utf-8"))]
        chequear(len(claves) == len(set(claves)) == len(manifiesto["textos"]), "cada clave está en un solo lote")

        # 2. Respuestas de prueba: el primer lote dentro de un bloque de código, como lo devolvería un modelo
        respuestas.mkdir()
        for i, a in enumerate(archivos):
            lote = json.loads(a.read_text(encoding="utf-8"))
            cuerpo = json.dumps({k: PREFIJO + v for k, v in lote.items()}, ensure_ascii=False, indent=1)
            if i == 0:
                (respuestas / f"{a.stem}-respuesta.md").write_text(f"Acá está:\n\n```json\n{cuerpo}\n```\n", encoding="utf-8")
            else:
                (respuestas / a.name).write_text(cuerpo, encoding="utf-8")

        # 3. Aplicar y volver a extraer
        rc, sal = correr("aplicar", str(respuestas), "--extraccion", str(lotes), "--capa", str(capa))
        chequear(rc == 0, f"aplicar: {sal.strip().splitlines()[-1]}", sal)
        rc, sal = correr("extraer", str(tmp / "lotes2"), "--capa", str(capa))
        chequear(rc == 0 and not list((tmp / "lotes2").glob("[0-9]*.json")), "después de aplicar no queda nada pendiente", sal)

        # 4. La app en inglés lee cada texto traducido; en español, ninguno
        esperados = {}
        for paquete, textos in E.paquetes().items():
            for clave, texto in textos.items():
                esperados.setdefault(clave, texto)
        rc, sal, en = volcar(godot, "en", capa, tmp / "en.json")
        chequear(rc == 0 and en.get("idioma") == "en", "la app en inglés carga la enciclopedia con la capa de prueba", sal)
        mal = [c for c, t in esperados.items() if valor_en(en, c) != PREFIJO + t]
        chequear(not mal, f"en inglés, los {len(esperados)} textos traducibles salen traducidos "
                 f"({en.get('traducidos')} aplicados)", "\n".join(f"{c}: {valor_en(en, c)!r}" for c in mal[:10]))
        chequear(all(x.get("id") and not str(x["id"]).startswith(PREFIJO) for x in en.get("fuentes", [])),
                 "los ids no se traducen")
        rc, sal, es = volcar(godot, "es", capa, tmp / "es.json")
        mal = [c for c, t in esperados.items() if valor_en(es, c) != t]
        chequear(rc == 0 and es.get("idioma") == "es" and not mal, "en español, la capa no se aplica",
                 sal + "\n".join(mal[:10]))

        # 5. Un texto español que cambió (otro hash) vuelve a pedirse
        paquete = next(p.stem for p in sorted((capa / "en").glob("*.json")))
        ruta = capa / "en" / f"{paquete}.json"
        datos = json.loads(ruta.read_text(encoding="utf-8"))
        clave = next(iter(datos["textos"]))
        datos["textos"][clave]["hash"] = "0000000000"
        E.escribir_capa(capa, "en", paquete, datos["textos"])
        rc, sal = correr("estado", "--capa", str(capa))
        chequear("1 viejos" in sal, "estado cuenta el texto viejo", sal)
        rc, sal = correr("extraer", str(tmp / "lotes3"), "--capa", str(capa))
        lote = json.loads((tmp / "lotes3" / "001.json").read_text(encoding="utf-8")) if rc == 0 else {}
        chequear(list(lote) == [f"{paquete}/{clave}"], "extraer pide solo el texto viejo", sal)
    finally:
        if "--conservar" in sys.argv:
            print(f"Carpeta de la prueba: {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)
    print("Todo bien." if not fallas else f"{len(fallas)} falla(s).")
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
