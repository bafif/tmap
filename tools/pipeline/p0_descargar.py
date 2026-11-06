"""Paso 0: baja a `tools/pipeline/cache/` los datos que no se guardan en el repo por su tamaño.

- Cliopatria (Seshat Global History Databank), CC BY 4.0: fronteras de entidades políticas de -3400 a 2024.
"""

from __future__ import annotations

import shutil
import urllib.request
import zipfile

from comun import CACHE

CLIOPATRIA_URL = (
    "https://github.com/Seshat-Global-History-Databank/cliopatria/raw/main/cliopatria.geojson.zip"
)


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    destino = CACHE / "cliopatria.geojson"
    if destino.exists():
        print("Cliopatria ya está en la caché:", destino)
        return
    zip_path = CACHE / "cliopatria.geojson.zip"
    print("Bajando Cliopatria…")
    with urllib.request.urlopen(CLIOPATRIA_URL) as r, open(zip_path, "wb") as f:
        shutil.copyfileobj(r, f)
    with zipfile.ZipFile(zip_path) as z:
        nombre = next(n for n in z.namelist() if n.endswith(".geojson"))
        with z.open(nombre) as src, open(destino, "wb") as dst:
            shutil.copyfileobj(src, dst)
    zip_path.unlink()
    print("Listo:", destino, f"({nombre})")


if __name__ == "__main__":
    main()
