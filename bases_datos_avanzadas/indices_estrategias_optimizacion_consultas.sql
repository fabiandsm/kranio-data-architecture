/* 
======================================
   EJERCICIO: Índices y Estrategias de Optimización de Consultas 
======================================
*/

-- 1 Configuración de base de datos y carga de datos de ejemplo:
-- Crear esquema dimensional optimizado
CREATE TABLE dim_tiempo (
    id SERIAL PRIMARY KEY,
    fecha DATE UNIQUE,
    año INTEGER,
    mes INTEGER,
    trimestre INTEGER,
    dia_semana VARCHAR(10)
);

CREATE TABLE dim_cliente (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    segmento VARCHAR(20),
    region VARCHAR(50)
);

CREATE TABLE hechos_ventas (
    id SERIAL PRIMARY KEY,
    id_tiempo INTEGER REFERENCES dim_tiempo(id),
    id_cliente INTEGER REFERENCES dim_cliente(id),
    total_venta DECIMAL(10,2),
    cantidad INTEGER,
    margen DECIMAL(5,2)
);

-- Generar datos de ejemplo (100,000 ventas)
INSERT INTO dim_tiempo (fecha, año, mes, trimestre, dia_semana)
SELECT 
    fecha,
    EXTRACT(YEAR FROM fecha),
    EXTRACT(MONTH FROM fecha),
    EXTRACT(QUARTER FROM fecha),
    TO_CHAR(fecha, 'Day')
FROM generate_series('2023-01-01'::date, '2024-12-31'::date, '1 day') as fecha;

-- Insertar datos de ventas (simulado)
-- Nota: En producción usar COPY o INSERT masivo

-- 2

-- Consulta analítica típica SIN optimización
EXPLAIN ANALYZE
SELECT 
    dt.año,
    dt.trimestre,
    dc.segmento,
    COUNT(*) as num_ventas,
    SUM(hv.total_venta) as ventas_total,
    AVG(hv.margen) as margen_promedio
FROM hechos_ventas hv
JOIN dim_tiempo dt ON hv.id_tiempo = dt.id
JOIN dim_cliente dc ON hv.id_cliente = dc.id
WHERE dt.año = 2024
  AND dc.segmento IN ('VIP', 'Premium')
  AND hv.total_venta > 100
GROUP BY dt.año, dt.trimestre, dc.segmento
ORDER BY dt.año, dt.trimestre, SUM(hv.total_venta) DESC;

-- Resultado típico SIN índices:
-- Execution time: ~5000ms
-- Plan: Sequential Scan on hechos_ventas (cost=10000.00..50000.00 rows=50000)
--       Hash Join, Nested Loop, etc.

-- 3 

-- Crear índices para optimizar la consulta analítica
CREATE INDEX idx_hechos_tiempo ON hechos_ventas(id_tiempo);
CREATE INDEX idx_hechos_cliente ON hechos_ventas(id_cliente);
CREATE INDEX idx_tiempo_año ON dim_tiempo(año);
CREATE INDEX idx_cliente_segmento ON dim_cliente(segmento);
CREATE INDEX idx_hechos_venta_total ON hechos_ventas(total_venta);

-- Índice compuesto para consulta específica
CREATE INDEX idx_hechos_analisis ON hechos_ventas(id_tiempo, id_cliente, total_venta);

-- Verificar que los índices existen
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('hechos_ventas', 'dim_tiempo', 'dim_cliente')
ORDER BY tablename, indexname;

-- 4

-- Re-ejecutar consulta CON optimización
EXPLAIN ANALYZE
SELECT 
    dt.año,
    dt.trimestre,
    dc.segmento,
    COUNT(*) as num_ventas,
    SUM(hv.total_venta) as ventas_total,
    AVG(hv.margen) as margen_promedio
FROM hechos_ventas hv
JOIN dim_tiempo dt ON hv.id_tiempo = dt.id
JOIN dim_cliente dc ON hv.id_cliente = dc.id
WHERE dt.año = 2024
  AND dc.segmento IN ('VIP', 'Premium')
  AND hv.total_venta > 100
GROUP BY dt.año, dt.trimestre, dc.segmento
ORDER BY dt.año, dt.trimestre, SUM(hv.total_venta) DESC;

-- Resultado esperado CON índices:
-- Execution time: ~50ms (100x más rápido)
-- Plan: Index Scan, Bitmap Index Scan, Hash Join optimizado

-- 5

-- Particionamiento por rangos para datos históricos
-- (Requiere recrear tabla - en producción planificar cuidadosamente)

-- Estrategia de particionamiento propuesta:
-- 1. Particionar hechos_ventas por id_tiempo (rangos mensuales)
-- 2. Subparticionar por hash de id_cliente para distribución uniforme
-- 3. Mantener particiones de los últimos 24 meses activas
-- 4. Archivar particiones más antiguas a storage económico

-- 5.1 Tabla hechos_ventas particionada


DROP TABLE IF EXISTS hechos_ventas CASCADE;

CREATE TABLE hechos_ventas (
    id          INTEGER NOT NULL,
    id_tiempo   INTEGER NOT NULL REFERENCES dim_tiempo(id),
    id_cliente  INTEGER NOT NULL REFERENCES dim_cliente(id),
    fecha       DATE NOT NULL,
    total_venta DECIMAL(10,2),
    cantidad    INTEGER,
    margen      DECIMAL(5,2),
    PRIMARY KEY (id, fecha, id_cliente)
)
PARTITION BY RANGE (fecha);


-- 5.2 Crear particiones mensuales + HASH por cliente

DO $$
DECLARE
    fecha_inicio DATE := '2023-01-01';
    fecha_fin DATE := '2024-12-31';
    mes_actual DATE;
    siguiente_mes DATE;
    nombre text;
    i int;
BEGIN
    mes_actual := date_trunc('month', fecha_inicio);

    WHILE mes_actual <= fecha_fin LOOP
        
        siguiente_mes := mes_actual + INTERVAL '1 month';

        nombre := format(
            'hechos_ventas_%s_%s',
            to_char(mes_actual, 'YYYY'),
            to_char(mes_actual, 'MM')
        );

        -- partición mensual
        EXECUTE format(
'CREATE TABLE IF NOT EXISTS %I
 PARTITION OF hechos_ventas
 FOR VALUES FROM (%L) TO (%L)
 PARTITION BY HASH (id_cliente);',
            nombre,
            mes_actual,
            siguiente_mes
        );

        -- subparticiones hash
        FOR i IN 0..3 LOOP
            EXECUTE format(
'CREATE TABLE IF NOT EXISTS %I_h%s
 PARTITION OF %I
 FOR VALUES WITH (MODULUS 4, REMAINDER %s);',
                nombre,
                i,
                nombre,
                i
            );
        END LOOP;

        mes_actual := siguiente_mes;
    END LOOP;
END $$;

-- Verificar particiones creadas
SELECT inhrelid::regclass AS particion
FROM pg_inherits
WHERE inhparent = 'hechos_ventas'::regclass
ORDER BY 1;

-- 5.3 todo lo anterior a 24 meses → marcar para archivado

DO $$
DECLARE
    limite DATE := date_trunc('month', current_date - INTERVAL '24 months');
    r record;
    fecha_part DATE;
BEGIN
    FOR r IN
        SELECT inhrelid::regclass AS particion
        FROM pg_inherits
        WHERE inhparent = 'hechos_ventas'::regclass
    LOOP
        
        -- extraer YYYY_MM de cualquier nombre
        fecha_part := to_date(
            substring(r.particion::text FROM '([0-9]{4})_([0-9]{2})'),
            'YYYY_MM'
        );

        IF fecha_part < limite THEN
            RAISE NOTICE '→ Esta partición debe ARCHIVARSE: %', r.particion;
        END IF;

    END LOOP;
END $$;

-- 5.4 Exportar cada partición a storage económico (CSV)
DO $$
DECLARE
    limite DATE := date_trunc('month', current_date - INTERVAL '24 months');
    r record;
    fecha_part DATE;
    path text;
BEGIN
    FOR r IN
        SELECT inhrelid::regclass AS particion
        FROM pg_inherits
        WHERE inhparent = 'hechos_ventas'::regclass
    LOOP
        fecha_part := to_date(
            substring(r.particion::text FROM '([0-9]{4})_([0-9]{2})'),
            'YYYY_MM'
        );

        IF fecha_part < limite THEN
            
            path := 'hechos_' || r.particion || '.csv';

            RAISE NOTICE 'Exportando → %', r.particion;

            EXECUTE format(
                'COPY (SELECT * FROM %I) TO %L WITH CSV HEADER',
                r.particion,
                path
            );
        END IF;
    END LOOP;
END $$;

-- 6 Comparación de performance y recomendaciones:

-- Crear vista materializada para consultas muy frecuentes
CREATE MATERIALIZED VIEW mv_ventas_mensuales AS
SELECT 
    dt.año,
    dt.mes,
    dc.segmento,
    COUNT(*) as num_ventas,
    SUM(hv.total_venta) as ventas_total,
    AVG(hv.margen) as margen_promedio
FROM hechos_ventas hv
JOIN dim_tiempo dt ON hv.id_tiempo = dt.id
JOIN dim_cliente dc ON hv.id_cliente = dc.id
GROUP BY dt.año, dt.mes, dc.segmento;

-- Índice en vista materializada
CREATE INDEX idx_mv_mensual ON mv_ventas_mensuales(año, mes, segmento);

-- Comparación de performance:
-- Consulta directa: ~50ms (con índices)
-- Vista materializada: ~5ms (precalculada)
-- Beneficio: 10x más rápido para consultas repetitivas

-- Recomendaciones de mantenimiento:
-- 1. Reindexar índices mensualmente: REINDEX INDEX CONCURRENTLY index_name;
-- 2. Actualizar estadísticas: ANALYZE hechos_ventas;
-- 3. Monitorear uso de índices: SELECT * FROM pg_stat_user_indexes;
-- 4. Refrescar vistas materializadas: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_mensuales;

/* 
======================================
7 Verificación: 

7.1 Explica cómo los índices y el particionamiento transforman una consulta que podría tardar minutos en una que se ejecuta en milisegundos.
- Los índices funcionan de manera similar al índice de un libro, permitiendo acceder directamente a las filas relevantes y evitando recorridos completos de la tabla.
El particionamiento divide las tablas en segmentos más pequeños; en este caso, se aplicó un particionamiento por rango sobre la columna FECHA y un subparticionamiento por HASH sobre la columna id_cliente.
Al combinar ambas estrategias, se reduce significativamente la cantidad de datos leídos y se optimiza el uso de CPU y disco, logrando que consultas que antes tardaban minutos se ejecuten en milisegundos.

7.2 Describe escenarios donde cada tipo de índice sería más apropiado.
- Trabajo pesado --> Índices B-Tree: Para Búsqueda por rango, ordenamiento, joins y Filtros selectivos.
- Eficiencia en Datos Categóricos --> Índices Bitmap: Columnas categóricas, Múltiples condiciones AND/OR y Data warehousing
- Optimización de Consultas Multicolumna --> Índices Compuestos: Orden importa (la primera columna debe ser la más selectiva o usada)
- Funcionales y Parciales --> Índices Especializados: Índices funcionales (aceleran expresiones calculadas), Índices parciales (Solo indexan filas que cumplen condición) 
======================================
*/
