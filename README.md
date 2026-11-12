<div align="center">

# TellMAP

**La historia del mundo en un mapa vivo, con sus fuentes a mano.**<br>
[English](README.en.md) · [Sitio](https://bafif.github.io/tmap/) · [Instalar](#instalar) · [Cómo se usa](#cómo-se-usa)

</div>

Mové la línea de tiempo y mirá cómo se corren las fronteras, nacen las ciudades y aparecen los textos que se
escribieron en cada lugar. Un *tell* es la colina que dejan siglos de ciudades levantadas una sobre otra: en TellMAP
elegís un lugar, bajás por sus capas y en cada una encontrás quién gobernaba, quién vivía ahí, qué pasó y qué se
escribió. En español y en inglés, para Linux, Windows y macOS.

<p align="center"><img src="docs/assets/portada.png" width="100%" alt="TellMAP en 1350 a. C.: Egipto seleccionado,
con el panel lateral que lista las fuentes escritas ahí en esa época, como las Cartas de Amarna y el Gran Himno a
Atón"></p>

## Por qué TellMAP

- **Fronteras con respaldo.** Salen de [Cliopatria](https://github.com/Seshat-Global-History-Databank/cliopatria), del
  Seshat Global History Databank: 13 400 registros revisados por historiadores, de 3400 a. C. a 2024. El mapa se divide
  en 58 000 unidades que siguen esas fronteras, no en una grilla que las aproxima.
- **Cada texto, en dos lugares.** Una fuente se ubica donde y cuando se escribió, y en el lugar y la época de los que
  trata. En el Egipto de 1350 a. C. aparecen el *Gran Himno a Atón*, escrito en Amarna en ese momento, Heródoto, que lo
  contó novecientos años después, y los egiptólogos que lo estudiaron en el siglo XX.
- **Fuentes primero.** Cada ficha distingue las fuentes primarias de los estudios, dice qué tan segura es su fecha y
  lleva al texto completo en Wikisource, Perseus, el Proyecto Gutenberg o Internet Archive cuando está en dominio
  público.
- **Nada inventado.** Las cifras de población son estimaciones publicadas, con su autor y su rango; las que dan los
  autores antiguos se muestran aparte, como testimonio. Lo que no se sabe, se dice.
- **Una enciclopedia que crece a la vista.** Son paquetes JSON legibles que se editan con formularios dentro de la app.
  Las fichas nuevas salen de borradores de Wikipedia y Wikidata, y las que redacta una IA citan sus fuentes y no se
  publican sin revisión humana.
- **Sin cuentas ni telemetría.** Corre en tu computadora. Sale a internet solo para pedirles a Wikipedia y a Pleiades
  el resumen de la ficha que abrís (queda en caché) y para buscar actualizaciones en GitHub, que se apaga en Ajustes.

## Instalar

Bajá el zip de tu sistema desde la [última versión](https://github.com/bafif/tmap/releases/latest), descomprimilo y
abrí la app: no hace falta instalar nada.

| Sistema | Archivo |
|---|---|
| Linux | `TellMAP-<versión>-linux-x86_64.zip` |
| Windows | `TellMAP-<versión>-windows-x86_64.zip` |
| macOS (Intel y Apple Silicon) | `TellMAP-<versión>-macos-universal.zip` |

La versión de macOS no está notarizada por Apple: la primera vez se abre desde **Configuración del Sistema →
Privacidad y seguridad** ([cómo](docs/es/instalar.md#macos-la-primera-vez)). Después, al abrir y cada hora, la app
avisa si hay una versión nueva y no baja nada hasta que le digas que sí.

Para correrla desde el código hace falta [Godot 4.7](https://godotengine.org/download):

```bash
git clone https://github.com/bafif/tmap.git
godot --path tmap
```

## Cómo se usa

1. **Mové la línea de tiempo**, abajo: un clic elige el año, arrastrar la recorre y la barra espaciadora deja correr
   el tiempo.
2. **Hacé clic en un lugar.** Se abre su ficha a la derecha, con las pestañas «Resumen», «Historia», «Fuentes», «Gente
   y hechos» y «Datos».
3. **Abrí «Fuentes»**: lo escrito ahí y entonces, y lo escrito después sobre ese lugar y esa época, con el enlace para
   leerlo.
4. **Cambiá de modo** con los botones de arriba o las teclas 1 a 5: político, terreno, religión, cultura e idioma.

F1 abre la ayuda con todos los atajos. Con una pantalla táctil, un dedo mueve el mapa y dos acercan o alejan.

## Estado

- **Versión publicada:** la 0.3.5. Lo táctil y los lugares de Pleiades ya están en el código y llegan con la próxima.
- **Linux:** probada con Vulkan y con OpenGL; la prueba automática corre con cada cambio.
- **macOS:** probada en una Mac con Intel. En Apple Silicon, la integración continua la abre y comprueba que dibuje,
  pero todavía no se probó en una de verdad.
- **Windows:** el ejecutable pasa la prueba completa con wine, pero todavía no se probó en un Windows de verdad.
- **Pantallas táctiles:** la prueba automática cubre los gestos; falta probarlas en una pantalla de verdad.
- **La enciclopedia:** el antiguo Egipto, la Europa medieval, Tierra Santa, la Argentina, los pueblos originarios de
  América y su colonización, la época contemporánea y los celtas, y regiones con su población estimada sobre casi toda
  la tierra firme. Lo cubierto y lo que falta está en
  [la cobertura](docs/es/cobertura.md).
- **Lo que sigue:** personas de Wikidata y grillas de población, migraciones y rutas animadas, una vista 3D y una
  versión para el navegador. El detalle está en [el progreso](PROGRESO.md).

## Más documentación

- [Instalar](docs/es/instalar.md): cada sistema, la primera vez en macOS, el motor de dibujo y cómo correrla desde el
  código.
- [Actualizaciones](docs/es/actualizaciones.md): qué se actualiza solo, cómo se publica y cómo se prueba.
- [La enciclopedia](docs/es/enciclopedia.md): qué trae, cómo se completa, el editor y las reglas editoriales.
- [Esquema de fichas](data/enciclopedia/ESQUEMA.md): el formato de las fuentes, personas, hechos, lugares y regiones.
- [Cobertura](docs/es/cobertura.md): qué regiones, épocas y datos están cubiertos, generado a partir de los datos.
- [Datos y licencias](docs/es/datos.md): de dónde sale cada dato, cómo se procesa y bajo qué licencia.
- [Plan](docs/es/plan.md): cómo está hecho el mapa, las decisiones técnicas y la hoja de ruta.
- [Almacenamiento y descargas](docs/es/almacenamiento.md): cuánto pesa cada cosa y cómo va a bajar la app lo masivo.
- [Progreso](PROGRESO.md): lo que falta y los hitos de cada versión.
- [Cómo trabajar en TellMAP](docs/es/contribuir.md): convenciones, pruebas y [el puente](tools/godot/README.md) para
  manejar la app desde la terminal.
- [Pipeline de datos](tools/pipeline/README.md): cómo se generan el mapa y las fronteras.

## Autor

Lo hace **Bautista D. Fiori** ([LinkedIn](https://www.linkedin.com/in/b-d-fiori/) · [GitHub](https://github.com/bafif)).
Si querés usarlo para enseñar, sumar fuentes de tu especialidad o ayudar con el código, escribime.

## Licencia

El código es [AGPL-3.0-or-later](LICENSE): podés usarlo, modificarlo y compartirlo; si ofrecés una versión modificada
por red, tenés que ofrecer también su código. La enciclopedia propia es CC BY-SA 4.0, y los demás datos conservan sus
licencias ([Datos y licencias](docs/es/datos.md)): Cliopatria (CC BY 4.0), Natural Earth y NASA (dominio público),
Wikipedia (CC BY-SA 4.0), Our World in Data (CC BY 4.0), Pleiades (CC BY 3.0) y las tipografías Cinzel y EB Garamond
(SIL Open Font License).
