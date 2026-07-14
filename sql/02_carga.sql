-- ====================================================================
--  CARGA DE DATOS  |  Ejecutar en psql conectado a supply_chain_bi
--
--  \copy (con barra invertida) es un comando de psql, NO de SQL. Lee el
--  archivo desde TU máquina. El COPY sin barra lo leería desde el servidor.
--  Esa distinción confunde a todo el mundo la primera vez.
--
--  Las dimensiones van primero: los hechos las referencian por llave foránea.
-- ====================================================================

\copy dim_calendario  FROM 'C:/Users/OR0ZCO/OROSOL/data/dim_calendario.csv'  WITH (FORMAT csv, HEADER true)
\copy dim_proveedor   FROM 'C:/Users/OR0ZCO/OROSOL/data/dim_proveedor.csv'   WITH (FORMAT csv, HEADER true)
\copy dim_bodega      FROM 'C:/Users/OR0ZCO/OROSOL/data/dim_bodega.csv'      WITH (FORMAT csv, HEADER true)
\copy dim_cliente     FROM 'C:/Users/OR0ZCO/OROSOL/data/dim_cliente.csv'     WITH (FORMAT csv, HEADER true)
\copy dim_producto    FROM 'C:/Users/OR0ZCO/OROSOL/data/dim_producto.csv'    WITH (FORMAT csv, HEADER true)

\echo 'Dimensiones cargadas. Ahora los hechos (esto tarda 1-3 minutos)...'

\copy fact_ventas     FROM 'C:/Users/OR0ZCO/OROSOL/data/fact_ventas.csv'     WITH (FORMAT csv, HEADER true)
\copy fact_inventario FROM 'C:/Users/OR0ZCO/OROSOL/data/fact_inventario.csv' WITH (FORMAT csv, HEADER true)

\echo 'Carga completa.'