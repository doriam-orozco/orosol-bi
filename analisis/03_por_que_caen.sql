-- ============================================================
-- 03 · ¿POR QUÉ caen esas categorías?
-- Tres hipótesis: menos demanda / menor precio / no hay stock.
-- Esta consulta las separa.
-- ============================================================
SELECT p.categoria,
       c.anio,
       SUM(v.unidades_solicitadas)                      AS pedidas,
       SUM(v.unidades)                                  AS despachadas,
       ROUND(100.0 * SUM(v.unidades) 
                   / SUM(v.unidades_solicitadas), 1)    AS fill_rate_pct,
       ROUND(SUM(v.venta_neta) / SUM(v.unidades), 2)    AS precio_promedio
FROM fact_ventas v
JOIN dim_calendario c ON c.fecha = v.fecha
JOIN dim_producto   p ON p.id_producto = v.id_producto
WHERE EXTRACT(DOY FROM v.fecha) <= 194
GROUP BY p.categoria, c.anio
ORDER BY p.categoria, c.anio;