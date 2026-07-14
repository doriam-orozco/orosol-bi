-- ============================================================
-- 07 · ¿Qué proveedor se está degradando?
--
-- El fill rate cae ~99% → 97.6% en las TRES bodegas por igual.
-- No es la bodega (Escuintla falla en entregas, no en stock).
-- Queda el otro sospechoso transversal: quién surte.
--
-- Problema: no tenemos órdenes de compra, así que no podemos
-- medir el lead time real.
-- Proxy: si un proveedor tarda más, sus productos pasan más días
-- en CERO existencia. El quiebre es la sombra del lead time.
--
-- Técnica nueva: WINDOW FUNCTIONS.
-- La pregunta no es "¿quién es malo?" sino "¿quién EMPEORÓ?",
-- y eso exige comparar a cada proveedor contra SÍ MISMO.
-- ============================================================

WITH quiebres_mensuales AS (
    -- % de días-SKU en cero existencia, por proveedor y por mes
    SELECT pr.id_proveedor,
           pr.nombre_proveedor,
           pr.pais,
           c.anio_mes,
           ROUND(100.0 * COUNT(*) FILTER (WHERE i.existencia = 0)
                       / COUNT(*), 2) AS pct_dias_en_cero
    FROM fact_inventario i
    JOIN dim_producto   p  ON p.id_producto  = i.id_producto
    JOIN dim_proveedor  pr ON pr.id_proveedor = p.id_proveedor
    JOIN dim_calendario c  ON c.fecha = i.fecha
    GROUP BY pr.id_proveedor, pr.nombre_proveedor, pr.pais, c.anio_mes
),
comparado AS (
    -- Cada mes contra el mismo proveedor 12 meses antes.
    -- LAG(x, 12) = "el valor de hace 12 filas dentro de este proveedor".
    -- Comparamos año contra año para no confundirnos con estacionalidad.
    SELECT *,
           LAG(pct_dias_en_cero, 12) OVER (
               PARTITION BY id_proveedor
               ORDER BY anio_mes
           ) AS pct_hace_un_anio
    FROM quiebres_mensuales
)
SELECT nombre_proveedor,
       pais,
       ROUND(AVG(pct_hace_un_anio), 1)                      AS antes_pct,
       ROUND(AVG(pct_dias_en_cero), 1)                      AS ahora_pct,
       ROUND(AVG(pct_dias_en_cero - pct_hace_un_anio), 1)   AS deterioro_pp
FROM comparado
WHERE anio_mes >= '2025-07'          -- últimos 12 meses
  AND pct_hace_un_anio IS NOT NULL
GROUP BY nombre_proveedor, pais
ORDER BY deterioro_pp DESC
LIMIT 10;
-- ============================================================
-- ¿Cuánto pesa realmente el Proveedor 25?
-- Encontrar un culpable no sirve si es irrelevante.
-- ============================================================
SELECT pr.nombre_proveedor,
       COUNT(DISTINCT p.id_producto)                  AS skus,
       ROUND(SUM(v.venta_neta))                       AS venta_q,
       ROUND(100.0 * SUM(v.venta_neta) 
             / SUM(SUM(v.venta_neta)) OVER (), 1)     AS pct_de_la_venta
FROM fact_ventas v
JOIN dim_producto  p  ON p.id_producto  = v.id_producto
JOIN dim_proveedor pr ON pr.id_proveedor = p.id_proveedor
GROUP BY pr.nombre_proveedor
ORDER BY venta_q DESC
LIMIT 10;
-- ¿Cuánto pesa el Proveedor 25, en realidad?
SELECT pr.nombre_proveedor,
       pr.pais,
       pr.lead_time_objetivo,
       COUNT(DISTINCT p.id_producto)              AS skus,
       ROUND(SUM(v.venta_neta))                   AS venta_q,
       ROUND(100.0 * SUM(v.venta_neta)
             / (SELECT SUM(venta_neta) FROM fact_ventas), 2) AS pct_venta_total
FROM fact_ventas v
JOIN dim_producto  p  ON p.id_producto  = v.id_producto
JOIN dim_proveedor pr ON pr.id_proveedor = p.id_proveedor
WHERE pr.nombre_proveedor IN ('Proveedor 25', 'Proveedor 29')
GROUP BY pr.nombre_proveedor, pr.pais, pr.lead_time_objetivo;