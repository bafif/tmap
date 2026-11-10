#!/usr/bin/env python3
"""Prueba de punta a punta de las actualizaciones automáticas (docs/es/actualizaciones.md).

Arma una «versión publicada» falsa en una carpeta temporal (manifiesto y .gz, con un paquete de enciclopedia de más),
la sirve por HTTP en 127.0.0.1 y corre TellMAP con -- --actualizaciones=<url> y una carpeta de usuario aparte
(XDG_DATA_HOME), así no toca los ajustes ni los datos de quien la corre. Comprueba que:

  1. al abrir ofrece los datos nuevos, y con «Ahora no» no baja ni cambia nada;
  2. con «Actualizar» baja e instala los datos nuevos, y la app los lee (una fuente más);
  3. otra búsqueda dice que está al día, y al abrir ya no pregunta nada;
  4. un archivo adulterado (sha256 que no coincide) se rechaza y siguen valiendo los datos de antes;
  5. con --ejecutable (un TellMAP exportado): ofrece la versión «nueva» y «Ahora no» deja el ejecutable como estaba;
     se reemplaza solo por la nueva, que arranca bien, y un ejecutable adulterado no se instala.

  python3 tools/actualizacion/probar.py                                  # con godot, desde el código fuente
  python3 tools/actualizacion/probar.py --ejecutable build/linux/TellMAP.x86_64

"""

import argparse
import functools
import http.server
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import publicar  # noqa: E402

RAIZ = publicar.RAIZ
PAQUETE_PRUEBA = {
    "paquete": "prueba-actualizacion",
    "fuentes": [{"id": "prueba-actualizacion", "titulo": "Fuente de la prueba de actualización", "anio": 2026}],
}


class Silencioso(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


def correr(cmd: list[str], env: dict, *extra: str) -> tuple[int, str]:
    r = subprocess.run(cmd + list(extra), env=env, capture_output=True, text=True, timeout=600)
    return r.returncode, r.stdout + r.stderr


def fuentes(salida: str) -> tuple[int, str]:
    m = re.search(r"TellMAP bien: .*?(\d+) fuentes, .*?; datos (.+)", salida)
    if not m:
        raise AssertionError("--verificar no dijo «TellMAP bien»:\n" + salida[-3000:])
    return int(m.group(1)), m.group(2).strip()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ejecutable", type=Path, help="un TellMAP exportado (prueba también el reemplazo de la app)")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--conservar", action="store_true", help="no borrar la carpeta temporal")
    a = ap.parse_args()

    tmp = Path(tempfile.mkdtemp(prefix="tellmap-actualizacion-"))
    remoto = tmp / "remoto"
    remoto.mkdir()
    env = dict(os.environ, XDG_DATA_HOME=str(tmp / "usuario"))
    servidor = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Silencioso, directory=str(remoto)))
    threading.Thread(target=servidor.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{servidor.server_address[1]}/"
    fallas: list[str] = []

    def chequear(cond: bool, texto: str, salida: str = "") -> None:
        print(("bien  " if cond else "MAL   ") + texto)
        if not cond:
            fallas.append(texto)
            if salida:
                print("      " + salida[-2500:].replace("\n", "\n      "))

    if a.ejecutable:
        exe = tmp / "app" / a.ejecutable.name
        exe.parent.mkdir()
        shutil.copy2(a.ejecutable, exe)
        cmd = [str(exe), "--headless", "--"]
    else:
        cmd = [a.godot, "--headless", "--path", str(RAIZ), "--"]
    # Los mensajes que se comprueban están en español: la app no tiene que elegir el idioma por el del equipo.
    cmd.append("--idioma=es")

    try:
        # La «versión publicada»: los datos del repo más un paquete, con una versión posterior a cualquier sello.
        datos2 = tmp / "datos2"
        shutil.copytree(RAIZ / "data", datos2, ignore=shutil.ignore_patterns("*.import", "version.json"))
        (datos2 / "enciclopedia/paquetes/zz-prueba-actualizacion.json").write_text(
            json.dumps(PAQUETE_PRUEBA, indent=2, ensure_ascii=False), encoding="utf-8")
        version_app = publicar.version_app()
        previo = {"app": {"version": version_app, "etiqueta": f"v{version_app}", "pagina": base}}
        v2 = int(time.time()) + 100
        publicar.manifiesto("datos-prueba", remoto, previo, {}, datos2, version=v2, base_url=base)
        url = base + "actualizacion.json"

        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--verificar")
        n0, d0 = fuentes(sal)
        print(f"antes: {n0} fuentes, datos {d0}")
        carpeta_datos = tmp / "usuario/godot/app_userdata/TellMAP/datos"

        # Lo que pasa al abrir la app: el cartel, contestado con «Ahora no» y después con «Actualizar».
        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--preguntar-y-salir=no")
        chequear(rc == 0 and "Hay una actualización: datos del" in sal and "Quedó para después" in sal,
                 "al abrir ofrece los datos nuevos, y «Ahora no» no da error", sal)
        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--verificar")
        nn, dn = fuentes(sal)
        bajado = [p.name for p in carpeta_datos.iterdir() if p.is_dir()] if carpeta_datos.exists() else []
        chequear(nn == n0 and dn == d0 and not bajado, f"«Ahora no» no bajó ni instaló nada ({bajado})", sal)

        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--preguntar-y-salir=si")
        chequear(rc == 0 and "Hay una actualización" in sal and "instalados" in sal,
                 "con «Actualizar» baja e instala los datos nuevos", sal)
        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--verificar")
        n1, d1 = fuentes(sal)
        chequear(n1 == n0 + 1 and d1.startswith(str(v2)) and "enciclopedia" in d1,
                 f"la app lee los datos nuevos ({n1} fuentes, datos {d1})", sal)
        chequear("mapa" not in d1, "solo se actualizó la enciclopedia (el mapa sigue siendo el de adentro)", sal)

        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--actualizar-y-salir")
        chequear(rc == 0 and "al día" in sal, "otra búsqueda dice que está al día", sal)
        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--preguntar-y-salir=no")
        chequear(rc == 0 and "al día" in sal and "Hay una actualización" not in sal,
                 "al día, al abrir no pregunta nada", sal)

        # Un archivo adulterado: el manifiesto anuncia otro sha256.
        (datos2 / "enciclopedia/paquetes/zz-prueba-actualizacion.json").write_text("{}", encoding="utf-8")
        remoto3 = tmp / "remoto3"
        publicado = json.loads((remoto / "actualizacion.json").read_text(encoding="utf-8"))
        m3 = publicar.manifiesto("datos-prueba-3", remoto3, publicado, {}, datos2, version=v2 + 10, base_url=base)
        for p in remoto3.glob("*.gz"):
            shutil.move(p, remoto / p.name)
        m3["datos"]["archivos"]["enciclopedia/paquetes/zz-prueba-actualizacion.json"]["sha256_gz"] = "0" * 64
        (remoto / "adulterado.json").write_text(json.dumps(m3), encoding="utf-8")
        rc, sal = correr(cmd, env, f"--actualizaciones={base}adulterado.json", "--actualizar-y-salir")
        chequear(rc == 1 and "sha256" in sal, "rechaza un archivo adulterado", sal)
        rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--verificar")
        n2, d2 = fuentes(sal)
        chequear(n2 == n1 and d2 == d1, "siguen valiendo los datos de antes", sal)
        restos = sorted(p.name for p in (tmp / "usuario/godot/app_userdata/TellMAP/datos").iterdir())
        chequear(restos == [str(v2), "activo.json"], f"en la carpeta del usuario queda solo lo activo ({restos})")

        if a.ejecutable:
            plataforma = "linux-x86_64"
            nombre = "TellMAP-99.0.0-linux-x86_64.gz"
            m4 = {"formato": 1, "datos": {"version": 0, "archivos": {}},
                  "app": {"version": "99.0.0", "etiqueta": "v99.0.0", "pagina": base,
                          plataforma: {"url": base + nombre, **publicar._gz(a.ejecutable.read_bytes(), remoto / nombre)}}}
            malo = json.loads(json.dumps(m4))
            malo["app"][plataforma]["sha256"] = "0" * 64
            (remoto / "app-mala.json").write_text(json.dumps(malo), encoding="utf-8")
            (remoto / "app.json").write_text(json.dumps(m4), encoding="utf-8")
            inodo = exe.stat().st_ino
            rc, sal = correr(cmd, env, f"--actualizaciones={base}app.json", "--preguntar-y-salir=no")
            chequear(rc == 0 and "Hay una actualización: TellMAP 99.0.0" in sal and "Quedó para después" in sal
                     and exe.stat().st_ino == inodo and not list(exe.parent.glob("*.nuevo")),
                     "ofrece la app nueva, y «Ahora no» deja el ejecutable como estaba", sal)
            rc, sal = correr(cmd, env, f"--actualizaciones={base}app-mala.json", "--actualizar-y-salir")
            chequear(rc == 1 and exe.stat().st_ino == inodo, "no instala un ejecutable adulterado", sal)
            rc, sal = correr(cmd, env, f"--actualizaciones={base}app.json", "--actualizar-y-salir")
            chequear(rc == 0 and "99.0.0 quedó instalada" in sal, "baja e instala la app nueva", sal)
            chequear(exe.stat().st_ino != inodo and os.access(exe, os.X_OK)
                     and publicar.sha256(exe.read_bytes()) == m4["app"][plataforma]["sha256"]
                     and not list(exe.parent.glob("*.nuevo")),
                     "el ejecutable quedó reemplazado, con permiso de ejecución y sin restos")
            rc, sal = correr(cmd, env, f"--actualizaciones={url}", "--verificar")
            chequear(rc == 0 and "TellMAP bien" in sal, "la app nueva arranca", sal)
    finally:
        servidor.shutdown()
        if a.conservar or fallas:
            print(f"Carpeta de la prueba: {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)
    print("Todo bien." if not fallas else f"{len(fallas)} falla(s).")
    sys.exit(1 if fallas else 0)


if __name__ == "__main__":
    main()
