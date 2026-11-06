# La enciclopedia

La enciclopedia de TellMAP no se escribe de una vez: se completa por etapas, empezando por donde más se usa, y cada
dato dice de dónde salió.

## Qué hay hoy

- **Fronteras y entidades** de todo el mundo (Cliopatria): cada entidad trae su artículo de Wikipedia y su id de
  Wikidata.
- **Resúmenes de Wikipedia en vivo**, en español primero y en inglés si no hay, guardados en caché por 30 días.
- **Dos paquetes curados** en `data/enciclopedia/paquetes/`:
  - `egipto.json`, el piloto: 4 regiones (con 18 eras para Egipto), 37 fuentes, 18 personas, 24 hechos y 14 lugares.
  - `mundo.json`, una muestra de once regiones (Mesopotamia, Levante, Anatolia, Grecia, Italia, Persia, China, India,
    Mesoamérica, Andes y Río de la Plata).
- El formato está en [ESQUEMA.md](../../data/enciclopedia/ESQUEMA.md) y se valida con
  `python3 tools/enciclopedia/validar.py`.

## ¿Y Grokipedia?

A noviembre de 2026, **Grokipedia no tiene una API oficial**. Lo que hay son clientes no oficiales que leen el sitio
(por ejemplo, paquetes de PyPI o servicios que lo replican) y al menos un sitio con nombre parecido que dice ofrecer una
API y no es de xAI. Además, su contenido estuvo congelado entre marzo y septiembre de 2026 y buena parte se derivó de
Wikipedia.

Por eso TellMAP no depende de Grokipedia: usa Wikipedia (API pública y estable, CC BY-SA), Wikidata (datos
estructurados, CC0) y, para las fichas largas, IA que redacta *a partir de fuentes citadas*. El estilo de ficha de
Grokipedia (un artículo largo, ordenado y legible) es la referencia de forma, no de contenido.

## Cuatro niveles de ficha

| Nivel | Qué es | Estado |
|---|---|---|
| 0 | Datos de Cliopatria: nombre, años y territorio | Todo el mundo |
| 1 | Resumen de Wikipedia en vivo | Todo lo que tenga artículo |
| 2 | Ficha curada: eras, fuentes primarias y secundarias, personas, hechos, población, religión, cultura e idioma | Egipto y la muestra mundial |
| 3 | Ficha extendida «estilo enciclopedia»: historia completa por secciones, redactada con IA desde fuentes citadas y revisada | Fase 0.3 |

## Cómo se va a completar (fase 0.3)

1. **Qué falta lo dice el uso.** La app ya anota (desde la 0.1) en `user://pendientes.json` lo que se abre y no tiene
   ficha curada: la entidad, su Wikidata, el lugar, los años consultados y cuántas veces. No sale de la computadora.
   Esa lista ordena el trabajo: primero lo que más se consulta. (En Linux, `user://` es
   `~/.local/share/godot/app_userdata/TellMAP/`.)
2. **Borrador automático.** Un script toma unas pocas entradas de la lista, junta lo que dicen Wikipedia (el artículo
   completo, por secciones) y Wikidata (fechas, lugares, personas relacionadas) y arma un borrador en el formato del
   esquema.
3. **Redacción con IA, con citas obligatorias.** Un modelo de lenguaje redacta la ficha extendida y propone fuentes
   primarias y estudios, pero cada afirmación tiene que apuntar a una fuente del borrador y cada enlace se comprueba.
   Lo que no se puede respaldar se descarta.
4. **Revisión humana.** El borrador queda en `paquetes/borradores/` marcado como «generado con IA, sin revisar», y
   solo pasa a un paquete cuando alguien lo revisa.
5. **De a poco y a mano.** Se corre en lotes chicos, cuando hace falta, nunca de forma desatendida: así el costo queda
   controlado y la calidad también.

## Reglas editoriales

- **Nada inventado.** Si una fecha es incierta se marca `aprox` y se baja la `confianza`; si un dato no tiene fuente,
  no se carga.
- **Fuentes primarias primero**, en ediciones de dominio público o de acceso abierto cuando existan.
- **Dos coordenadas por texto**: dónde y cuándo se escribió, y de qué lugar y época trata.
- **Estimaciones con su autor y su rango.** Las cifras de autores antiguos son testimonios, no estimaciones.
- **Más de una tradición.** Las eras de cada región usan su propia periodización; la periodización europea aparece
  solo como referencia global y se dice que es orientativa.
- **Licencias claras.** Lo que se deriva de Wikipedia hereda CC BY-SA 4.0 y se atribuye.
