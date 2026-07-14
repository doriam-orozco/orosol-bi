-- ============================================================
-- 05 · ¿CUÁNDO colapsaron y CUÁNTO capital dejaron atrapado?
-- ============================================================

-- A) La fecha del colapso.
--    Tomamos los SKUs desplomados y vemos su demanda mes a mes.
--    Si hay un mes donde se apagan, hubo un EVENTO.
WITH skus_muertos AS (
    SELECT v.id_producto
    FROM fact_ventas v
    JOIN dim_calendario c ON c.fecha = v.fecha
    WHERE EXTRACT(DOY FROM v.fecha) <= 194
      AND c.anio IN (2025, 2026)
    GROUP BY v.id_producto
    HAVING SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2025) >= 20
       AND SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2026)
           < 0.15 * SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2025)
)
SELECT c.anio_mes,
       SUM(v.unidades_solicitadas) AS unidades_pedidas
FROM fact_ventas v
JOIN dim_calendario c ON c.fecha = v.fecha
WHERE v.id_producto IN (SELECT id_producto FROM skus_muertos)
  AND c.fecha >= '2024-06-01'
GROUP BY c.anio_mes
ORDER BY c.anio_mes;
-- ============================================================
-- B) El capital atrapado.
--    Estos SKUs murieron en abril 2025. ¿Qué pasó con su stock?
-- ============================================================
WITH skus_muertos AS (
    SELECT v.id_producto
    FROM fact_ventas v
    JOIN dim_calendario c ON c.fecha = v.fecha
    WHERE EXTRACT(DOY FROM v.fecha) <= 194
      AND c.anio IN (2025, 2026)
    GROUP BY v.id_producto
    HAVING SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2025) >= 20
       AND SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2026)
           < 0.15 * SUM(v.unidades_solicitadas) FILTER (WHERE c.anio = 2025)
)
SELECT COUNT(DISTINCT i.id_producto)      AS skus_afectados,
       SUM(i.existencia)                  AS unidades_en_bodega,
       ROUND(SUM(i.valor_inventario))     AS capital_atrapado_q
FROM fact_inventario i
WHERE i.fecha = '2026-07-13'                       -- foto de hoy
  AND i.id_producto IN (SELECT id_producto FROM skus_muertos);