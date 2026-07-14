-- ============================================================
-- 02 · ¿DÓNDE está el estancamiento?
--
-- Contexto: el negocio debería crecer ~9% anual. No lo hace.
-- YTD 2024: +5.2% | 2025: +1.1% | 2026: -2.9%
--
-- Estrategia: descomponer el total por cada dimensión hasta que
-- el problema se delate solo. Si una parte cae mucho más que el
-- resto, ahí está el foco.
--
-- Todo comparado YTD (día 1 al 194 de cada año) para que la
-- comparación sea honesta: 2026 es un año parcial.
-- ============================================================


-- ------------------------------------------------------------
-- A) Por BODEGA
-- ------------------------------------------------------------
SELECT b.nombre_bodega,
       c.anio,
       ROUND(SUM(v.venta_neta)) AS venta_q
FROM fact_ventas v
JOIN dim_calendario c ON c.fecha = v.fecha
JOIN dim_bodega     b ON b.id_bodega = v.id_bodega
WHERE EXTRACT(DOY FROM v.fecha) <= 194
GROUP BY b.nombre_bodega, c.anio
ORDER BY b.nombre_bodega, c.anio;


-- ------------------------------------------------------------
-- B) Por CATEGORÍA
-- ------------------------------------------------------------
SELECT p.categoria,
       c.anio,
       ROUND(SUM(v.venta_neta)) AS venta_q
FROM fact_ventas v
JOIN dim_calendario c ON c.fecha = v.fecha
JOIN dim_producto   p ON p.id_producto = v.id_producto
WHERE EXTRACT(DOY FROM v.fecha) <= 194
GROUP BY p.categoria, c.anio
ORDER BY p.categoria, c.anio;


-- ------------------------------------------------------------
-- C) Por CANAL
-- ------------------------------------------------------------
SELECT cl.canal,
       c.anio,
       ROUND(SUM(v.venta_neta)) AS venta_q
FROM fact_ventas v
JOIN dim_calendario c  ON c.fecha = v.fecha
JOIN dim_cliente    cl ON cl.id_cliente = v.id_cliente
WHERE EXTRACT(DOY FROM v.fecha) <= 194
GROUP BY cl.canal, c.anio
ORDER BY cl.canal, c.anio;