# Cobertura de la enciclopedia

> Este archivo lo genera `tools/enciclopedia/cobertura.py` a partir de los paquetes, de la asignación de población (`tools/enciclopedia/poblacion_regiones.json`) y de los datos del mapa; no se edita a mano. `python3 tools/enciclopedia/cobertura.py` lo rehace y `validar.py` avisa cuando quedó viejo.

## En números

- **Regiones:** 88 (81 de primer nivel) en 5 paquetes.
- **Tierra firme dentro de alguna región:** 99,6 % de los 135,4 millones de km² del mapa (sin la Antártida), medido con las 58 076 unidades del mapa.
- **Población:** 64 regiones tienen serie propia y 24 se cuentan dentro de otra; 14 tienen además estimaciones curadas de especialistas.
- **Capas:** 85 regiones con eras y 39 con religiones, culturas o idiomas.
- **Elementos:** 425 fuentes (42 sin lugar de escritura), 468 personas, 375 hechos y 242 lugares.

## Población: qué parte del mundo cubre cada época

La población mundial y la de cada país salen de Our World in Data (actualización del 2024-07-15): HYDE 3.3 hasta 1799, Gapminder v7 de 1800 a 1949 y la ONU (World Population Prospects 2024) desde 1950, siempre en las fronteras actuales. «Con serie» es la parte de la población mundial que vive en países asignados a alguna región. «Con estimación curada» es la parte que vive en regiones que, a menos de cien años de esa fecha, tienen además una estimación publicada por especialistas para esa región (Russell, Urlanis, Butzer, DellaPergola…); el resto es solo el modelo por país.

| Año | Población mundial | Con serie | Con estimación curada |
|---|---|---|---|
| 10000 a. C. | 4,5 millones | 99,9 % | 0,0 % |
| 5000 a. C. | 19,2 millones | 99,7 % | 0,0 % |
| 3000 a. C. | 44,6 millones | 99,6 % | 2,2 % |
| 1000 a. C. | 110,5 millones | 99,5 % | 0,0 % |
| 1 | 232,3 millones | 99,6 % | 25,2 % |
| 500 | 253,4 millones | 99,6 % | 5,4 % |
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
| Alemania y los Países Bajos | edad-media | 7 (476 a hoy) | curada: Urlanis (1000–1500); por país: DEU, AUT, NLD, BEL, CHE, LUX, LIE | 6 · 5 · 6 | 17 · 23 · 16 |
| Balcanes | edad-media | 7 (600 a hoy) | por país: SRB, HRV, BIH, MNE, MKD, ALB, BGR, SVN, OWID_KOS | 7 · 6 · 7 | 11 · 5 · 4 |
| Bohemia y Moravia | edad-media | 7 (833 a hoy) | por país: CZE | 6 · 3 · 4 | 2 · 4 · 2 |
| Britania | edad-media | 7 (43 a. C. a hoy) | curada: Urlanis (1000–1500); por país: GBR, IMN, GGY, JEY | 7 · 9 · 9 | 14 · 22 · 11 |
| Cerdeña y Córcega | edad-media | 7 (1800 a. C. a hoy) | sin serie propia; cuenta en Italia | 4 · 7 · 6 | 0 · 0 · 0 |
| Escandinavia | edad-media | 6 (793 a hoy) | curada: Urlanis (1000–1500); por país: SWE, NOR, DNK, FRO, SJM | 4 · 2 · 4 | 6 · 9 · 7 |
| Estepa póntica | edad-media | 9 (3300 a. C. a hoy) | sin serie propia; cuenta en Rus | 8 · 7 · 4 | 0 · 0 · 0 |
| Finlandia | edad-media | 5 (1150 a hoy) | por país: FIN | 5 · 2 · 4 | 0 · 0 · 0 |
| Francia | edad-media | 7 (50 a. C. a hoy) | curada: Russell (500–1450); por país: FRA, MCO | 7 · 7 · 7 | 33 · 42 · 21 |
| Hungría | edad-media | 8 (9 a. C. a hoy) | curada: Russell (500–1450); por país: HUN, SVK | 7 · 5 · 6 | 1 · 5 · 3 |
| Irlanda | edad-media | 6 (432 a hoy) | curada: Urlanis (1000–1500); por país: IRL | 5 · 3 · 7 | 0 · 2 · 4 |
| Islandia | edad-media | 5 (870 a hoy) | curada: Censo de Islandia de 1703 (1703–1703); por país: ISL | 3 · 2 · 2 | 2 · 3 · 2 |
| Península ibérica | edad-media | 7 (218 a. C. a hoy) | curada: Russell (500–1450); por país: ESP, PRT, AND, GIB | 10 · 9 · 11 | 35 · 31 · 16 |
| Polonia | edad-media | 8 (960 a hoy) | curada: Russell (1000–1450); por país: POL | 3 · 3 · 3 | 1 · 6 · 4 |
| Prusia, Lituania y Livonia | edad-media | 6 (1200 a hoy) | por país: EST, LVA, LTU | 5 · 2 · 5 | 0 · 4 · 2 |
| Rus | edad-media | 6 (862 a hoy) | curada: Russell (1000–1450); por país: RUS, UKR, BLR | 4 · 3 · 6 | 3 · 6 · 4 |
| Sicilia y Malta | edad-media | 10 (241 a. C. a hoy) | sin serie propia; cuenta en Italia | 9 · 9 · 8 | 3 · 5 · 1 |
| Valaquia y Moldavia | edad-media | 5 (106 a hoy) | por país: ROU, MDA | 3 · 4 · 3 | 0 · 0 · 0 |
| Alto Egipto (en Egipto) | egipto | — | sin serie propia; cuenta en Egipto | — · — · — | 0 · 0 · 0 |
| Bajo Egipto (en Egipto) | egipto | — | sin serie propia; cuenta en Egipto | — · — · — | 0 · 5 · 0 |
| Egipto | egipto | 18 (5300 a. C. a 1952) | curada: Butzer (3000 a. C.–150 a. C.); por país: EGY | 9 · 9 · 6 | 77 · 35 · 14 |
| Nubia | egipto | — | sin serie propia; cuenta en Sudán y Sudán del Sur | — · — · — | 0 · 1 · 0 |
| Anatolia | mundo | 8 (1650 a. C. a 2000) | por país: TUR | 4 · 4 · 4 | 38 · 19 · 5 |
| Andes centrales | mundo | 8 (3000 a. C. a 2000) | por país: PER, BOL | 2 · 2 · 3 | 3 · 5 · 3 |
| China (cuencas del Amarillo y el Yangtsé) | mundo | 8 (1600 a. C. a 1912) | curada: Hanshu, Sima Biao (2–140); por país: CHN, HKG, MAC | 4 · 1 · 3 | 5 · 5 · 3 |
| Grecia | mundo | 8 (1600 a. C. a 2000) | por país: GRC | 2 · 1 · 1 | 14 · 13 · 6 |
| India (cuencas del Indo y el Ganges) | mundo | 8 (3300 a. C. a 1947) | por país: IND, PAK, BGD, NPL, BTN | 5 · 3 · 3 | 4 · 5 · 3 |
| Italia | mundo | 8 (900 a. C. a 2000) | curada: Russell (500–1450); por país: ITA, SMR, VAT, MLT | 2 · 2 · 2 | 41 · 37 · 21 |
| Levante | mundo | 8 (3500 a. C. a 1918) | suma de sus hijas: ISR, PSE, LBN, SYR, JOR | 4 · 3 · 3 | 12 · 109 · 56 |
| Mesoamérica | mundo | 6 (1500 a. C. a 2000) | por país: MEX, GTM, BLZ, SLV | 2 · 2 · 3 | 3 · 5 · 3 |
| Mesopotamia | mundo | 8 (4000 a. C. a 637) | por país: IRQ | 4 · 4 · 4 | 28 · 14 · 6 |
| Persia (meseta iraní) | mundo | 8 (2700 a. C. a 2000) | por país: IRN | 4 · 2 · 4 | 17 · 10 · 3 |
| Río de la Plata | mundo | 7 (10000 a. C. a 2000) | por país: ARG, URY, PRY | 2 · 3 · 2 | 6 · 7 · 3 |
| Afganistán | regiones-del-mundo | 7 (550 a. C. a hoy) | por país: AFG | — · — · — | 0 · 0 · 0 |
| Amazonía andina (oriente peruano y boliviano) | regiones-del-mundo | 5 (1682 a hoy) | sin serie propia; cuenta en Andes centrales | — · — · — | 0 · 0 · 0 |
| Aridoamérica (norte de México) | regiones-del-mundo | 4 (1546 a hoy) | sin serie propia; cuenta en Mesoamérica | — · — · — | 0 · 0 · 0 |
| Asia central | regiones-del-mundo | 8 (550 a. C. a hoy) | por país: KAZ, UZB, TKM, KGZ, TJK | — · — · — | 0 · 0 · 0 |
| Australia | regiones-del-mundo | 3 (1788 a hoy) | por país: AUS | — · — · — | 0 · 0 · 0 |
| Brasil | regiones-del-mundo | 4 (1500 a hoy) | por país: BRA | — · — · — | 0 · 0 · 0 |
| Caribe | regiones-del-mundo | 5 (1492 a hoy) | por país: CUB, HTI, DOM, JAM, PRI, BHS, TTO, BRB, ATG, DMA, GRD, KNA, LCA, VCT, ABW, CUW, VIR, VGB, CYM, TCA, AIA, MSR, SXM, MAF, BLM, BES, GLP, MTQ | — · — · — | 0 · 0 · 0 |
| Centroamérica (de Honduras a Panamá) | regiones-del-mundo | 4 (1502 a hoy) | por país: HND, NIC, CRI, PAN | — · — · — | 0 · 0 · 0 |
| Chile | regiones-del-mundo | 5 (7000 a. C. a hoy) | por país: CHL | — · — · — | 0 · 0 · 0 |
| China meridional | regiones-del-mundo | 7 (214 a. C. a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 0 · 0 · 0 |
| Corea | regiones-del-mundo | 7 (57 a. C. a hoy) | por país: KOR, PRK | — · — · — | 0 · 0 · 0 |
| Cáucaso | regiones-del-mundo | 7 (300 a. C. a hoy) | por país: GEO, AZE | — · — · — | 0 · 0 · 0 |
| Etiopía y el Cuerno de África | regiones-del-mundo | 6 (980 a. C. a hoy) | por país: ETH, ERI, DJI, SOM | — · — · — | 0 · 0 · 0 |
| Gran Chaco | regiones-del-mundo | 4 (1884 a hoy) | sin serie propia; cuenta en Río de la Plata | — · — · — | 0 · 0 · 0 |
| Groenlandia | regiones-del-mundo | 5 (2500 a. C. a hoy) | por país: GRL | — · — · — | 0 · 0 · 0 |
| Insulindia (sudeste asiático insular) | regiones-del-mundo | 5 (650 a hoy) | por país: IDN, MYS, SGP, BRN, PHL, TLS | — · — · — | 0 · 0 · 0 |
| Japón | regiones-del-mundo | 8 (14000 a. C. a hoy) | por país: JPN | — · — · — | 0 · 0 · 0 |
| Lejano Oriente ruso | regiones-del-mundo | 4 (1632 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 0 · 0 · 0 |
| Madagascar y las islas del Índico | regiones-del-mundo | 4 (500 a hoy) | por país: MDG, COM, MUS, SYC, REU, MYT | — · — · — | 0 · 0 · 0 |
| Manchuria | regiones-del-mundo | 6 (37 a. C. a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 0 · 0 · 0 |
| Melanesia | regiones-del-mundo | 4 (1600 a. C. a hoy) | por país: PNG, SLB, VUT, NCL, FJI | — · — · — | 0 · 0 · 0 |
| Micronesia | regiones-del-mundo | 4 (1500 a. C. a hoy) | por país: FSM, PLW, GUM, MNP, MHL, NRU, KIR | — · — · — | 0 · 0 · 0 |
| Mongolia | regiones-del-mundo | 8 (209 a. C. a hoy) | por país: MNG | — · — · — | 0 · 0 · 0 |
| Noreste de la India | regiones-del-mundo | 4 (350 a hoy) | sin serie propia; cuenta en India (cuencas del Indo y el Ganges) | — · — · — | 0 · 0 · 0 |
| Noroeste argentino y Cuyo | regiones-del-mundo | 4 (1480 a hoy) | sin serie propia; cuenta en Río de la Plata | — · — · — | 0 · 0 · 0 |
| Norte de Rusia | regiones-del-mundo | 5 (1100 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 0 · 0 · 0 |
| Norte de Sudamérica | regiones-del-mundo | 5 (3800 a. C. a hoy) | por país: COL, VEN, ECU, GUY, SUR, GUF | — · — · — | 0 · 0 · 0 |
| Norteamérica (Estados Unidos y Canadá) | regiones-del-mundo | 5 (800 a hoy) | por país: USA, CAN, BMU, SPM | — · — · — | 0 · 0 · 0 |
| Nueva Zelanda (Aotearoa) | regiones-del-mundo | 4 (1250 a hoy) | por país: NZL | — · — · — | 0 · 0 · 0 |
| Paraguay oriental | regiones-del-mundo | 5 (1537 a hoy) | sin serie propia; cuenta en Río de la Plata | — · — · — | 0 · 0 · 0 |
| Patagonia argentina | regiones-del-mundo | 3 (1520 a hoy) | sin serie propia; cuenta en Río de la Plata | — · — · — | 0 · 0 · 0 |
| Polinesia | regiones-del-mundo | 4 (900 a. C. a hoy) | por país: WSM, ASM, TON, NIU, WLF, TKL, COK, PYF, TUV | — · — · — | 0 · 0 · 0 |
| Sahara (norte) | regiones-del-mundo | 4 (9000 a. C. a hoy) | sin serie propia; cuenta en Magreb | — · — · — | 0 · 0 · 0 |
| Siberia | regiones-del-mundo | 4 (1207 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 0 · 0 · 0 |
| Sri Lanka | regiones-del-mundo | 5 (377 a. C. a hoy) | por país: LKA, MDV | — · — · — | 0 · 0 · 0 |
| Sudeste asiático continental | regiones-del-mundo | 6 (500 a. C. a hoy) | por país: MMR, THA, LAO, KHM, VNM | — · — · — | 0 · 0 · 0 |
| Sudán y Sudán del Sur | regiones-del-mundo | 6 (550 a hoy) | por país: SDN, SSD | — · — · — | 0 · 0 · 0 |
| Sur de la India (Decán) | regiones-del-mundo | 6 (300 a. C. a hoy) | sin serie propia; cuenta en India (cuencas del Indo y el Ganges) | — · — · — | 0 · 0 · 0 |
| Taiwán | regiones-del-mundo | 6 (1624 a hoy) | por país: TWN | — · — · — | 0 · 0 · 0 |
| Turquestán oriental (Xinjiang) | regiones-del-mundo | 6 (200 a. C. a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 0 · 0 · 0 |
| Tíbet | regiones-del-mundo | 6 (618 a hoy) | sin serie propia; cuenta en China (cuencas del Amarillo y el Yangtsé) | — · — · — | 0 · 0 · 0 |
| Volga y Urales | regiones-del-mundo | 6 (700 a hoy) | sin serie propia; cuenta en Rus | — · — · — | 0 · 0 · 0 |
| África austral | regiones-del-mundo | 6 (300 a hoy) | por país: ZAF, NAM, BWA, ZWE, MOZ, ZMB, MWI, LSO, SWZ | — · — · — | 0 · 0 · 0 |
| África central | regiones-del-mundo | 5 (1000 a. C. a hoy) | por país: TCD, CMR, CAF, GNQ, GAB, COG, COD, AGO, STP | — · — · — | 0 · 0 · 0 |
| África occidental | regiones-del-mundo | 7 (1000 a. C. a hoy) | por país: SEN, GMB, GNB, GIN, SLE, LBR, CIV, GHA, TGO, BEN, NGA, BFA, MLI, NER, MRT, CPV | — · — · — | 0 · 0 · 0 |
| África oriental (Grandes Lagos y costa suajili) | regiones-del-mundo | 5 (800 a hoy) | por país: KEN, UGA, TZA, RWA, BDI | — · — · — | 0 · 0 · 0 |
| Arabia | tierra-santa | 7 (1000 a. C. a hoy) | por país: SAU, YEM, OMN, ARE, QAT, BHR, KWT | 6 · 2 · 2 | 31 · 16 · 7 |
| Armenia (meseta armenia) | tierra-santa | 10 (860 a. C. a hoy) | por país: ARM | 5 · 5 · 5 | 0 · 0 · 0 |
| Chipre | tierra-santa | 9 (1100 a. C. a hoy) | por país: CYP | 4 · 3 · 3 | 1 · 2 · 3 |
| Cilicia (en Anatolia) | tierra-santa | 8 (1500 a. C. a hoy) | sin serie propia; cuenta en Anatolia | 6 · 4 · 4 | 0 · 0 · 0 |
| Líbano (en Levante) | tierra-santa | 8 (3000 a. C. a hoy) | por país: LBN | 5 · 3 · 4 | 7 · 5 · 4 |
| Magreb | tierra-santa | 11 (814 a. C. a hoy) | por país: MAR, DZA, TUN, LBY, ESH | 7 · 3 · 5 | 6 · 5 · 11 |
| Siria (en Levante) | tierra-santa | 11 (2500 a. C. a hoy) | por país: SYR | 8 · 4 · 3 | 43 · 17 · 8 |
| Tierra Santa (en Levante) | tierra-santa | 20 (12500 a. C. a hoy) | curada: Censos del Mandato británico de Palestina, DellaPergola, Oficina Central de Estadística de Israel, Village Statistics del gobierno del Mandato (1–2023); por país: ISR, PSE | 17 · 11 · 11 | 124 · 96 · 35 |
| Transjordania (en Levante) | tierra-santa | 9 (1200 a. C. a hoy) | por país: JOR | 4 · 3 · 3 | 6 · 4 · 6 |

## Lo que falta

### Tierra sin región

0,4 % de la tierra firme del mapa queda fuera de toda región. Por entidad política de Cliopatria en 2024 (solo las que suman más de 10 000 km²):

- Sin entidad política en Cliopatria: 175 065 km²
- Reino de Noruega: 61 669 km²
- República Popular China: 39 055 km²
- Irak: 30 631 km²
- Perú: 23 453 km²
- Rusia: 22 531 km²
- Estados Unidos: 21 404 km²
- Territorios británicos de ultramar: 17 936 km²
- Turquía: 17 524 km²
- México: 16 299 km²
- Irán: 12 622 km²
- India: 11 813 km²
- Quinta República francesa: 11 061 km²

### Países sin región en la población

Territorios de la tabla de Our World in Data que ninguna región suma (población de 2023):

- Saint Helena (SHN): 5 316
- Falkland Islands (FLK): 3 498

### Regiones sin serie de población propia

Las series por país no se pueden partir: estas regiones no tienen población propia y se cuentan en otra.

- Alto Egipto: Parte de Egipto.
- Amazonía andina (oriente peruano y boliviano): Parte de Perú y Bolivia.
- Aridoamérica (norte de México): Parte de México.
- Bajo Egipto: Parte de Egipto.
- Cerdeña y Córcega: Cerdeña se cuenta en Italia y Córcega en Francia.
- China meridional: Parte de China, con Hong Kong y Macao.
- Cilicia: Parte de Turquía (región Anatolia).
- Estepa póntica: Su población se cuenta en Ucrania y Rusia (región Rus).
- Gran Chaco: Se reparte entre Argentina y Paraguay (región Río de la Plata) y Bolivia (región Andes).
- Lejano Oriente ruso: Parte de Rusia (región Rus).
- Manchuria: Parte de China.
- Noreste de la India: Parte de la India y de Bangladés.
- Noroeste argentino y Cuyo: Parte de la Argentina.
- Norte de Rusia: Parte de Rusia (región Rus).
- Nubia: Se reparte entre Sudán (región Sudán) y Egipto.
- Paraguay oriental: Parte de Paraguay.
- Patagonia argentina: Parte de la Argentina.
- Sahara (norte): Su población se cuenta en los países del Magreb.
- Siberia: Parte de Rusia (región Rus).
- Sicilia y Malta: Las series por país no separan Sicilia de Italia.
- Sur de la India (Decán): Parte de la India.
- Turquestán oriental (Xinjiang): Parte de China.
- Tíbet: Parte de China; Bután y Nepal se cuentan en la India.
- Volga y Urales: Parte de Rusia (región Rus).

### Regiones sin religiones, culturas ni idiomas (49)

Afganistán, Alto Egipto, Amazonía andina (oriente peruano y boliviano), Aridoamérica (norte de México), Asia central, Australia, Bajo Egipto, Brasil, Caribe, Centroamérica (de Honduras a Panamá), Chile, China meridional, Corea, Cáucaso, Etiopía y el Cuerno de África, Gran Chaco, Groenlandia, Insulindia (sudeste asiático insular), Japón, Lejano Oriente ruso, Madagascar y las islas del Índico, Manchuria, Melanesia, Micronesia, Mongolia, Noreste de la India, Noroeste argentino y Cuyo, Norte de Rusia, Norte de Sudamérica, Norteamérica (Estados Unidos y Canadá), Nubia, Nueva Zelanda (Aotearoa), Paraguay oriental, Patagonia argentina, Polinesia, Sahara (norte), Siberia, Sri Lanka, Sudeste asiático continental, Sudán y Sudán del Sur, Sur de la India (Decán), Taiwán, Turquestán oriental (Xinjiang), Tíbet, Volga y Urales, África austral, África central, África occidental, África oriental (Grandes Lagos y costa suajili).

### Regiones sin eras (3)

Alto Egipto, Bajo Egipto, Nubia.

### Límites de los datos de población

- Las series por país usan las fronteras actuales: una región histórica más chica o más grande que sus países (la Rus, Mesoamérica, los Andes) recibe la población de los países enteros, y la nota de cada serie lo dice.
- Entre una estimación curada y la serie por país puede haber un salto: son métodos y territorios distintos, y el gráfico muestra la fuente de cada punto.
- Our World in Data no publica los escenarios bajo y alto de HYDE, así que las series no tienen rango de incertidumbre. Las grillas de HYDE, que permitirían sumar la población dentro de cada polígono, están en el servidor de la Universidad de Utrecht detrás de una verificación anti-bots.
