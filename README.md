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

*Se realizo una primer consulta con una comparativa de los datos delos 4 años de datos, pero se estaba realizando mal porque se considero al 2026 con un año completo, alli mostraba una caida del 47% de las ventas pero no era real*
*Se corrigio la consulta ys e compararon datos hasta el 13 de julio, en donde pudimos evidenciar que realmente no era un caida del 47% su no del -2.9%*