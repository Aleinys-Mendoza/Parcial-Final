-- ConectaSucre | DCL A, B y C | MySQL 8
-- Ejecutar BLOQUE 1 con administrador (CREATE USER, CREATE ROLE y GRANT OPTION).
-- Usar cuentas locales NUEVAS, exclusivas de este ejercicio.
-- No ejecutar las pruebas negativas como administrador.
-- Las contraseñas son generadas por MySQL: guardar cada resultado de CREATE USER
-- de forma privada y no mostrarlo en las capturas. MySQL 8.0.18+.
USE conectasucre_ddl;

-- BLOQUE 1. CONFIGURACION (administrador)
-- A. Rastreo de clientes
CREATE ROLE 'rol_rastreo_cliente'@'localhost';
CREATE USER 'usr_cliente_tienda1'@'localhost' IDENTIFIED BY RANDOM PASSWORD;
GRANT SELECT ON conectasucre_ddl.orders TO 'rol_rastreo_cliente'@'localhost';
GRANT SELECT ON conectasucre_ddl.dispatch_assignments TO 'rol_rastreo_cliente'@'localhost';
GRANT SELECT ON conectasucre_ddl.deliveries TO 'rol_rastreo_cliente'@'localhost';
GRANT 'rol_rastreo_cliente'@'localhost' TO 'usr_cliente_tienda1'@'localhost';
SET DEFAULT ROLE 'rol_rastreo_cliente'@'localhost' TO 'usr_cliente_tienda1'@'localhost';

-- B. Separacion de responsabilidades
CREATE ROLE 'rol_despachador_muelle'@'localhost', 'rol_admin_flota'@'localhost';
CREATE USER 'usr_despachador_muelle'@'localhost' IDENTIFIED BY RANDOM PASSWORD;
CREATE USER 'usr_admin_flota'@'localhost' IDENTIFIED BY RANDOM PASSWORD;
GRANT INSERT, UPDATE ON conectasucre_ddl.dispatch_assignments TO 'rol_despachador_muelle'@'localhost';
GRANT INSERT, UPDATE ON conectasucre_ddl.deliveries TO 'rol_despachador_muelle'@'localhost';
GRANT INSERT, UPDATE, DELETE ON conectasucre_ddl.vehicles TO 'rol_admin_flota'@'localhost';
GRANT INSERT, UPDATE, DELETE ON conectasucre_ddl.drivers TO 'rol_admin_flota'@'localhost';
GRANT INSERT, UPDATE, DELETE ON conectasucre_ddl.routes TO 'rol_admin_flota'@'localhost';
GRANT 'rol_despachador_muelle'@'localhost' TO 'usr_despachador_muelle'@'localhost';
GRANT 'rol_admin_flota'@'localhost' TO 'usr_admin_flota'@'localhost';
SET DEFAULT ROLE 'rol_despachador_muelle'@'localhost' TO 'usr_despachador_muelle'@'localhost';
SET DEFAULT ROLE 'rol_admin_flota'@'localhost' TO 'usr_admin_flota'@'localhost';

-- C. Simular permiso historico y revocarlo de inmediato, sin borrar datos.
GRANT DELETE ON conectasucre_ddl.deliveries TO 'rol_despachador_muelle'@'localhost';
SHOW GRANTS FOR 'rol_despachador_muelle'@'localhost';
REVOKE DELETE ON conectasucre_ddl.deliveries FROM 'rol_despachador_muelle'@'localhost';
SHOW GRANTS FOR 'rol_despachador_muelle'@'localhost';
-- Diccionario de MySQL: consultar privilegios de tabla antes y despues si se desea.
SELECT GRANTEE, TABLE_SCHEMA, TABLE_NAME, PRIVILEGE_TYPE
FROM information_schema.TABLE_PRIVILEGES
WHERE TABLE_SCHEMA = 'conectasucre_ddl'
  AND GRANTEE = CONCAT(QUOTE('rol_despachador_muelle'), '@', QUOTE('localhost'))
ORDER BY TABLE_NAME, PRIVILEGE_TYPE;
SHOW GRANTS FOR 'usr_cliente_tienda1'@'localhost' USING 'rol_rastreo_cliente'@'localhost';
SHOW GRANTS FOR 'usr_despachador_muelle'@'localhost' USING 'rol_despachador_muelle'@'localhost';
SHOW GRANTS FOR 'usr_admin_flota'@'localhost' USING 'rol_admin_flota'@'localhost';

-- BLOQUE 2. PRUEBAS MANUALES (NO ejecutar como administrador).
-- Copiar cada consulta sin el prefijo -- en la conexion del usuario indicado.
-- Las operaciones permitidas usan WHERE 1=0 para no cambiar ningun registro.
-- Las denegadas deben producir error de permisos incluso con WHERE 1=0.

-- A: conexion usr_cliente_tienda1
-- SELECT CURRENT_USER(), CURRENT_ROLE();
-- SELECT * FROM conectasucre_ddl.dispatch_assignments LIMIT 5;
-- UPDATE conectasucre_ddl.dispatch_assignments SET dispatch_status = 'ASSIGNED' WHERE 1=0;

-- B: conexion usr_despachador_muelle
-- SELECT CURRENT_USER(), CURRENT_ROLE();
-- UPDATE conectasucre_ddl.dispatch_assignments SET dispatch_status = 'ASSIGNED' WHERE 1=0;
-- UPDATE conectasucre_ddl.deliveries SET delivery_status = 'PENDING' WHERE 1=0;
-- UPDATE conectasucre_ddl.vehicles SET vehicle_status = 'AVAILABLE' WHERE 1=0;

-- B: conexion usr_admin_flota
-- SELECT CURRENT_USER(), CURRENT_ROLE();
-- UPDATE conectasucre_ddl.vehicles SET vehicle_status = 'AVAILABLE' WHERE 1=0;
-- UPDATE conectasucre_ddl.dispatch_assignments SET dispatch_status = 'ASSIGNED' WHERE 1=0;

-- C: conexion usr_despachador_muelle (despues del REVOKE)
-- SELECT CURRENT_USER(), CURRENT_ROLE();
-- DELETE FROM conectasucre_ddl.deliveries WHERE 1=0;

-- NOTA: los permisos SELECT del cliente son a nivel de tabla, tal como pide
-- el ejercicio. No restringen filas a un cliente concreto. Para produccion
-- se requeriria una capa adicional de autorizacion por cliente.
-- No se otorgan SELECT adicionales a los roles de escritura.
