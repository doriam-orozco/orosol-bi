-- ====================================================================
--  ÍNDICES  |  Ejecutar DESPUÉS de cargar los datos, nunca antes.
--
--  Crear los índices antes de la carga hace que cada INSERT tenga que
--  actualizar el índice. Cargás lento y el índice queda fragmentado.
--  Primero se llenan las tablas, después se indexan. Siempre.
-- ====================================================================

CREATE INDEX idx_ventas_fecha      ON fact_ventas (fecha);
CREATE INDEX idx_ventas_producto   ON fact_ventas (id_producto);
CREATE INDEX idx_ventas_bodega     ON fact_ventas (id_bodega);
CREATE INDEX idx_ventas_cliente    ON fact_ventas (id_cliente);
-- Índice compuesto: sirve para los filtros más frecuentes de tu tablero.
CREATE INDEX idx_ventas_fecha_prod ON fact_ventas (fecha, id_producto);

CREATE INDEX idx_inv_fecha         ON fact_inventario (fecha);
CREATE INDEX idx_inv_producto      ON fact_inventario (id_producto);
-- Índice PARCIAL: solo indexa las filas en quiebre. Ocupa una fracción del
-- espacio y acelera muchísimo las consultas de stockout. Es el tipo de detalle
-- que en una entrevista demuestra que entendés Postgres y no solo SQL.
CREATE INDEX idx_inv_quiebre       ON fact_inventario (fecha, id_producto)
    WHERE existencia = 0;

-- Actualiza las estadísticas del planificador. Sin esto, Postgres puede
-- ignorar tus índices recién creados.
ANALYZE fact_ventas;
ANALYZE fact_inventario;
