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

### 3. La caída se concentra en dos categorías

Mientras Plomería (+4.2%) y Material Eléctrico (+0.8%) crecen, dos categorías se
hunden:

| Categoría | Δ 2025→2026 | Peso en la venta |
|---|---|---|
| Herramienta Eléctrica | −4.1% | 61% |
| Seguridad Industrial | −6.7% | 3% |

Que unas crezcan y otras caigan descarta una explicación macroeconómica.

### 4. La causa es demanda, no precio ni desabasto

Se probaron tres hipótesis con una sola consulta:

- **¿Precio?** No. Los precios *subieron* en ambas categorías.
- **¿Quiebres de stock?** No. El fill rate es equivalente en categorías que caen
  (97.1%) y que crecen (97.8%).
- **¿Demanda?** **Sí.** Las unidades solicitadas por los clientes caen: Seguridad
  Industrial −11.7% y Herramienta Eléctrica −4.1%.

**Los clientes no dejaron de recibir: dejaron de pedir.**

Seguridad Industrial además lleva dos años consecutivos cayendo
(13,468 → 12,344 → 10,900 unidades), lo que descarta un bache puntual.

### 5. Alerta transversal: el servicio se está degradando

Al margen del estancamiento, el fill rate cayó de ~99% (2023) a ~97.5% (2026) en
**todas** las categorías. Es un problema distinto, transversal, y merece
investigación propia.

---

*Siguiente pregunta abierta: ¿la demanda cayó en toda la categoría, o se desplomó
en un grupo específico de SKUs? La respuesta cambia por completo el diagnóstico.*