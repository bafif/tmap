"""Enlaces de lectura que no se pierdan: la copia en la Wayback Machine de cada enlace `leer` de la enciclopedia.

Escribe `data/enciclopedia/archivo.json` (url del enlace → url de su copia en web.archive.org), que la app ofrece al
lado de cada enlace, por si el original se cae o se mueve. La copia vive aparte y no en los paquetes: así esta
herramienta no reescribe lo que se edita a mano o con el editor, y se puede volver a correr sin chocar con nadie.
Los enlaces a archive.org no necesitan copia (ya están en Internet Archive).

Se corre a mano antes de cada versión (ver docs/es/almacenamiento.md):
  python3 tools/enciclopedia/enlaces.py              busca la copia de los enlaces nuevos (unos 3 s cada uno)
  python3 tools/enciclopedia/enlaces.py --guardar    además pide a la Wayback Machine que archive los que no tienen
                                                     copia (lento: uno cada 15 s, y para si lo frena)
  python3 tools/enciclopedia/enlaces.py --comprobar  además comprueba que cada original responda y lista los caídos
  python3 tools/enciclopedia/enlaces.py --resumen    cuántos enlaces tienen copia
"""
from __future__ import annotations

import concurrent.futures
import json
import socket
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# IPv4 primero: con IPv6 roto (pasa en algunas redes), urllib espera el timeout entero en cada pedido.
_getaddrinfo = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: sorted(_getaddrinfo(*a, **k), key=lambda r: r[0] != socket.AF_INET)

RAIZ = Path(__file__).resolve().parents[2]
PAQUETES = RAIZ / "data" / "enciclopedia" / "paquetes"
SALIDA = RAIZ / "data" / "enciclopedia" / "archivo.json"
UA = {"User-Agent": "tmap-enlaces/0.4 (https://bafif.github.io/tmap; tools/enciclopedia/enlaces.py)"}
DISPONIBLE = "https://archive.org/wayback/available"
## La Wayback Machine corta a quien le pide mucho a la vez: la búsqueda de copias va de a un pedido.
HILOS = 1


def enlaces() -> list[str]:
    urls = set()
    for ruta in sorted(PAQUETES.glob("*.json")):
        for f in json.loads(ruta.read_text(encoding="utf-8")).get("fuentes", []):
            for l in f.get("leer") or []:
                url = str(l.get("url", ""))
                if url.startswith(("http://", "https://")):
                    urls.add(url)
    return sorted(urls)


def necesita_copia(url: str) -> bool:
    host = urllib.parse.urlsplit(url).hostname or ""
    return not (host == "archive.org" or host.endswith(".archive.org"))


def leer_archivo() -> dict[str, str]:
    if SALIDA.exists():
        return json.loads(SALIDA.read_text(encoding="utf-8")).get("copias", {})
    return {}


def escribir(copias: dict[str, str]) -> None:
    datos = {"fuente": "Wayback Machine de Internet Archive (https://web.archive.org), la última copia que respondió "
                       "200; la arma tools/enciclopedia/enlaces.py",
             "copias": dict(sorted(copias.items()))}
    SALIDA.write_text(json.dumps(datos, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def pedir(url: str, timeout: float = 60) -> tuple[int, bytes]:
    for intento in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 502, 503, 504) and intento < 3:
                time.sleep(10 * (intento + 1))
                continue
            return e.code, b""
        except OSError:
            if intento == 3:
                return 0, b""
            time.sleep(5 * (intento + 1))
    return 0, b""


def copia(url: str) -> str:
    """La copia más reciente de `url` en la Wayback Machine que respondió 200, o "".

    Usa la API de disponibilidad (archive.org/wayback/available), de a un pedido: la API CDX de web.archive.org es
    más completa, pero con varios pedidos seguidos deja de aceptar conexiones."""
    q = urllib.parse.urlencode({"url": url, "timestamp": time.strftime("%Y%m%d")})
    codigo, cuerpo = pedir(f"{DISPONIBLE}?{q}")
    if codigo != 200 or not cuerpo.strip():
        return ""
    cerca = json.loads(cuerpo).get("archived_snapshots", {}).get("closest", {})
    if not cerca.get("available") or str(cerca.get("status")) != "200":
        return ""
    return str(cerca["url"]).replace("http://web.archive.org/", "https://web.archive.org/", 1)


def guardar(url: str) -> bool:
    codigo, _ = pedir(f"https://web.archive.org/save/{url}", timeout=120)
    return codigo == 200


def responde(url: str) -> int:
    req = urllib.request.Request(url, headers=UA, method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        if e.code in (403, 405):  # hay sitios que no aceptan HEAD o rechazan programas: se prueba con GET
            return pedir(url, timeout=30)[0]
        return e.code
    except OSError:
        return 0


def main() -> None:
    urls = enlaces()
    copias = {u: c for u, c in leer_archivo().items() if u in set(urls)}  # se olvidan los enlaces que ya no están
    con_copia = [u for u in urls if necesita_copia(u)]
    if "--resumen" in sys.argv:
        print(f"{len(urls)} enlaces, {len(con_copia)} fuera de archive.org, {len(copias)} con copia")
        return
    faltan = [u for u in con_copia if u not in copias]
    print(f"{len(urls)} enlaces; {len(con_copia) - len(faltan)} ya tenían copia; buscando {len(faltan)}…")
    sin_copia = []
    with concurrent.futures.ThreadPoolExecutor(HILOS) as ex:
        for i, (u, c) in enumerate(zip(faltan, ex.map(copia, faltan)), 1):
            if c:
                copias[u] = c
            else:
                sin_copia.append(u)
            if i % 50 == 0:
                escribir(copias)
                print(f"  {i}/{len(faltan)}")
    escribir(copias)
    if "--guardar" in sys.argv and sin_copia:
        print(f"pidiendo a la Wayback Machine que archive {len(sin_copia)}…")
        frenos = 0
        for u in sin_copia[:]:
            if guardar(u):
                c = copia(u)
                if c:
                    copias[u] = c
                    sin_copia.remove(u)
                    escribir(copias)
                frenos = 0
            else:
                frenos += 1
                if frenos >= 3:
                    print("  la Wayback Machine frena los pedidos: se sigue en otra corrida")
                    break
            time.sleep(15)
    print(f"{SALIDA.relative_to(RAIZ)}: {len(copias)} de {len(con_copia)} enlaces con copia")
    for u in sin_copia:
        print("  sin copia:", u)
    if "--comprobar" in sys.argv:
        with concurrent.futures.ThreadPoolExecutor(HILOS) as ex:
            caidos = [(u, c) for u, c in zip(urls, ex.map(responde, urls)) if c not in (200, 301, 302)]
        print(f"{len(caidos)} originales que no responden 200:")
        for u, c in caidos:
            print(f"  {c or 'sin respuesta'}: {u}" + ("  (hay copia)" if u in copias else ""))


if __name__ == "__main__":
    main()
