-- ============================================================
-- 09 · ¿Cuánto costó reducir el inventario?
--
-- En 2024 el inventario promedio cayó 26.3% y nunca se recuperó.
-- El fill rate cayó de 99% a 97.6% como consecuencia.
--
-- La pregunta NO es "¿fue un error?". Es: ¿el capital liberado
-- vale más que el margen que se dejó de ganar?
--
-- SUPUESTOS (declarados a propósito; cambiarlos cambia el resultado):
--   1) La venta perdida es un TECHO. Asume que el cliente no vuelve.
--      La pérdida real es menor, pero no sabemos cuánto.
--   2) Se pierde el MARGEN, no la venta. El costo no se desembolsó.
--   3) El capital liberado se valora al 12% anual (costo de capital
--      referencial para una empresa mediana en Guatemala).
-- ============================================================

WITH margen AS (
    -- Margen porcentual real del negocio, calculado de los datos
    SELECT SUM(venta_neta - costo_total) / SUM(venta_neta) AS margen_pct
    FROM fact_ventas
),
perdida AS (
    -- Venta NO realizada por quiebres: lo que pidieron y no se dio,
    -- valorado al precio al que se habría vendido.
    SELECT c.anio,
           SUM(v.unidades_solicitadas - v.unidades)                    AS unidades_perdidas,
           ROUND(SUM((v.unidades_solicitadas - v.unidades) 
                     * v.precio_unitario))                             AS venta_perdida_q
    FROM fact_ventas v
    JOIN dim_calendario c ON c.fecha = v.fecha
    WHERE EXTRACT(DOY FROM v.fecha) <= 194
    GROUP BY c.anio
),
capital AS (
    -- Valor promedio del inventario en bodega, por año
    SELECT c.anio,
           ROUND(AVG(i.valor_inventario) * COUNT(DISTINCT i.id_producto) 
                                         * COUNT(DISTINCT i.id_bodega)) AS capital_inmovilizado_q
    FROM fact_inventario i
    JOIN dim_calendario c ON c.fecha = i.fecha
    WHERE EXTRACT(DOY FROM i.fecha) <= 194
    GROUP BY c.anio
)
SELECT p.anio,
       p.unidades_perdidas,
       p.venta_perdida_q,
       ROUND(p.venta_perdida_q * m.margen_pct)           AS margen_perdido_q,
       k.capital_inmovilizado_q,
       -- Cuánto capital se liberó contra 2023 (el año base)
       ROUND(FIRST_VALUE(k.capital_inmovilizado_q) OVER (ORDER BY p.anio)
             - k.capital_inmovilizado_q)                 AS capital_liberado_q,
       -- Lo que ese capital liberado vale al año, al 12%
       ROUND((FIRST_VALUE(k.capital_inmovilizado_q) OVER (ORDER BY p.anio)
              - k.capital_inmovilizado_q) * 0.12)        AS beneficio_capital_q
FROM perdida p
JOIN capital k ON k.anio = p.anio
CROSS JOIN margen m
ORDER BY p.anio;