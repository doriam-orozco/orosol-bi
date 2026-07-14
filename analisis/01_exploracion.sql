-- ============================================================
-- 01 · EXPLORACIÓN INICIAL
-- Distribuidora Orosol · Torre de control de inventarios
-- ============================================================

-- ¿Cargó todo?
SELECT 'ventas' AS tabla, COUNT(*) FROM fact_ventas
UNION ALL
SELECT 'inventario', COUNT(*) FROM fact_inventario;


-- Venta por año.
-- OJO con 2026: es un año PARCIAL, hasta el 13 de julio.
SELECT c.anio,
       COUNT(*)                 AS lineas,
       ROUND(SUM(v.venta_neta)) AS venta_q
FROM fact_ventas v
JOIN dim_calendario c ON c.fecha = v.fecha
GROUP BY c.anio
ORDER BY c.anio;