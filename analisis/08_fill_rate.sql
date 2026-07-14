-- ============================================================
-- 08 · ¿Por qué cae el fill rate?
--
-- Cae de ~99% a ~97.6%, parejo en TODAS las bodegas y categorías.
--
-- Antes de buscar qué se rompió, descartar la explicación aburrida:
-- ¿y si nada se rompió y el negocio simplemente creció contra una
-- capacidad de inventario que no creció con él?
--
-- Si el inventario NO creció al ritmo de la demanda, los quiebres
-- suben sin que nadie haya hecho nada mal.
-- ============================================================

WITH demanda AS (
    SELECT c.anio,
           SUM(v.unidades_solicitadas) AS unidades_pedidas
    FROM fact_ventas v
    JOIN dim_calendario c ON c.fecha = v.fecha
    WHERE EXTRACT(DOY FROM v.fecha) <= 194
    GROUP BY c.anio
),
inventario AS (
    -- Inventario PROMEDIO del período. No se puede sumar el
    -- inventario a través del tiempo (es semiaditivo): el stock de
    -- enero más el de febrero no significa nada. Se promedia.
    SELECT c.anio,
           ROUND(AVG(i.existencia), 1)      AS existencia_promedio,
           ROUND(AVG(i.valor_inventario))   AS valor_promedio_q
    FROM fact_inventario i
    JOIN dim_calendario c ON c.fecha = i.fecha
    WHERE EXTRACT(DOY FROM i.fecha) <= 194
    GROUP BY c.anio
)
SELECT d.anio,
       d.unidades_pedidas,
       ROUND(100.0 * (d.unidades_pedidas - LAG(d.unidades_pedidas) OVER (ORDER BY d.anio))
                   / LAG(d.unidades_pedidas) OVER (ORDER BY d.anio), 1) AS demanda_var_pct,
       i.existencia_promedio,
       ROUND(100.0 * (i.existencia_promedio - LAG(i.existencia_promedio) OVER (ORDER BY d.anio))
                   / LAG(i.existencia_promedio) OVER (ORDER BY d.anio), 1) AS inventario_var_pct
FROM demanda d
JOIN inventario i ON i.anio = d.anio
ORDER BY d.anio;