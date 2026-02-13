# 3. Requisitos y Restricciones del Sistema

En esta sección se identifican los requisitos de negocio y técnicos del
sistema de analytics retail, así como las principales restricciones que
influyen en el diseño de la arquitectura.

---

## 3.1 Requisitos Funcionales (Negocio)

El sistema debe permitir:

- Consolidar datos de ventas provenientes de una API transaccional
- Integrar información de inventario desde una base de datos operativa
- Calcular métricas clave como:
  - Ventas diarias y mensuales
  - Ticket promedio
  - Rotación de inventario
- Visualizar indicadores mediante dashboards interactivos
- Generar reportes diarios para seguimiento operativo

Estos requisitos buscan apoyar la toma de decisiones comerciales y
operacionales del negocio retail.

---

## 3.2 Requisitos No Funcionales (Técnicos)

El sistema debe cumplir con los siguientes atributos de calidad:

- **Disponibilidad:** el sistema debe estar disponible para consultas
  durante el horario laboral.
- **Rendimiento:** los dashboards deben responder en tiempos aceptables
  para el usuario final.
- **Escalabilidad:** la arquitectura debe permitir crecer en volumen de
  datos sin rediseños complejos.
- **Mantenibilidad:** los pipelines deben ser fáciles de modificar y
  monitorear.
- **Calidad de datos:** se deben aplicar validaciones y procesos de
  limpieza antes de consumir la información.
- **Seguridad:** el acceso a los datos debe estar controlado según roles.

---

## 3.3 Restricciones del Sistema

Las principales restricciones identificadas son:

- Presupuesto limitado para licencias e infraestructura
- Equipo técnico reducido
- Infraestructura inicialmente on-premise o de bajo costo
- Volúmenes de datos moderados en la etapa inicial
- Necesidad de implementar la solución en un plazo acotado

Estas restricciones justifican la selección de tecnologías maduras,
simples de operar y ampliamente adoptadas.
