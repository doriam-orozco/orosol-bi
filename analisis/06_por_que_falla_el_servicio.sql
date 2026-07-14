-- ============================================================
-- 06 · ¿Por qué se degrada el servicio?
--
-- El fill rate cayó de ~99% (2023) a ~97.5% (2026), parejo en
-- TODAS las categorías. Cuando algo se degrada en todas partes,
-- la causa atraviesa todo: el proveedor o la bodega.
--
-- Paso 0: separar dos métricas que la gente confunde.
--   fill rate = ¿te di todo lo que pediste?  → inventario
--   on-time   = ¿te llegó cuando prometí?    → logística
-- ============================================================

SELECT b.nombre_bodega,
       c.anio,
       -- ¿le dimos al cliente todo lo que pidió?
       ROUND(100.0 * SUM(v.unidades) 
                   / SUM(v.unidades_solicitadas), 1)          AS fill_rate,
       -- ¿llegó a tiempo?
       ROUND(100.0 * COUNT(*) FILTER (WHERE v.fecha_entrega <= v.fecha_prometida)
                   / COUNT(*), 1)                             AS on_time,
       -- OTIF: las dos cosas a la vez. Es la métrica que de verdad
       -- importa: al cliente no le sirve completo pero tarde, ni
       -- puntual pero incompleto.
       ROUND(100.0 * COUNT(*) FILTER (WHERE v.fecha_entrega <= v.fecha_prometida
                                        AND v.entrega_completa)
                   / COUNT(*), 1)                             AS otif
FROM fact_ventas v
JOIN dim_calendario c ON c.fecha = v.fecha
JOIN dim_bodega     b ON b.id_bodega = v.id_bodega
GROUP BY b.nombre_bodega, c.anio
ORDER BY b.nombre_bodega, c.anio;