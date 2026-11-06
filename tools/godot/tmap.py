#!/usr/bin/env python3
"""Maneja TellMAP y el editor de Godot desde la terminal, a través del puente (addons/tellmap_puente).

Uso: tools/godot/tmap.py [--proyecto RUTA] [--a juego|editor|PID] ORDEN [argumentos]

  sesiones                       puentes vivos del proyecto (editor y app)
  lanzar [--ventana] [-- ARGS]   abre la app con el puente; sin pantalla usa el compositor cage (headless)
  cerrar                         cierra las apps abiertas con «lanzar» por este usuario
  captura ARCHIVO [clave=valor]  guarda una captura (ancho=1200, region=[x,y,w,h], formato=jpg)
  eval CODIGO | -                ejecuta GDScript en la app (o en el editor con --a editor); «-» lo lee de stdin
  errores [desde=N]              errores y avisos capturados
  doc CLASE[.MIEMBRO] | ?TEXTO   referencia de la API de la versión de Godot instalada
  registros [editor] [-n N] [--errores] [--lista]
                                 el último registro guardado de la app (o del editor), en .godot/registros/
  revisar                        compila todos los scripts sin abrir la app
  prueba                         corre la prueba automática completa (--prueba)
  COMANDO [clave=valor ...]      cualquier comando del puente; «ayuda» los lista

Los valores se leen como JSON cuando se puede (anio=-1350, region=[0,0,800,600], limpiar=true).
Ejemplos:
  tools/godot/tmap.py lanzar && tools/godot/tmap.py anio anio=-1350
  tools/godot/tmap.py seleccionar lon=31 lat=27.6 && tools/godot/tmap.py captura /tmp/egipto.png ancho=1200
  tools/godot/tmap.py --proyecto ~/tmap --a editor jugar
Documentación: tools/godot/README.md.
"""

from __future__ import annotations

import base64
import json
import os
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

RAIZ_DEFECTO = Path(__file__).resolve().parents[2]


def morir(texto: str, codigo: int = 1):
    print(texto, file=sys.stderr)
    sys.exit(codigo)


def vivo(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def sesiones(proyecto: Path) -> list[dict]:
    out = []
    for f in sorted((proyecto / ".godot" / "puente").glob("*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if vivo(int(d.get("pid", 0))):
            out.append(d)
        else:
            try:
                f.unlink()
            except OSError:
                pass
    return sorted(out, key=lambda d: d.get("desde", 0), reverse=True)


def elegir(proyecto: Path, a: str) -> dict:
    todas = sesiones(proyecto)
    if a.isdigit():
        todas = [s for s in todas if s["pid"] == int(a)]
    else:
        todas = [s for s in todas if s["rol"] == a]
    if not todas:
        morir(f"No hay ningún puente «{a}» vivo en {proyecto}. "
              + ("Abrí la app con «tmap.py lanzar» o desde el editor." if a == "juego"
                 else "Abrí el proyecto en el editor de Godot (el plugin viene activado)."))
    return todas[0]


def pedir(sesion: dict, cmd: str, args: dict | None = None, espera: float = 120.0) -> dict:
    pedido = {"token": sesion["token"], "cmd": cmd, "args": args or {}, "id": 1}
    with socket.create_connection(("127.0.0.1", sesion["puerto"]), timeout=espera) as s:
        s.sendall((json.dumps(pedido) + "\n").encode())
        datos = b""
        while not datos.endswith(b"\n"):
            parte = s.recv(1 << 20)
            if not parte:
                break
            datos += parte
    if not datos:
        morir(f"El puente no respondió a «{cmd}».")
    return json.loads(datos)


def leer_args(lista: list[str]) -> dict:
    out = {}
    for x in lista:
        if "=" not in x:
            morir(f"Argumento sin «=»: {x}")
        k, v = x.split("=", 1)
        try:
            out[k] = json.loads(v)
        except json.JSONDecodeError:
            out[k] = v
    return out


def mostrar(resp: dict) -> int:
    for e in resp.get("errores", []):
        lugar = f"{e.get('archivo', '')}:{e.get('linea', '')}" if e.get("archivo") else ""
        print(f"[{e.get('tipo')}] {e.get('texto')} {lugar}".rstrip(), file=sys.stderr)
        for t in e.get("traza", [])[:6]:
            print(f"    {t}", file=sys.stderr)
    if not resp.get("ok"):
        print("ERROR:", resp.get("error"), file=sys.stderr)
        return 1
    r = resp.get("r")
    if r not in (None, {}, []):
        print(r if isinstance(r, str) else json.dumps(r, ensure_ascii=False, indent=1))
    return 0


def anotar(texto: str, titulo: str = "TellMAP") -> None:
    """En GitHub Actions, publica el texto como anotación de error del check: se ve en la página de la corrida y en
    la API pública, sin descargar el registro."""
    if os.environ.get("GITHUB_ACTIONS") == "true":
        texto = texto.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
        print(f"::error title={titulo}::{texto}")


def godot() -> str:
    g = shutil.which("godot") or shutil.which("godot4")
    if not g:
        morir("No encuentro el ejecutable de Godot (godot) en el PATH.")
    return g


# ---------------------------------------------------------------------------------------------------------------


def orden_lanzar(proyecto: Path, resto: list[str]) -> int:
    ventana = "--ventana" in resto
    extra = resto[resto.index("--") + 1:] if "--" in resto else []
    etiqueta = secrets.token_hex(4)
    dir_s = proyecto / ".godot" / "puente"
    dir_s.mkdir(parents=True, exist_ok=True)
    log = open(dir_s / f"lanzada-{etiqueta}.log", "w")
    args = [godot(), "--path", str(proyecto)]
    env = dict(os.environ)
    hay_pantalla = bool(env.get("WAYLAND_DISPLAY") or env.get("DISPLAY"))
    if not (ventana and hay_pantalla):
        if not shutil.which("cage"):
            morir("Sin pantalla hace falta el compositor cage (o usá --ventana desde una sesión gráfica).")
        env.update(XDG_RUNTIME_DIR=tempfile.mkdtemp(prefix="tmap-cage-"), WLR_BACKENDS="headless",
                   WLR_LIBINPUT_NO_DEVICES="1", WLR_RENDERER=env.get("WLR_RENDERER", "gles2"),
                   WLR_RENDER_DRM_DEVICE=env.get("WLR_RENDER_DRM_DEVICE", "/dev/dri/renderD128"))
        env.pop("WAYLAND_DISPLAY", None)
        env.pop("DISPLAY", None)
        args = ["cage", "--"] + args + ["--display-driver", "wayland"]
    args += ["--", "--puente", f"--puente-etiqueta={etiqueta}", "--puente-autocierre=900"] + extra
    proc = subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    limite = time.time() + 60
    while time.time() < limite:
        s = [x for x in sesiones(proyecto) if x.get("etiqueta") == etiqueta]
        if s:
            resp = pedir(s[0], "listo", espera=120)
            print(f"App lista (pid {s[0]['pid']}, puerto {s[0]['puerto']}); se cierra sola tras 15 min sin pedidos.")
            return mostrar(resp)
        if proc.poll() is not None:
            break
        time.sleep(0.3)
    morir(f"La app no abrió el puente. Salida en {log.name}")


def orden_cerrar(proyecto: Path) -> int:
    yo = os.environ.get("USER")
    n = 0
    for s in sesiones(proyecto):
        if s["rol"] == "juego" and s.get("lanzada_con_puente") and s.get("usuario") == yo:
            pedir(s, "salir")
            n += 1
    print(f"Cerré {n} app(s).")
    return 0


def orden_captura(sesion: dict, resto: list[str]) -> int:
    if not resto:
        morir("Uso: captura ARCHIVO [clave=valor]")
    salida = Path(resto[0]).expanduser()
    args = leer_args(resto[1:])
    if salida.suffix.lower() in (".jpg", ".jpeg"):
        args.setdefault("formato", "jpg")
    resp = pedir(sesion, "captura", args)
    if resp.get("ok"):
        r = resp["r"]
        salida.write_bytes(base64.b64decode(r.pop("base64")))
        resp["r"] = f"{salida} ({r['ancho']}×{r['alto']})"
    return mostrar(resp)


def ref_dir() -> Path:
    v = subprocess.run([godot(), "--version"], capture_output=True, text=True).stdout.strip()
    version = ".".join(v.split(".")[:3])
    base = Path.home() / ".cache" / "tellmap" / f"godot-doc-{version}"
    clases = base / "doc" / "classes"
    if not clases.is_dir():
        print(f"Generando la referencia de Godot {version} en {base}…", file=sys.stderr)
        base.mkdir(parents=True, exist_ok=True)
        subprocess.run([godot(), "--headless", "--doctool", str(base)], cwd=base, capture_output=True)
    return clases


def firma(m: ET.Element) -> str:
    ret = m.find("return")
    params = ", ".join(f"{p.get('name')}: {p.get('type')}" + (f" = {p.get('default')}" if p.get("default") else "")
                       for p in m.findall("param"))
    q = f" {m.get('qualifiers')}" if m.get("qualifiers") else ""
    return f"{m.get('name')}({params}) -> {ret.get('type') if ret is not None else 'void'}{q}"


def orden_doc(resto: list[str]) -> int:
    if not resto:
        morir("Uso: doc CLASE[.MIEMBRO] | ?TEXTO")
    clases = ref_dir()
    q = resto[0]
    if q.startswith("?"):
        texto = q[1:].lower()
        hallados = []
        for f in sorted(clases.glob("*.xml")):
            for m in ET.parse(f).getroot().iter():
                if m.tag in ("method", "member", "signal") and texto in (m.get("name") or "").lower():
                    hallados.append(f"{f.stem}.{m.get('name')} ({m.tag})")
        print("\n".join(hallados[:60]) or "Nada.")
        return 0
    clase, _, miembro = q.partition(".")
    f = clases / f"{clase}.xml"
    if not f.exists():
        morir(f"No existe la clase {clase}.")
    raiz = ET.parse(f).getroot()
    print(f"{clase} hereda de {raiz.get('inherits', '—')}  ·  https://docs.godotengine.org/en/stable/classes/"
          f"class_{clase.lower()}.html")
    for sec, etiqueta in (("methods", "method"), ("members", "member"), ("signals", "signal"),
                          ("constants", "constant")):
        items = [m for m in raiz.findall(f"{sec}/{etiqueta}") if not miembro or m.get("name") == miembro]
        if not items:
            continue
        print(f"\n{sec}:")
        for m in items:
            if etiqueta in ("method", "signal"):
                print("  " + firma(m))
            elif etiqueta == "member":
                print(f"  {m.get('name')}: {m.get('type')} = {m.get('default', '')}")
            else:
                print(f"  {m.get('name')} = {m.get('value')}" + (f" ({m.get('enum')})" if m.get("enum") else ""))
    return 0


def orden_registros(proyecto: Path, resto: list[str]) -> int:
    rol = "editor" if "editor" in resto else "juego"
    n = int(resto[resto.index("-n") + 1]) if "-n" in resto else 80
    archivos = sorted((proyecto / ".godot" / "registros").glob(f"{rol}-*.log"), key=lambda f: f.stat().st_mtime)
    if not archivos:
        morir(f"Todavía no hay registros de «{rol}» en {proyecto / '.godot' / 'registros'}.")
    if "--lista" in resto:
        for f in archivos:
            print(f"{f.name}  ({f.stat().st_size // 1024} KB)")
        return 0
    f = archivos[-1]
    lineas = f.read_text(encoding="utf-8", errors="replace").splitlines()
    if "--errores" in resto:
        sigue = False
        filtradas = []
        for l in lineas:
            if l[:1].isdigit():
                sigue = " MENSAJE " not in l
            if sigue or not l[:1].isdigit():
                filtradas.append(l)
        lineas = filtradas
    print(f"== {f}")
    print("\n".join(lineas[-n:]))
    return 0


def orden_revisar(proyecto: Path) -> int:
    try:
        r = subprocess.run([godot(), "--headless", "--path", str(proyecto), "-s",
                            "res://addons/tellmap_puente/revisar.gd"], capture_output=True, text=True, timeout=300)
    except subprocess.TimeoutExpired as e:
        salida = ((e.stdout or b"") + (e.stderr or b"")).decode("utf-8", "replace") if isinstance(e.stdout, bytes) \
            else (e.stdout or "") + (e.stderr or "")
        anotar("Godot no terminó en 5 minutos. Última salida:\n" + "\n".join(salida.splitlines()[-25:]), "revisar")
        print(salida)
        return 1
    lineas = [l for l in (r.stdout + r.stderr).splitlines() if l.strip() and not l.startswith("Godot Engine")]
    print("\n".join(lineas))
    if r.returncode != 0:
        anotar(f"Código de salida {r.returncode}. Salida de Godot:\n" + "\n".join(lineas[-30:]), "revisar")
    return r.returncode


def main() -> int:
    argv = sys.argv[1:]
    proyecto = Path(os.environ.get("TMAP_PROYECTO", RAIZ_DEFECTO))
    a = "juego"
    while argv and argv[0] in ("--proyecto", "--a"):
        if argv[0] == "--proyecto":
            proyecto = Path(argv[1]).expanduser().resolve()
        else:
            a = argv[1]
        argv = argv[2:]
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    orden, resto = argv[0], argv[1:]
    if orden == "sesiones":
        for s in sesiones(proyecto):
            print(f"{s['rol']:7} pid {s['pid']:<8} puerto {s['puerto']}  {s.get('usuario', '')}"
                  + ("  (lanzada)" if s.get("lanzada_con_puente") else ""))
        return 0
    if orden == "lanzar":
        return orden_lanzar(proyecto, resto)
    if orden == "cerrar":
        return orden_cerrar(proyecto)
    if orden == "doc":
        return orden_doc(resto)
    if orden == "registros":
        return orden_registros(proyecto, resto)
    if orden == "revisar":
        return orden_revisar(proyecto)
    if orden == "prueba":
        r = subprocess.run([godot(), "--headless", "--path", str(proyecto), "--", "--prueba"],
                           capture_output=True, text=True, timeout=600)
        malas = [l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l or "[prueba]" in l]
        print("\n".join(malas[-30:]))
        bien = "TERMINADA sin cortes" in r.stdout and not any("ERROR" in l for l in malas)
        if not bien:
            todo = (r.stdout + r.stderr).splitlines()
            anotar(f"Código de salida {r.returncode}. Errores:\n" + "\n".join(malas[-20:])
                   + "\n--- final de la salida:\n" + "\n".join(todo[-15:]), "prueba")
        return 0 if bien else 1
    sesion = elegir(proyecto, a)
    if orden == "captura":
        return orden_captura(sesion, resto)
    if orden == "eval":
        codigo = sys.stdin.read() if resto == ["-"] else " ".join(resto)
        return mostrar(pedir(sesion, "eval", {"codigo": codigo}))
    return mostrar(pedir(sesion, orden, leer_args(resto)))


if __name__ == "__main__":
    sys.exit(main())
