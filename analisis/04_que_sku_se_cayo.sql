-- ============================================================
-- 04 · ¿Toda la categoría, o unos pocos SKUs?
--
-- Si la demanda cayó parejo en toda la categoría → es el mercado.
-- Si se desplomó en unos pocos SKUs → algo pasó CON ESOS PRODUCTOS.
-- El diagnóstico y la acción son completamente distintos.
--
-- Técnica nueva: CTE (WITH ... AS). Parte la consulta en pasos
-- con nombre, en vez de anidar subconsultas ilegibles.
-- ============================================================

WITH ventas_por_sku AS (
    -- PASO 1: unidades pedidas por SKU, en 2025 y en 2026 (mismo período)
    SELECT v.id_producto,
           SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2025) AS pedidas_2025,
           SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2026) AS pedidas_2026
    FROM fact_ventas v
    JOIN dim_calendario c ON c.fecha = v.fecha
    WHERE EXTRACT(DOY FROM v.fecha) <= 194
      AND c.anio IN (2025, 2026)
    GROUP BY v.id_producto
)
-- PASO 2: comparar y ordenar por el derrumbe más grande
SELECT p.sku,
       p.nombre_producto,
       p.categoria,
       s.pedidas_2025,
       s.pedidas_2026,
       ROUND(100.0 * (s.pedidas_2026 - s.pedidas_2025) 
                   / NULLIF(s.pedidas_2025, 0), 1) AS variacion_pct
FROM ventas_por_sku s
JOIN dim_producto p ON p.id_producto = s.id_producto
WHERE s.pedidas_2025 >= 20          -- ignorar SKUs marginales: un 2→1 es -50% y no significa nada
ORDER BY variacion_pct ASC          -- los peores primero
LIMIT 30;