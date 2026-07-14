-- ============================================================
-- 10 · ¿Está el inventario donde debe estar?
--
-- Contradicción: el inventario está PLANO desde 2024, pero las
-- unidades no servidas siguen subiendo (2,704 → 3,409 → 3,680).
--
-- Hipótesis: el inventario no bajó, se MOVIÓ DE LUGAR. Está
-- sentado en productos muertos mientras falta en los que rotan.
-- El promedio esconde eso.
--
-- Técnica: NTILE + clasificación ABC dinámica.
-- ============================================================

WITH abc AS (
    -- Clasificar los SKUs por su venta en los últimos 12 meses.
    -- NTILE(10) parte el universo en 10 grupos del mismo tamaño,
    -- ordenados por venta. El grupo 1 son los que más venden.
    SELECT v.id_producto,
           SUM(v.venta_neta) AS venta_12m,
           NTILE(10) OVER (ORDER BY SUM(v.venta_neta) DESC) AS decil
    FROM fact_ventas v
    WHERE v.fecha >= '2025-07-13'
    GROUP BY v.id_producto
),
stock_hoy AS (
    -- Foto del inventario al día de hoy
    SELECT i.id_producto,
           SUM(i.existencia)        AS unidades,
           SUM(i.valor_inventario)  AS valor_q
    FROM fact_inventario i
    WHERE i.fecha = '2026-07-13'
    GROUP BY i.id_producto
),
quiebres AS (
    -- ¿Cuánta demanda se perdió por SKU en los últimos 12 meses?
    SELECT v.id_producto,
           SUM(v.unidades_solicitadas - v.unidades) AS unidades_perdidas
    FROM fact_ventas v
    WHERE v.fecha >= '2025-07-13'
    GROUP BY v.id_producto
)
SELECT a.decil,
       COUNT(*)                              AS skus,
       ROUND(SUM(a.venta_12m))               AS venta_12m_q,
       ROUND(SUM(s.valor_q))                 AS inventario_q,
       SUM(q.unidades_perdidas)              AS unidades_perdidas,
       -- La métrica que lo revela todo: cuántos quetzales de
       -- inventario sostienen cada quetzal de venta.
       ROUND(SUM(s.valor_q) / NULLIF(SUM(a.venta_12m), 0), 3) AS q_inventario_por_q_venta
FROM abc a
JOIN stock_hoy s ON s.id_producto = a.id_producto
LEFT JOIN quiebres q ON q.id_producto = a.id_producto
GROUP BY a.decil
ORDER BY a.decil;