# 2. Decisiones Clave de Arquitectura

Este documento describe las principales decisiones tecnológicas tomadas
para el diseño del sistema de analytics retail, junto con su justificación
técnica y de negocio.

## 🗄️ Base de Datos

**Tecnología seleccionada:** PostgreSQL (base de datos relacional open source)

### Justificación
PostgreSQL fue seleccionada como motor de almacenamiento para los datos
analíticos debido a su alta madurez, estabilidad y facilidad de uso.
Permite trabajar con SQL estándar, es open source y se integra fácilmente
con herramientas de visualización.

### Alternativas consideradas
- MySQL
- SQL Server
- BigQuery

### Trade-offs
- No está optimizada para escenarios de Big Data a gran escala
- Escalabilidad horizontal limitada frente a soluciones cloud nativas
