# Cobertura de la enciclopedia

[English](../en/coverage.md)

> Este archivo lo genera `tools/enciclopedia/cobertura.py` a partir de los paquetes, de la asignación de población (`tools/enciclopedia/poblacion_regiones.json`) y de los datos del mapa; no se edita a mano. `python3 tools/enciclopedia/cobertura.py` lo rehace y `validar.py` avisa cuando quedó viejo.

## En números

- **Regiones:** 107 (81 de primer nivel) en 42 paquetes.
- **Tierra firme dentro de alguna región:** 99,6 % de los 135,4 millones de km² del mapa (sin la Antártida), medido con las 58 076 unidades del mapa.
- **Población:** 64 regiones tienen serie propia y 43 se cuentan dentro de otra; 26 tienen además estimaciones curadas de especialistas.
- **Capas:** 105 regiones con eras y 73 con religiones, culturas o idiomas.
- **Elementos:** 2733 fuentes (255 sin lugar de escritura), 2768 personas, 3008 hechos y 942 lugares.

## Población: qué parte del mundo cubre cada época

La población mundial y la de cada país salen de Our World in Data (actualización del 2024-07-15): HYDE 3.3 hasta 1799, Gapminder v7 de 1800 a 1949 y la ONU (World Population Prospects 2024) desde 1950, siempre en las fronteras actuales. «Con serie» es la parte de la población mundial que vive en países asignados a alguna región. «Con estimación curada» es la parte que vive en regiones que, a menos de cien años de esa fecha, tienen además una estimación publicada por especialistas para esa región (Russell, Urlanis, Butzer, DellaPergola…); el resto es solo el modelo por país.

| Año | Población mundial | Con serie | Con estimación curada |
|---|---|---|---|
| 10000 a. C. | 4,5 millones | 99,9 % | 0,0 % |
| 5000 a. C. | 19,2 millones | 99,7 % | 0,0 % |
| 3000 a. C. | 44,6 millones | 99,6 % | 2,2 % |
| 1000 a. C. | 110,5 millones | 99,5 % | 0,0 % |
| 1 | 232,3 millones | 99,6 % | 35,2 % |
| 500 | 253,4 millones | 99,6 % | 5,7 % |
| 1000 | 323,5 millones | 99,7 % | 9,3 % |
| 1300 | 456,2 millones | 99,6 % | 16,2 % |
| 1500 | 503,1 millones | 99,6 % | 13,7 % |
| 1700 | 595,5 millones | 99,5 % | 0,1 % |
| 1800 | 983,1 millones | 99,7 % | 0,0 % |
| 1900 | 1,63 mil millones | 99,8 % | 0,0 % |
| 1950 | 2,49 mil millones | 100,0 % | 0,1 % |
| 2000 | 6,17 mil millones | 100,0 % | 0,2 % |
| 2023 | 8,09 mil millones | 100,0 % | 0,2 % |

Antes del año 1, HYDE extrapola con modelos de densidad y uso del suelo: las cifras son órdenes de magnitud, no recuentos. En las islas que se poblaron tarde (Islandia, Madagascar, el Caribe, Nueva Zelanda) se omiten los años anteriores al poblamiento.

## Regiones

Eras: cantidad y período. Población: estimaciones curadas y países que suma la serie (códigos ISO). Capas: entradas de religión · cultura · idioma. Elementos: fuentes · hechos · lugares que nombran la región.

| Región | Paquete | Eras | Población | Capas | Elementos |
|---|---|---|---|---|---|
| Amazonía brasileña (en Brasil) | areas-culturales-de-america | 9 (11000 a. C. a hoy) | sin serie propia; cuenta en Brasil | 8 · 7 · 10 | 0 · 15 · 5 |
| Bosques del noreste (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 7 (14000 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 11 · 17 · 11 | 0 · 91 · 27 |
| California indígena (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 6 (11000 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 5 · 8 · 7 | 0 · 9 · 3 |
| Costa noroeste (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 5 (11800 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 5 · 7 · 9 | 0 · 13 · 3 |
| Gran Cuenca (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 7 (12300 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 7 · 8 · 7 | 0 · 2 · 1 |
| Grandes Llanuras (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 7 (13500 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 7 · 13 · 8 | 0 · 23 · 8 |
| Meseta del Columbia (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 6 (14000 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 5 · 6 · 7 | 0 · 2 · 1 |
| Subártico norteamericano (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 6 (12000 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 7 · 8 · 7 | 0 · 4 · 4 |
| Sudeste norteamericano (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 8 (12550 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 8 · 14 · 11 | 0 · 34 · 15 |
| Suroeste norteamericano (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 10 (21000 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 5 · 13 · 11 | 0 · 27 · 15 |
| Área maya (en Mesoamérica) | areas-culturales-de-america | 8 (11000 a. C. a hoy) | curada: Canuto et al. (750–750); sin serie propia; cuenta en Mesoamérica | 7 · 8 · 7 | 0 · 56 · 37 |
| Ártico norteamericano (en Norteamérica (Estados Unidos y Canadá)) | areas-culturales-de-america | 6 (11000 a. C. a hoy) | curada: Ubelaker (1500–1500); sin serie propia; cuenta en Norteamérica (Estados Unidos y Canadá) | 6 · 9 · 10 | 0 · 18 · 4 |
| Alemania y los Países Bajos | edad-media | 11 (5500 a. C. a hoy) | curada: Urlanis (1000–1500); por país: DEU, AUT, NLD, BEL, CHE, LUX, LIE | 9 · 15 · 12 | 151 · 159 · 35 |
| Balcanes | edad-media | 10 (6500 a. C. a hoy) | por país: SRB, HRV, BIH, MNE, MKD, ALB, BGR, SVN, OWID_KOS | 9 · 11 · 12 | 43 · 32 · 4 |
| Bohemia y Moravia | edad-media | 12 (5500 a. C. a hoy) | por país: CZE | 8 · 12 · 8 | 26 · 26 · 4 |
| Britania | edad-media | 11 (5500 a. C. a hoy) | curada: Alcock, Harper, Urlanis (150–1500); por país: GBR, IMN, GGY, JEY | 8 · 16 · 14 | 269 · 211 · 56 |
| Cerdeña y Córcega | edad-media | 7 (1800 a. C. a hoy) | sin serie propia; cuenta en Italia | 4 · 7 · 6 | 0 · 1 · 0 |
| Escandinavia | edad-media | 6 (793 a hoy) | curada: Urlanis (1000–1500); por país: SWE, NOR, DNK, FRO, SJM | 4 · 2 · 4 | 31 · 38 · 9 |
| Estepa póntica | edad-media | 12 (3300 a. C. a hoy) | sin serie propia; cuenta en Rus | 8 · 8 · 5 | 21 · 17 · 0 |
| Finlandia | edad-media | 5 (1150 a hoy) | por país: FIN | 5 · 2 · 4 | 2 · 2 · 1 |
| Francia | edad-media | 12 (5800 a. C. a hoy) | curada: Frier, Harper, Russell (14–1450); por país: FRA, MCO | 10 · 19 · 17 | 268 · 249 · 52 |
| Hungría | edad-media | 12 (6000 a. C. a hoy) | curada: Russell (500–1450); por país: HUN, SVK | 16 · 17 · 15 | 19 · 27 · 6 |
| Irlanda | edad-media | 9 (5500 a. C. a hoy) | curada: Urlanis (1000–1500); por país: IRL | 5 · 8 · 10 | 124 · 52 · 21 |
| Islandia | edad-media | 6 (410 a hoy) | curada: Censo de Islandia de 1703 (1703–1703); por país: ISL | 3 · 2 · 2 | 8 · 6 · 2 |
| Península ibérica | edad-media | 12 (5600 a. C. a hoy) | curada: Frier, Harper, Russell (14–1450); por país: ESP, PRT, AND, GIB | 15 · 21 · 22 | 178 · 190 · 49 |
| Polonia | edad-media | 11 (5500 a. C. a hoy) | curada: Russell (1000–1450); por país: POL | 3 · 9 · 6 | 20 · 29 · 5 |
| Prusia, Lituania y Livonia | edad-media | 6 (1200 a hoy) | por país: EST, LVA, LTU | 5 · 2 · 5 | 4 · 10 · 2 |
| Rus | edad-media | 6 (862 a hoy) | curada: Russell (1000–1450); por país: RUS, UKR, BLR | 7 · 6 · 9 | 35 · 41 · 5 |
| Sicilia y Malta | edad-media | 10 (241 a. C. a hoy) | sin serie propia; cuenta en Italia | 9 · 9 · 8 | 4 · 5 · 1 |
| Valaquia y Moldavia | edad-media | 8 (6000 a. C. a hoy) | por país: ROU, MDA | 8 · 13 · 12 | 6 · 8 · 0 |
| Alto Egipto (en Egipto) | egipto | — | sin serie propia; cuenta en Egipto | — · — · — | 0 · 2 · 1 |
| Bajo Egipto (en Egipto) | egipto | — | sin serie propia; cuenta en Egipto | — · — · — | 1 · 13 · 0 |
| Egipto | egipto | 21 (5300 a. C. a 2011) | curada: Butzer (3000 a. C.–150 a. C.); por país: EGY | 9 · 9 · 6 | 94 · 53 · 15 |
| Nubia | egipto | 8 (2970 a. C. a 1821) | sin serie propia; cuenta en Sudán y Sudán del Sur | 10 · 8 · 10 | 1 · 3 · 0 |
| Anatolia | mundo | 9 (1760 a. C. a hoy) | curada: Frier, Harper (14–164); por país: TUR | 10 · 7 · 8 | 97 · 64 · 11 |
| Andes centrales | mundo | 8 (3000 a. C. a 2000) | por país: PER, BOL | 7 · 10 · 9 | 234 · 201 · 60 |
| China (cuencas del Amarillo y el Yangtsé) | mundo | 12 (1760 a. C. a hoy) | curada: Hanshu, Sima Biao (2–140); por país: CHN, HKG, MAC | 8 · 2 · 4 | 11 · 23 · 4 |
| Grecia | mundo | 10 (1760 a. C. a 2000) | por país: GRC | 3 · 2 · 3 | 52 · 38 · 6 |
| India (cuencas del Indo y el Ganges) | mundo | 9 (3300 a. C. a hoy) | por país: IND, PAK, BGD, NPL, BTN | 5 · 3 · 4 | 22 · 19 · 4 |
| Italia | mundo | 11 (6000 a. C. a hoy) | curada: Frier, Harper, Russell, Scheidel (14–1450); por país: ITA, SMR, VAT, MLT | 4 · 10 · 15 | 135 · 111 · 22 |
| Levante | mundo | 11 (3500 a. C. a hoy) | suma de sus hijas: ISR, PSE, LBN, SYR, JOR | 9 · 5 · 6 | 24 · 164 · 57 |
| Mesoamérica | mundo | 7 (1760 a. C. a hoy) | por país: MEX, GTM, BLZ, SLV | 6 · 15 · 10 | 263 · 215 · 94 |
| Mesopotamia | mundo | 20 (4000 a. C. a hoy) | por país: IRQ | 4 · 5 · 5 | 43 · 43 · 6 |
| Persia (meseta iraní) | mundo | 9 (2700 a. C. a 2000) | por país: IRN | 4 · 2 · 8 | 36 · 35 · 3 |
| Río de la Plata | mundo | 7 (10000 a. C. a hoy) | por país: ARG, URY, PRY | 6 · 12 · 6 | 421 · 584 · 94 |
| Armórica (Bretaña) (en Francia) | mundo-celta | 7 (5000 a. C. a hoy) | sin serie propia; cuenta en Francia | 3 · 11 · 10 | 9 · 15 · 2 |
| Caledonia (en Britania) | mundo-celta | 7 (4000 a. C. a hoy) | sin serie propia; cuenta en Britania | 6 · 10 · 11 | 4 · 19 · 6 |
| Celtiberia (en Península ibérica) | mundo-celta | 9 (5500 a. C. a hoy) | sin serie propia; cuenta en Península ibérica | 10 · 8 · 9 | 14 · 35 · 8 |
| Galacia (en Anatolia) | mundo-celta | 8 (1650 a. C. a hoy) | sin serie propia; cuenta en Anatolia | 9 · 7 · 7 | 11 · 20 · 5 |
| Galecia (Gallaecia) (en Península ibérica) | mundo-celta | 9 (4800 a. C. a hoy) | sin serie propia; cuenta en Península ibérica | 6 · 10 · 10 | 7 · 16 · 7 |
| Galia Cisalpina (en Italia) | mundo-celta | 10 (5500 a. C. a hoy) | sin serie propia; cuenta en Italia | 7 · 13 · 12 | 1 · 24 · 1 |
| Nórico (en Alemania y los Países Bajos) | mundo-celta | 8 (5500 a. C. a hoy) | sin serie propia; cuenta en Alemania y los Países Bajos | 7 · 11 · 10 | 1 · 10 · 3 |
| Afganistán | regiones-del-mundo | 7 (550 a. C. a hoy) | por país: AFG | — · — · — | 3 · 6 · 0 |
| Amazonía andina (oriente peruano y boliviano) | regiones-del-mundo | 5 (1682 a hoy) | sin serie propia; cuenta en Andes centrales | 6 · 7 · 9 | 27 · 44 · 6 |
| Aridoamérica (norte de México) | regiones-del-mundo | 4 (1546 a hoy) | sin serie propia; cuenta en Mesoamérica | 5 · 8 · 6 | 23 · 32 · 4 |
| Asia central | regiones-del-mundo | 8 (550 a. C. a hoy) | por país: KAZ, UZB, TKM, KGZ, TJK | 7 · 4 · 4 | 2 · 6 · 1 |
| Australia | regiones-del-mundo | 3 (1788 a hoy) | por país: AUS | — · — · — | 0 · 2 · 0 |
| Brasil | regiones-del-mundo | 4 (1500 a hoy) | por país: BRA | 13 · 15 · 13 | 121 · 138 · 29 |
| Caribe | regiones-del-mundo | 5 (1492 a hoy) | por país: CUB, HTI, DOM, JAM, PRI, BHS, TTO, BRB, ATG, DMA, GRD, KNA, LCA, VCT, ABW, CUW, VIR, VGB, CYM, TCA, AIA, MSR, SXM, MAF, BLM, BES, GLP, MTQ | 14 · 21 · 23 | 146 · 117 · 29 |
| Centroamérica (de Honduras a Panamá) | regiones-del-mundo | 4 (1502 a hoy) | por país: HND, NIC, CRI, PAN | 7 · 10 · 8 | 25 · 40 · 8 |
| Chile | regiones-del-mundo | 5 (7000 a. C. a hoy) | por país: CHL | 12 · 14 · 12 | 75 · 115 · 19 |
| China meridional | regiones-del-mundo | 7 (214 a. C. a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 0 · 3 · 0 |
| Corea | regiones-del-mundo | 7 (57 a. C. a hoy) | por país: KOR, PRK | — · — · — | 3 · 2 · 0 |
| Cáucaso | regiones-del-mundo | 7 (300 a. C. a hoy) | por país: GEO, AZE | — · — · — | 0 · 1 · 0 |
| Etiopía y el Cuerno de África | regiones-del-mundo | 6 (980 a. C. a hoy) | por país: ETH, ERI, DJI, SOM | — · — · — | 0 · 2 · 0 |
| Gran Chaco | regiones-del-mundo | 4 (1884 a hoy) | sin serie propia; cuenta en Río de la Plata | 8 · 7 · 7 | 78 · 22 · 2 |
| Groenlandia | regiones-del-mundo | 5 (2500 a. C. a hoy) | por país: GRL | 8 · 4 · 5 | 20 · 23 · 6 |
| Insulindia (sudeste asiático insular) | regiones-del-mundo | 5 (650 a hoy) | por país: IDN, MYS, SGP, BRN, PHL, TLS | — · — · — | 3 · 5 · 0 |
| Japón | regiones-del-mundo | 8 (14000 a. C. a hoy) | por país: JPN | — · — · — | 9 · 5 · 1 |
| Lejano Oriente ruso | regiones-del-mundo | 4 (1632 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 3 · 3 · 0 |
| Madagascar y las islas del Índico | regiones-del-mundo | 4 (500 a hoy) | por país: MDG, COM, MUS, SYC, REU, MYT | — · — · — | 0 · 0 · 0 |
| Manchuria | regiones-del-mundo | 6 (37 a. C. a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 1 · 3 · 0 |
| Melanesia | regiones-del-mundo | 4 (1600 a. C. a hoy) | por país: PNG, SLB, VUT, NCL, FJI | — · — · — | 0 · 0 · 0 |
| Micronesia | regiones-del-mundo | 4 (1500 a. C. a hoy) | por país: FSM, PLW, GUM, MNP, MHL, NRU, KIR | — · — · — | 0 · 1 · 0 |
| Mongolia | regiones-del-mundo | 8 (209 a. C. a hoy) | por país: MNG | — · — · — | 0 · 0 · 0 |
| Noreste de la India | regiones-del-mundo | 4 (350 a hoy) | sin serie propia; cuenta en India (cuencas del Indo y el Ganges) | — · — · — | 1 · 1 · 0 |
| Noroeste argentino y Cuyo | regiones-del-mundo | 4 (1480 a hoy) | sin serie propia; cuenta en Río de la Plata | 8 · 7 · 6 | 151 · 142 · 21 |
| Norte de Rusia | regiones-del-mundo | 5 (1100 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 1 · 1 · 0 |
| Norte de Sudamérica | regiones-del-mundo | 5 (3800 a. C. a hoy) | por país: COL, VEN, ECU, GUY, SUR, GUF | 10 · 17 · 13 | 80 · 151 · 45 |
| Norteamérica (Estados Unidos y Canadá) | regiones-del-mundo | 5 (800 a hoy) | por país: USA, CAN, BMU, SPM | 21 · 21 · 15 | 273 · 363 · 104 |
| Nueva Zelanda (Aotearoa) | regiones-del-mundo | 4 (1250 a hoy) | por país: NZL | — · — · — | 0 · 1 · 0 |
| Paraguay oriental | regiones-del-mundo | 5 (1537 a hoy) | sin serie propia; cuenta en Río de la Plata | 8 · 9 · 6 | 49 · 60 · 1 |
| Patagonia argentina | regiones-del-mundo | 3 (1520 a hoy) | sin serie propia; cuenta en Río de la Plata | 8 · 8 · 10 | 125 · 57 · 13 |
| Polinesia | regiones-del-mundo | 4 (900 a. C. a hoy) | por país: WSM, ASM, TON, NIU, WLF, TKL, COK, PYF, TUV | — · — · — | 8 · 12 · 4 |
| Sahara (norte) | regiones-del-mundo | 4 (9000 a. C. a hoy) | sin serie propia; cuenta en Magreb | — · — · — | 0 · 0 · 0 |
| Siberia | regiones-del-mundo | 4 (1207 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 7 · 6 · 0 |
| Sri Lanka | regiones-del-mundo | 5 (377 a. C. a hoy) | por país: LKA, MDV | — · — · — | 0 · 0 · 0 |
| Sudeste asiático continental | regiones-del-mundo | 6 (500 a. C. a hoy) | por país: MMR, THA, LAO, KHM, VNM | — · — · — | 4 · 8 · 0 |
| Sudán y Sudán del Sur | regiones-del-mundo | 6 (550 a hoy) | por país: SDN, SSD | — · — · — | 0 · 1 · 0 |
| Sur de la India (Decán) | regiones-del-mundo | 6 (300 a. C. a hoy) | sin serie propia; cuenta en India (cuencas del Indo y el Ganges) | — · — · — | 2 · 3 · 0 |
| Taiwán | regiones-del-mundo | 6 (1624 a hoy) | por país: TWN | — · — · — | 0 · 0 · 0 |
| Turquestán oriental (Xinjiang) | regiones-del-mundo | 6 (200 a. C. a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 0 · 0 · 0 |
| Tíbet | regiones-del-mundo | 6 (618 a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 0 · 1 · 0 |
| Volga y Urales | regiones-del-mundo | 6 (700 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 4 · 3 · 0 |
| África austral | regiones-del-mundo | 6 (300 a hoy) | por país: ZAF, NAM, BWA, ZWE, MOZ, ZMB, MWI, LSO, SWZ | — · — · — | 2 · 2 · 1 |
| África central | regiones-del-mundo | 5 (1000 a. C. a hoy) | por país: TCD, CMR, CAF, GNQ, GAB, COG, COD, AGO, STP | — · — · — | 2 · 1 · 0 |
| África occidental | regiones-del-mundo | 7 (1000 a. C. a hoy) | por país: SEN, GMB, GNB, GIN, SLE, LBR, CIV, GHA, TGO, BEN, NGA, BFA, MLI, NER, MRT, CPV | — · — · — | 6 · 2 · 0 |
| África oriental (Grandes Lagos y costa suajili) | regiones-del-mundo | 5 (800 a hoy) | por país: KEN, UGA, TZA, RWA, BDI | — · — · — | 2 · 2 · 0 |
| Arabia | tierra-santa | 7 (1000 a. C. a hoy) | por país: SAU, YEM, OMN, ARE, QAT, BHR, KWT | 6 · 2 · 2 | 35 · 26 · 7 |
| Armenia (meseta armenia) | tierra-santa | 10 (860 a. C. a hoy) | por país: ARM | 5 · 5 · 5 | 0 · 3 · 0 |
| Chipre | tierra-santa | 9 (1100 a. C. a hoy) | por país: CYP | 4 · 3 · 3 | 1 · 4 · 3 |
| Cilicia (en Anatolia) | tierra-santa | 8 (1500 a. C. a hoy) | sin serie propia; cuenta en Anatolia | 6 · 4 · 4 | 0 · 0 · 0 |
| Líbano (en Levante) | tierra-santa | 9 (3000 a. C. a hoy) | por país: LBN | 5 · 3 · 4 | 12 · 21 · 4 |
| Magreb | tierra-santa | 11 (814 a. C. a hoy) | por país: MAR, DZA, TUN, LBY, ESH | 7 · 3 · 5 | 13 · 18 · 11 |
| Siria (en Levante) | tierra-santa | 12 (2500 a. C. a hoy) | por país: SYR | 8 · 4 · 3 | 47 · 37 · 8 |
| Tierra Santa (en Levante) | tierra-santa | 21 (12500 a. C. a hoy) | curada: Censos del Mandato británico de Palestina, DellaPergola, Oficina Central de Estadística de Israel, Village Statistics del gobierno del Mandato (1–2023); por país: ISR, PSE | 17 · 11 · 11 | 135 · 136 · 36 |
| Transjordania (en Levante) | tierra-santa | 11 (1200 a. C. a hoy) | por país: JOR | 4 · 3 · 3 | 6 · 10 · 6 |

## Lo que falta

### Tierra sin región

0,4 % de la tierra firme del mapa queda fuera de toda región. Por entidad política de Cliopatria en 2024 (solo las que suman más de 10 000 km²):

- Sin entidad política en Cliopatria: 172 620 km²
- Reino de Noruega: 61 669 km²
- República Popular China: 39 055 km²
- Irak: 30 631 km²
- Rusia: 22 531 km²
- Estados Unidos: 21 404 km²
- Turquía: 17 524 km²
- Perú: 14 025 km²
- Irán: 12 622 km²
- India: 11 813 km²
- México: 11 483 km²
- Quinta República francesa: 11 061 km²

### Países sin región en la población

Territorios de la tabla de Our World in Data que ninguna región suma (población de 2023):

- Saint Helena (SHN): 5 316
- Falkland Islands (FLK): 3 498

### Regiones sin serie de población propia

Las series por país no se pueden partir: estas regiones no tienen población propia y se cuentan en otra.

- Alto Egipto: Parte de Egipto.
- Amazonía andina (oriente peruano y boliviano): Parte de Perú y Bolivia.
- Amazonía brasileña: Parte de Brasil.
- Aridoamérica (norte de México): Parte de México.
- Armórica (Bretaña): Parte de Francia (Bretaña).
- Bajo Egipto: Parte de Egipto.
- Bosques del noreste: Parte de los Estados Unidos y de Canadá.
- Caledonia: Parte de Britania: las series por país no separan Escocia del Reino Unido.
- California indígena: Parte de los Estados Unidos.
- Celtiberia: Parte de la península ibérica (España).
- Cerdeña y Córcega: Cerdeña se cuenta en Italia y Córcega en Francia.
- China meridional: Parte de China, con Hong Kong y Macao.
- Cilicia: Parte de Turquía (región Anatolia).
- Costa noroeste: Parte de los Estados Unidos y de Canadá.
- Estepa póntica: Su población se cuenta en Ucrania y Rusia (región Rus).
- Galacia: Parte de Anatolia (Turquía).
- Galecia (Gallaecia): Parte de la península ibérica (España y Portugal).
- Galia Cisalpina: Parte de Italia: las series por país no separan el norte.
- Gran Chaco: Se reparte entre Argentina y Paraguay (región Río de la Plata) y Bolivia (región Andes).
- Gran Cuenca: Parte de los Estados Unidos.
- Grandes Llanuras: Parte de los Estados Unidos y de Canadá.
- Lejano Oriente ruso: Parte de Rusia (región Rus).
- Manchuria: Parte de China.
- Meseta del Columbia: Parte de los Estados Unidos y de Canadá.
- Noreste de la India: Parte de la India y de Bangladés.
- Noroeste argentino y Cuyo: Parte de la Argentina.
- Norte de Rusia: Parte de Rusia (región Rus).
- Nubia: Se reparte entre Sudán (región Sudán) y Egipto.
- Nórico: Parte de la región de Alemania y los Países Bajos (Austria).
- Paraguay oriental: Parte de Paraguay.
- Patagonia argentina: Parte de la Argentina.
- Sahara (norte): Su población se cuenta en los países del Magreb.
- Siberia: Parte de Rusia (región Rus).
- Sicilia y Malta: Las series por país no separan Sicilia de Italia.
- Subártico norteamericano: Parte de Canadá y de los Estados Unidos (Alaska).
- Sudeste norteamericano: Parte de los Estados Unidos.
- Sur de la India (Decán): Parte de la India.
- Suroeste norteamericano: Parte de los Estados Unidos.
- Turquestán oriental (Xinjiang): Parte de China.
- Tíbet: Parte de China; Bután y Nepal se cuentan en la India.
- Volga y Urales: Parte de Rusia (región Rus).
- Área maya: Parte de México, Guatemala y Belice.
- Ártico norteamericano: Parte de los Estados Unidos (Alaska) y de Canadá.

### Regiones sin religiones, culturas ni idiomas (34)

Afganistán, Alto Egipto, Australia, Bajo Egipto, China meridional, Corea, Cáucaso, Etiopía y el Cuerno de África, Insulindia (sudeste asiático insular), Japón, Lejano Oriente ruso, Madagascar y las islas del Índico, Manchuria, Melanesia, Micronesia, Mongolia, Noreste de la India, Norte de Rusia, Nueva Zelanda (Aotearoa), Polinesia, Sahara (norte), Siberia, Sri Lanka, Sudeste asiático continental, Sudán y Sudán del Sur, Sur de la India (Decán), Taiwán, Turquestán oriental (Xinjiang), Tíbet, Volga y Urales, África austral, África central, África occidental, África oriental (Grandes Lagos y costa suajili).

### Regiones sin eras (2)

Alto Egipto, Bajo Egipto.

### Límites de los datos de población

- Las series por país usan las fronteras actuales: una región histórica más chica o más grande que sus países (la Rus, Mesoamérica, los Andes) recibe la población de los países enteros, y la nota de cada serie lo dice.
- Entre una estimación curada y la serie por país puede haber un salto: son métodos y territorios distintos, y el gráfico muestra la fuente de cada punto.
- Our World in Data no publica los escenarios bajo y alto de HYDE, así que las series no tienen rango de incertidumbre. Las grillas de HYDE, que permitirían sumar la población dentro de cada polígono, están en el servidor de la Universidad de Utrecht detrás de una verificación anti-bots.
