-- =========================
-- 1: DIMENSIONES
-- =========================

CREATE TABLE dim_customer (
    customer_id SERIAL PRIMARY KEY,
    email TEXT,
    registration_date DATE,
    customer_segment TEXT
);

CREATE TABLE dim_product (
    product_id SERIAL PRIMARY KEY,
    sku TEXT,
    name TEXT,
    category TEXT,
    brand TEXT,
    unit_cost DECIMAL(10,2),
    current_price DECIMAL(10,2)
);

CREATE TABLE dim_time (
    date_key INTEGER PRIMARY KEY,
    full_date DATE,
    year INTEGER,
    quarter INTEGER,
    month INTEGER,
    day_of_week INTEGER,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN
);

CREATE TABLE dim_location (
    location_id SERIAL PRIMARY KEY,
    country TEXT,
    region TEXT,
    city TEXT,
    postal_code TEXT,
    timezone TEXT
);
-- =========================
-- 2: TABLA DE HECHOS
-- Grano: una línea de pedido (order_id + product_id)
-- =========================

CREATE TABLE fact_orders (
    order_id BIGINT,
    product_id INTEGER REFERENCES dim_product(product_id),
    customer_id INTEGER REFERENCES dim_customer(customer_id),
    time_id INTEGER REFERENCES dim_time(date_key),
    location_id INTEGER REFERENCES dim_location(location_id),

    -- Métricas del pedido
    quantity_ordered INTEGER,
    unit_price DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    shipping_cost DECIMAL(10,2),
    total_amount DECIMAL(10,2),

    -- Costo al momento de la venta
    cost_amount DECIMAL(10,2),

    -- Atributos del evento
    is_first_purchase BOOLEAN,
    order_channel TEXT,   -- web, mobile, api
    payment_method TEXT,

    PRIMARY KEY (order_id, product_id)
);

-- =========================
-- 3: Vista analítica de productos
-- =========================

CREATE VIEW product_performance AS
SELECT
    dp.name AS product_name,
    dp.category,
    dp.brand,
    SUM(fo.quantity_ordered) AS total_units_sold,
    SUM(fo.total_amount) AS total_revenue,
    AVG(fo.unit_price) AS avg_selling_price,
    COUNT(DISTINCT fo.customer_id) AS unique_customers,
    ROW_NUMBER() OVER (
        PARTITION BY dp.category
        ORDER BY SUM(fo.total_amount) DESC
    ) AS category_rank
FROM fact_orders fo
JOIN dim_product dp ON fo.product_id = dp.product_id
JOIN dim_time dt ON fo.time_id = dt.date_key
WHERE dt.year = 2024
GROUP BY dp.product_id, dp.name, dp.category, dp.brand;

-- =========================
-- 3.1: Vista materializada para dashboards
-- =========================

CREATE MATERIALIZED VIEW executive_dashboard AS
WITH monthly AS (
    SELECT
        dt.year,
        dt.month,
        SUM(fo.total_amount) AS monthly_revenue,
        COUNT(DISTINCT fo.customer_id) AS active_customers,
        COUNT(DISTINCT fo.order_id) AS total_orders,
        AVG(fo.total_amount) AS avg_order_value
    FROM fact_orders fo
    JOIN dim_time dt ON fo.time_id = dt.date_key
    GROUP BY dt.year, dt.month
)
SELECT
    year,
    month,
    monthly_revenue,
    active_customers,
    total_orders,
    avg_order_value,
    (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY year, month)) /
     NULLIF(LAG(monthly_revenue) OVER (ORDER BY year, month), 0) AS growth_rate
FROM monthly
ORDER BY year, month;

-- Índices para acelerar joins y filtros
CREATE INDEX idx_fact_orders_time ON fact_orders(time_id);
CREATE INDEX idx_fact_orders_product ON fact_orders(product_id);
CREATE INDEX idx_fact_orders_customer ON fact_orders(customer_id);

CREATE INDEX idx_dim_time_year_month ON dim_time(year, month);

-- =========================
-- 4: Verificación
-- =========================
''' 
¿Qué índices crearías para optimizar estas consultas?
	Como el patrón de consultas del ejercicio es: joins frecuentes, filtros temporales y agregaciones. Los índices más efectivos serían los siguientes:
	1-	Índices en claves foráneas de la tabla de hechos: ya que la fact es la tabla más grande y se une constantemente con las dimensiones:
		fact_orders(time_id)
		fact_orders(product_id)
		fact_orders(customer_id)
	2-	Índice compuesto en la dimensión tiempo:
		dim_time(year, month)
		Este índice optimiza filtros temporales y agregaciones mensuales usadas tanto en la vista analítica como en la vista materializada.
	3-	Clave primaria compuesta (order_id, product_id): 
		Además de asegurar unicidad, PostgreSQL crea automáticamente un índice que mejora búsquedas y conteos de pedidos.
	Estos índices reducen el número de filas escaneadas, aceleran los joins y mejoran significativamente el rendimiento de consultas analíticas sobre grandes volúmenes de datos.
	
¿Cómo manejarías el crecimiento de datos históricos en este warehouse?
	Para manejar el crecimiento de datos históricos de forma eficiente y escalable, se aplicarían las siguientes estrategias:
	1-	Particionamiento de la tabla de hechos por tiempo, por ejemplo por año o mes, utilizando RANGE sobre la clave de tiempo. Esto permite que PostgreSQL lea solamente las particiones relevantes en consultas temporales.
	2-	Modelo append-only, donde los datos históricos no se actualizan ni eliminan, garantizando consistencia analítica y facilitando el mantenimiento.
	3-	Uso de vistas materializadas para métricas ejecutivas, reduciendo el costo de recalcular agregaciones históricas en cada consulta.
 	4-	Mantenimiento periódico, como refresco programado de vistas materializadas y archivado de particiones antiguas si es necesario.
	Estas prácticas aseguran que el warehouse pueda escalar sin degradar el rendimiento.
'''

-- =========================
-- 4.1: Conclusión
-- =========================
'''
La combinación de índices estratégicos, particionamiento temporal y vistas materializadas permite optimizar tanto el rendimiento de consultas analíticas como la escalabilidad del Data Warehouse. 
Mientras que los índices aceleran joins y filtros frecuentes, el particionamiento y el enfoque append-only aseguran un manejo eficiente del crecimiento histórico de datos. 
En conjunto, estas decisiones permiten mantener un warehouse robusto, eficiente y preparado para análisis avanzados y dashboards ejecutivos incluso con grandes volúmenes de información.
''
