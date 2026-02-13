# 1. Identificación de Componentes Principales

En esta sección se describen los componentes principales que conforman
la arquitectura del sistema de analytics retail, organizados por capas
según su función dentro del flujo de datos.

---

## 1.1 Capa de Ingesta de Datos

La capa de ingesta es responsable de capturar los datos desde los
sistemas fuente del negocio. En esta arquitectura se consideran las
siguientes fuentes:

- **API de ventas:** provee información transaccional relacionada con
  ventas realizadas, incluyendo fecha, producto, precio y cantidad.
- **Base de datos de inventario:** contiene información operativa sobre
  stock disponible, movimientos de inventario y rotación de productos.

El objetivo de esta capa es asegurar la correcta y oportuna obtención de
los datos necesarios para el análisis.

---

## 1.2 Capa de Procesamiento de Datos

La capa de procesamiento transforma los datos crudos en información
confiable y utilizable para análisis. Sus principales responsabilidades
son:

- **Limpieza de datos:** eliminación de duplicados, validación de
  valores nulos y estandarización de formatos.
- **Cálculo de métricas:** generación de indicadores clave como ventas
  agregadas, ticket promedio y rotación de inventario.

Esta capa es clave para garantizar la calidad de los datos que serán
consumidos por el negocio.

---

## 1.3 Capa de Almacenamiento

La capa de almacenamiento es responsable de persistir los datos ya
procesados y listos para análisis. En esta arquitectura se considera un
repositorio central de datos limpios:

- **Base de datos analítica:** almacena información estructurada que
  permite realizar consultas eficientes y soportar herramientas de
  visualización y reporting.

Este componente actúa como una fuente única de verdad para el sistema.

---

## 1.4 Capa de Consumo de Información

La capa de consumo permite que los usuarios finales accedan a la
información generada por el sistema. Incluye:

- **Dashboards de ventas:** visualización interactiva de métricas clave
  para el seguimiento del desempeño del negocio.
- **Reportes diarios:** informes periódicos utilizados para control
  operativo y análisis histórico.

Esta capa es donde se materializa el valor del sistema de analytics para
el negocio.

---

## 1.5 Flujo General de la Arquitectura

El flujo de datos del sistema sigue una secuencia lógica:

1. Los datos son extraídos desde las fuentes de ingesta.
2. Se procesan y transforman para asegurar su calidad.
3. Se almacenan en un repositorio central de datos limpios.
4. Son consumidos mediante dashboards y reportes.

Este enfoque por capas permite una arquitectura clara, mantenible y
alineada con las necesidades del negocio.
