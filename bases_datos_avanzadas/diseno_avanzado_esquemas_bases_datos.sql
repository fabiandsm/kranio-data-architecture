-- ==========================================================
-- DISEÑO AVANZADO – ESQUEMA DIMENSIONAL PARA E-COMMERCE
-- ==========================================================

-- Requisitos:
-- - Analizar ventas por producto, cliente, tiempo y ubicación
-- - Segmentar clientes por comportamiento y valor
-- - Calcular métricas: ventas, ticket promedio, margen, etc.


-- ==========================================================
-- 1. DIMENSIONES
-- ==========================================================

-- Tiempo
CREATE TABLE dim_tiempo (
    id INTEGER PRIMARY KEY,
    fecha DATE UNIQUE,
    dia INTEGER,
    mes INTEGER,
    nombre_mes VARCHAR(20),
    trimestre INTEGER,
    año INTEGER,
    dia_semana VARCHAR(10),
    numero_semana INTEGER,
    festivo BOOLEAN,
    temporada VARCHAR(20),
    fin_semana BOOLEAN,
    dia_habil BOOLEAN
);

-- Cliente
CREATE TABLE dim_cliente (
    id INTEGER PRIMARY KEY,
    id_cliente_natural INTEGER,
    nombre VARCHAR(100),
    email VARCHAR(100),
    fecha_registro DATE,
    segmento_valor VARCHAR(20),
    segmento_comportamiento VARCHAR(30),
    edad INTEGER,
    genero VARCHAR(10),
    ciudad VARCHAR(50),
    region VARCHAR(50),
    pais VARCHAR(50),
    frecuencia_compras_mensual DECIMAL(4,1),
    valor_promedio_compra DECIMAL(10,2),
    ultima_compra DATE,
    activo BOOLEAN
);

-- Categoría
CREATE TABLE dim_categoria (
    id INTEGER PRIMARY KEY,
    nombre VARCHAR(50),
    categoria_padre INTEGER REFERENCES dim_categoria(id),
    nivel INTEGER,
    descripcion TEXT
);

-- Marca
CREATE TABLE dim_marca (
    id INTEGER PRIMARY KEY,
    nombre VARCHAR(50),
    pais_origen VARCHAR(50),
    segmento VARCHAR(20),
    reputacion DECIMAL(3,1)
);

-- Producto
CREATE TABLE dim_producto (
    id INTEGER PRIMARY KEY,
    sku VARCHAR(20) UNIQUE,
    nombre VARCHAR(100),
    descripcion TEXT,
    id_categoria INTEGER REFERENCES dim_categoria(id),
    id_marca INTEGER REFERENCES dim_marca(id),
    precio_lista DECIMAL(10,2),
    costo DECIMAL(10,2),
    margen DECIMAL(5,2),
    stock_actual INTEGER,
    stock_minimo INTEGER,
    disponible BOOLEAN,
    fecha_lanzamiento DATE,
    temporada VARCHAR(20)
);

-- Geografía
CREATE TABLE dim_geografia (
    id INTEGER PRIMARY KEY,
    codigo_postal VARCHAR(10),
    ciudad VARCHAR(50),
    provincia VARCHAR(50),
    region VARCHAR(50),
    pais VARCHAR(50),
    zona_horaria VARCHAR(10),
    densidad_poblacional VARCHAR(20)
);

-- Canal
CREATE TABLE dim_canal_adquisicion (
    id INTEGER PRIMARY KEY,
    nombre_canal VARCHAR(50),
    tipo_canal VARCHAR(20),
    costo_adquisicion DECIMAL(8,2),
    roi_promedio DECIMAL(5,2),
    tasa_conversion DECIMAL(5,2),
    activo BOOLEAN
);


-- ==========================================================
-- 2. TABLA DE HECHOS
-- ==========================================================

CREATE TABLE hechos_ventas (
    id_venta INTEGER PRIMARY KEY,
    id_tiempo INTEGER REFERENCES dim_tiempo(id),
    id_cliente INTEGER REFERENCES dim_cliente(id),
    id_producto INTEGER REFERENCES dim_producto(id),
    id_canal INTEGER REFERENCES dim_canal_adquisicion(id),
    id_geografia INTEGER REFERENCES dim_geografia(id),

    cantidad INTEGER,
    precio_unitario DECIMAL(10,2),
    descuento_aplicado DECIMAL(10,2),
    costo_envio DECIMAL(10,2),
    impuestos DECIMAL(10,2),

    total_bruto DECIMAL(10,2)
        GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,

    total_neto DECIMAL(10,2)
        GENERATED ALWAYS AS ((cantidad * precio_unitario) - descuento_aplicado + costo_envio + impuestos) STORED,

    margen_contribucion DECIMAL(10,2)
        GENERATED ALWAYS AS (((cantidad * precio_unitario) - descuento_aplicado - costo_envio) * 0.3) STORED,

    primera_compra BOOLEAN,
    compra_recurrente BOOLEAN,
    cliente_vip BOOLEAN
);


-- ==========================================================
-- 3. MODELO NORMALIZADO (COMPARACIÓN)
-- ==========================================================

CREATE TABLE clientes (
    id SERIAL PRIMARY KEY,
    nombre_cliente VARCHAR(100)
);

CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre_categoria VARCHAR(100)
);

CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    nombre_producto VARCHAR(100),
    id_categoria INT REFERENCES categorias(id)
);

CREATE TABLE ventas (
    id SERIAL PRIMARY KEY,
    id_cliente INT REFERENCES clientes(id),
    id_producto INT REFERENCES productos(id),
    fecha_venta DATE,
    cantidad INT,
    precio_unitario DECIMAL(10,2)
);


-- ==========================================================
-- 4. INSERTS DIMENSIONALES
-- ==========================================================

INSERT INTO dim_tiempo VALUES
(1, '2024-01-10', 10, 1, 'Enero', 1, 2024, 'Miércoles', 2, FALSE, 'Verano', FALSE, TRUE);

INSERT INTO dim_cliente VALUES
(1, 10, 'Juan Pérez', 'juan@test.com', '2023-01-01',
 'Oro', 'Recurrente', 35, 'M', 'Santiago', 'RM', 'Chile',
 2.5, 45000, '2024-01-05', TRUE);

INSERT INTO dim_categoria VALUES
(1, 'Electrónica', NULL, 1, 'Tecnología y dispositivos');

INSERT INTO dim_marca VALUES
(1, 'Sony', 'Japón', 'Premium', 9.2);

INSERT INTO dim_producto VALUES
(1, 'SKU001', 'Televisor 50 Pulgadas', 'Smart TV 4K UHD',
 1, 1, 500000, 300000, 0.40, 20, 5, TRUE, '2023-10-01', 'Verano');

INSERT INTO hechos_ventas (
    id_venta, id_tiempo, id_cliente, id_producto, id_canal, id_geografia,
    cantidad, precio_unitario, descuento_aplicado, costo_envio, impuestos,
    primera_compra, compra_recurrente, cliente_vip
)
VALUES
(1, 1, 1, 1, NULL, NULL, 2, 500000, 20000, 5000, 9500, FALSE, TRUE, TRUE);


-- ==========================================================
-- 5. CONSULTA DIMENSIONAL
-- ==========================================================

SELECT 
    dc.nombre AS cliente,
    dp.nombre AS producto,
    dcat.nombre AS categoria,
    SUM(hv.total_neto) AS total_ventas,
    AVG(hv.total_neto) AS ticket_promedio
FROM hechos_ventas hv
JOIN dim_tiempo dt ON hv.id_tiempo = dt.id
JOIN dim_cliente dc ON hv.id_cliente = dc.id
JOIN dim_producto dp ON hv.id_producto = dp.id
JOIN dim_categoria dcat ON dp.id_categoria = dcat.id
WHERE dt.año = 2024
GROUP BY dc.nombre, dp.nombre, dcat.nombre;


-- ==========================================================
-- 6. VENTAJAS / DESVENTAJAS / RECOMENDACIONES
-- ==========================================================

-- Ventajas del diseño dimensional:
-- 1. Consultas más simples y legibles
-- 2. Performance superior para agregaciones
-- 3. Optimizado para herramientas BI
-- 4. Fácil de entender para analistas de negocio

-- Desventajas:
-- 1. Mayor redundancia de datos
-- 2. Más complejo mantenimiento de dimensiones
-- 3. Menos flexible ante cambios estructurales

-- Recomendaciones técnicas:

CREATE INDEX idx_hechos_tiempo ON hechos_ventas(id_tiempo);
CREATE INDEX idx_hechos_cliente ON hechos_ventas(id_cliente);
CREATE INDEX idx_hechos_producto ON hechos_ventas(id_producto);
CREATE INDEX idx_dimensiones_compuestas 
    ON hechos_ventas(id_tiempo, id_cliente, id_producto);

CREATE MATERIALIZED VIEW mv_ventas_mensuales AS
SELECT dt.año, dt.mes,
       SUM(hv.total_neto) AS ventas_total,
       COUNT(DISTINCT hv.id_cliente) AS clientes_unicos,
       AVG(hv.total_neto) AS ticket_promedio
FROM hechos_ventas hv
JOIN dim_tiempo dt ON hv.id_tiempo = dt.id
GROUP BY dt.año, dt.mes;

ALTER TABLE hechos_ventas ADD CONSTRAINT ck_total_neto_positivo 
    CHECK (total_neto > 0);

ALTER TABLE dim_cliente ADD CONSTRAINT ck_segmento_valido 
    CHECK (segmento_valor IN ('Bronce', 'Plata', 'Oro', 'Platino'));
