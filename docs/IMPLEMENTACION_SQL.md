# Implementación de la base de datos SQL (ConectaSucre)

## Motor
MySQL 8.0 (imagen `mysql:8.0`).

## Orden de ejecución
1. `scripts.sql/DDL/DDL_A.sql` — creación del schema y tablas base.
2. `scripts.sql/DDL/DDL_B.sql` — ajustes (columnas/estados/CHECK) sobre `vehicles`.
3. `scripts.sql/DDL/DDL_C.sql` — FKs adicionales, índices y tablas dependientes (`deliveries`, `incidents`, etc.).
4. `scripts.sql/DATASET/INSERT_DATA.sql` — carga de 200+ registros.
5. `scripts.sql/view/*.sql`, `Stored Functions`, `Stored Procedures`, `TRIGGER` — objetos adicionales.

## Contenido del modelo
- 12 tablas operativas: `customers`, `producers`, `products`, `vehicles`, `drivers`, `routes`, `orders`, `order_details`, `dispatch_assignments`, `deliveries`, `incidents`, `dispatch_audits`.
- Restricciones: PK, FK, UNIQUE, CHECK.
- Índices: PK, UNIQUE y secundarios (B-Tree).
- Triggers de auditoría y control de asignación.
- Procedimientos/funciones almacenadas y vistas.

## Automatización Docker
El contenedor MySQL ejecuta `docker/mysql/init/00_init.sh`, que corre los scripts en el orden anterior sobre la base `conectasucre_ddl`.

## Verificación
```bash
mysql -h 127.0.0.1 -P 3306 -u root -p conectasucre_ddl -e "SELECT COUNT(*) FROM customers;"
```
