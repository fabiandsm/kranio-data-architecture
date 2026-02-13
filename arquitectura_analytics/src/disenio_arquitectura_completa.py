"""
Arquitectura simplificada para un sistema de analytics retail.

Este archivo representa la arquitectura como estructura de datos.
No corresponde a código productivo ni a un DAG de Airflow.
"""

arquitectura_retail = {
    "ingesta": ["API de ventas", "Base de datos de inventario"],
    "procesamiento": ["Limpieza de datos", "Cálculo de métricas"],
    "almacenamiento": ["PostgreSQL para datos limpios"],
    "consumo": ["Dashboard de ventas", "Reportes diarios"],
}

if __name__ == "__main__":
    from pprint import pprint
    pprint(arquitectura_retail)

