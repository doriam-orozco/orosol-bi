-- ====================================================================
--  DISTRIBUIDORA OROSOL, S.A.  |  Esquema estrella
--  Ejecutar conectado a la base supply_chain_bi
-- ====================================================================

DROP TABLE IF EXISTS fact_ventas, fact_inventario CASCADE;
DROP TABLE IF EXISTS dim_producto, dim_bodega, dim_cliente, dim_proveedor, dim_calendario CASCADE;

-- --------------------------------------------------------------------
-- DIMENSIONES
-- --------------------------------------------------------------------
CREATE TABLE dim_calendario (
    fecha             DATE PRIMARY KEY,
    anio              SMALLINT     NOT NULL,
    trimestre         SMALLINT     NOT NULL,
    mes               SMALLINT     NOT NULL,
    nombre_mes        VARCHAR(12)  NOT NULL,
    dia               SMALLINT     NOT NULL,
    dia_semana        SMALLINT     NOT NULL,
    nombre_dia        VARCHAR(12)  NOT NULL,
    es_fin_semana     BOOLEAN      NOT NULL,
    anio_mes          CHAR(7)      NOT NULL,
    es_anio_completo  BOOLEAN      NOT NULL   -- 2026 es parcial: clave para YTD
);

CREATE TABLE dim_proveedor (
    id_proveedor        INT PRIMARY KEY,
    nombre_proveedor    VARCHAR(60) NOT NULL,
    pais                VARCHAR(30) NOT NULL,
    lead_time_objetivo  INT         NOT NULL   -- días PROMETIDOS, no los reales
);

CREATE TABLE dim_bodega (
    id_bodega      INT PRIMARY KEY,
    nombre_bodega  VARCHAR(40) NOT NULL,
    region         VARCHAR(20) NOT NULL,
    tipo           VARCHAR(20) NOT NULL,
    capacidad_m2   INT         NOT NULL
);

CREATE TABLE dim_cliente (
    id_cliente      INT PRIMARY KEY,
    nombre_cliente  VARCHAR(60) NOT NULL,
    canal           VARCHAR(30) NOT NULL,
    segmento        VARCHAR(20) NOT NULL,
    region          VARCHAR(20) NOT NULL
);

CREATE TABLE dim_producto (
    id_producto      INT PRIMARY KEY,
    sku              VARCHAR(15) NOT NULL UNIQUE,
    nombre_producto  VARCHAR(80) NOT NULL,
    categoria        VARCHAR(30) NOT NULL,
    subcategoria     VARCHAR(30) NOT NULL,
    id_proveedor     INT         NOT NULL REFERENCES dim_proveedor(id_proveedor),
    costo_unitario   NUMERIC(12,2) NOT NULL,
    precio_lista     NUMERIC(12,2) NOT NULL,
    unidad_medida    VARCHAR(15) NOT NULL
);

-- --------------------------------------------------------------------
-- HECHOS
-- --------------------------------------------------------------------
-- Granularidad: UNA LÍNEA DE PEDIDO.
-- unidades_solicitadas vs unidades = de aquí sale el fill rate y la demanda perdida.
CREATE TABLE fact_ventas (
    id_venta              BIGINT PRIMARY KEY,
    fecha                 DATE   NOT NULL REFERENCES dim_calendario(fecha),
    id_producto           INT    NOT NULL REFERENCES dim_producto(id_producto),
    id_bodega             INT    NOT NULL REFERENCES dim_bodega(id_bodega),
    id_cliente            INT    NOT NULL REFERENCES dim_cliente(id_cliente),
    unidades              INT    NOT NULL,   -- lo que realmente se despachó
    unidades_solicitadas  INT    NOT NULL,   -- lo que el cliente pidió
    precio_unitario       NUMERIC(12,2) NOT NULL,
    costo_unitario        NUMERIC(12,2) NOT NULL,
    fecha_prometida       DATE   NOT NULL,
    fecha_entrega         DATE   NOT NULL,
    entrega_completa      BOOLEAN NOT NULL,
    venta_neta            NUMERIC(14,2) NOT NULL,
    costo_total           NUMERIC(14,2) NOT NULL
);

-- Granularidad: UN SNAPSHOT DIARIO por SKU y bodega.
-- OJO: granularidad DISTINTA a fact_ventas. Esto no es un descuido, es el
-- corazón del reto de modelado. En Power BI no podrás sumar inventario
-- a través del tiempo (es una medida semiaditiva).
CREATE TABLE fact_inventario (
    fecha              DATE NOT NULL REFERENCES dim_calendario(fecha),
    id_producto        INT  NOT NULL REFERENCES dim_producto(id_producto),
    id_bodega          INT  NOT NULL REFERENCES dim_bodega(id_bodega),
    existencia         INT  NOT NULL,
    en_transito        INT  NOT NULL,
    costo_unitario     NUMERIC(12,2) NOT NULL,
    valor_inventario   NUMERIC(14,2) NOT NULL,
    PRIMARY KEY (fecha, id_producto, id_bodega)
);
