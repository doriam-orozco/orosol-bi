# Distribuidora Orosol, S.A. — Torre de Control de Inventarios y Servicio

Proyecto de Business Intelligence de punta a punta: generación de datos, modelado
dimensional en PostgreSQL, análisis en SQL y tablero en Power BI.

## El caso de negocio

Distribuidora Orosol es una ferretería mayorista guatemalteca, fundada en 1998, con
tres centros de distribución (Guatemala, Escuintla, Quetzaltenango) y ~900 SKUs en
ocho categorías. Vende a ferreterías minoristas, constructoras y al sector público.

El problema: **la empresa creció más rápido de lo que creció su capacidad de
gestionar inventario.** La gerencia no sabe cuánto capital tiene inmovilizado, qué
proveedores están fallando ni por qué el servicio se siente peor en unas regiones
que en otras. Las decisiones de compra se toman por intuición.

Este proyecto construye la torre de control que responde esas preguntas.

## Estructura

```
orosol/
├── scripts/
│   └── generar_datos.py     Simulador de la operación (genera los CSV)
├── sql/
│   ├── 01_esquema.sql       Esquema estrella
│   ├── 02_carga.sql         Carga de CSV a PostgreSQL
│   └── 03_indices.sql       Índices (después de cargar)
└── data/                    CSV generados (no se versionan)
```

## Cómo reproducirlo

**1. Generar los datos**
```bash
pip install numpy pandas
cd scripts
python generar_datos.py
```
Tarda ~1 minuto y produce ~113 MB de CSV.

**2. Crear la base y el esquema**

En SQL Shell (psql), conectado a `supply_chain_bi`:
```
\i C:/ruta/a/orosol/sql/01_esquema.sql
```

**3. Cargar**

Abrí `sql/02_carga.sql` y **ajustá la variable `ruta`** a tu carpeta `data`.
Después:
```
\i C:/ruta/a/orosol/sql/02_carga.sql
\i C:/ruta/a/orosol/sql/03_indices.sql
```

**4. Verificar**
```sql
SELECT 'fact_ventas' t, COUNT(*) FROM fact_ventas
UNION ALL SELECT 'fact_inventario', COUNT(*) FROM fact_inventario;
```
Debe dar ~490,000 y ~2,193,000.

## El modelo

Esquema estrella con **dos tablas de hechos de granularidad distinta**:

| Tabla | Granularidad | Filas |
|---|---|---|
| `fact_ventas` | una línea de pedido | ~490,000 |
| `fact_inventario` | snapshot diario por SKU y bodega | ~2,193,000 |

Dimensiones: `dim_producto`, `dim_bodega`, `dim_cliente`, `dim_proveedor`,
`dim_calendario`.

Esa diferencia de granularidad es deliberada. El inventario es una medida
**semiaditiva**: se suma entre productos y entre bodegas, pero **no se suma a
través del tiempo** (el inventario de enero + el de febrero no es nada). Manejar eso
correctamente en DAX es el reto central del proyecto.

## Nota sobre los datos

Los datos son **sintéticos, pero no aleatorios**. El script simula la operación día
a día: la demanda consume inventario, el inventario dispara órdenes de compra, los
proveedores entregan con retraso variable, y cuando no alcanza la existencia se
produce un quiebre. Las métricas no están inyectadas — **emergen** de la simulación,
y por eso son internamente consistentes.

Perfil resultante:

- Venta total: ~Q691 millones (2023 – jul 2026)
- Fill rate: 98.5 %
- OTIF: 85.6 %
- 11.3 % de los días-SKU terminan en cero existencia
- 14 % de los SKUs generan el 80 % de la venta

**Advertencia sobre 2026:** es un año **parcial** (hasta el 13 de julio). Cualquier
comparación contra años completos debe hacerse **YTD contra YTD**. La columna
`es_anio_completo` de `dim_calendario` existe para eso.

## Hallazgos

### 1. La caída de 2026 no existe — es un artefacto del año parcial

A primera vista, las ventas de 2026 caen 47% contra 2025. **Es falso.** 2026 solo
tiene datos hasta el 13 de julio. Comparado correctamente (YTD contra YTD, del
1 de enero al 13 de julio de cada año), el panorama real es otro:

| Año | Venta ene–13 jul | vs. año anterior |
|---|---|---|
| 2023 | Q103.1M | — |
| 2024 | Q108.4M | +5.2% |
| 2025 | Q109.6M | +1.1% |
| 2026 | Q106.4M | **−2.9%** |

Un tablero que compare 2026 contra años completos no tiene un bug: **miente**, y
alguien va a tomar una decisión basada en esa mentira.

### 2. El negocio está estancado, y el problema no es geográfico

Las tres bodegas caen (Escuintla −1.4%, Guatemala −1.6%, Quetzaltenango −8.1%).
Cuando todas las partes se mueven en la misma dirección, la causa no está en las
partes.

### 3. La caída se concentra en dos categorías... pero eso es el síntoma

Mientras Plomería (+4.2%) y Material Eléctrico (+0.8%) crecen, dos categorías
caen: Herramienta Eléctrica (−4.1%, el 61% de la venta) y Seguridad Industrial
(−6.7%). Que unas crezcan y otras caigan descarta una explicación macroeconómica.

Un reporte que se detuviera aquí sería plausible, convincente y **equivocado**.

### 4. La causa es demanda, no precio ni desabasto

Tres hipótesis, una sola consulta para discriminarlas:

| Hipótesis | Evidencia | Veredicto |
|---|---|---|
| ¿Bajaron los precios? | Los precios *subieron* en ambas categorías | ❌ |
| ¿Faltó producto? | Fill rate equivalente en categorías que caen (97.1%) y que crecen (97.8%) | ❌ |
| ¿Cayó la demanda? | Unidades solicitadas: Seguridad Industrial −11.7%, Herramienta Eléctrica −4.1% | ✅ |

**Los clientes no dejaron de recibir: dejaron de pedir.**

### 5. Causa raíz: 57 SKUs murieron el 1 de abril de 2025

Bajando al nivel de SKU aparece lo que las categorías escondían. Un grupo de
productos **no cayó gradualmente: se apagó de un mes al otro.**

| Mes | Unidades pedidas |
|---|---|
| 2025-01 | 2,760 |
| 2025-02 | 2,715 |
| 2025-03 | 2,799 |
| **2025-04** | **93** ← −96.7 % |
| 2025-05 | 81 |
| … | … |
| 2026-06 | 68 |

Quince meses después siguen planos. Nada natural se comporta así: una demanda que
se enfría lo hace en curva, no con un interruptor. **Esto es un evento, no una
tendencia** — un cambio regulatorio, una descontinuación, la pérdida de un cliente
mayorista, o la entrada de un competidor.

Y estos SKUs **atraviesan todas las categorías**, incluidas las que crecen. Por eso
el análisis por categoría llevaba a una conclusión falsa: Herramienta Eléctrica y
Seguridad Industrial caían solo porque concentran más de estos productos.

### 6. El costo: Q1.34 millones de capital atrapado

Orosol compró estos productos calibrando a la demanda anterior. La demanda murió.
El inventario no.

| | |
|---|---|
| SKUs muertos | **57** |
| Unidades en bodega | 3,494 |
| **Capital inmovilizado** | **Q 1,337,254** |
| % del inventario total | **~16 %** |

**Uno de cada seis quetzales del inventario de Orosol está en productos que ya nadie
compra.** Ese capital podría estar financiando Plomería, que crece 4% anual.

**Acción recomendada:** liquidación dirigida de los 57 SKUs y revisión de la política
de reposición, que sigue calibrada a una demanda que dejó de existir hace 15 meses.

### 7. El servicio se degradó porque se recortó el inventario

El fill rate cayó de 99.1% (2023) a 97.6% (2026), **parejo en las tres bodegas y
en todas las categorías**. Esa uniformidad es la pista: una causa local no produce
un efecto global.

Primero se descartó la explicación aburrida — que el negocio hubiera crecido contra
una capacidad fija. No fue eso:

| Año | Demanda | Δ | Inventario promedio | Δ |
|---|---|---|---|---|
| 2023 | 148,456 | — | 11.4 | — |
| 2024 | 156,088 | +5.1% | **8.4** | **−26.3%** |
| 2025 | 157,503 | +0.9% | 8.3 | −1.2% |
| 2026 | 153,599 | −2.5% | 8.6 | +3.6% |

La demanda apenas se movió. **El inventario se desplomó 26% en 2024 y nunca se
recuperó.** Menos colchón, más quiebres. Transversal, como el síntoma.

### 8. Y ese recorte está costando dinero

Los datos no dicen si la reducción fue una decisión deliberada (liberar capital de
trabajo) o un recorte a ciegas. Pero sí permiten **ponerle precio**:

| Año | Margen perdido por quiebres | Valor del capital liberado | **Neto** |
|---|---|---|---|
| 2024 | Q 692,307 | Q 413,908 | **−Q 278,399** |
| 2025 | Q 745,006 | Q 450,145 | **−Q 294,861** |
| 2026 * | Q 888,090 | Q 428,498 | **−Q 459,592** |

*\* 2026 es medio año, y ya supera la pérdida de años completos anteriores.*

**Supuestos declarados** (cambiarlos cambia el resultado):
1. La venta perdida es un **techo**: asume que el cliente no vuelve. La pérdida real
   es menor, pero no es observable en los datos.
2. Se pierde el **margen**, no la venta: el costo del producto no se desembolsó.
3. El capital liberado se valora al **12% anual** (costo de capital referencial para
   una empresa mediana en Guatemala).

> **Conclusión: la reducción de inventario de 2024 liberó ~Q3.5M de capital, pero
> cuesta ~Q460k al año en margen perdido. Es una pérdida neta, y se está agravando.**

### 9. Riesgo abierto: un proveedor concentra el 31% de la venta

El **Proveedor 29** (México, 22 SKUs) representa el **31.07%** de la venta total de
Orosol. Hoy funciona bien — y por eso nadie lo mira. Si sube precios, se atrasa o
quiebra, un tercio del negocio se apaga.

Nota metodológica: durante la investigación se detectó que el **Proveedor 25** se
degradó fuertemente (quiebres de 19.1% → 35.6%, +16.5 pp, 4.5× peor que el
siguiente). Señal limpia, narrativa convincente — y **materialmente irrelevante**:
pesa el **1.24%** de la venta. Publicarlo como causa del problema de servicio habría
sido un error caro.

**Encontrar una señal no es encontrar una causa. Siempre hay que preguntar cuánto
pesa.**

### 10. Pendiente: las unidades perdidas siguen creciendo

El inventario está plano desde 2024 (8.4 → 8.3 → 8.6), pero las unidades no servidas
siguen subiendo: **1,340 → 2,704 → 3,409 → 3,680** (y 2026 es medio año). Algo más se
está deteriorando. Hipótesis a probar: la política de reposición sigue calibrada a la
demanda anterior, incluidos los 57 SKUs que murieron en abril de 2025.