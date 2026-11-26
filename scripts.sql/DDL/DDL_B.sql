-- DDL B | ConectaSucre
-- Ejecutar despues de DDL_A.sql.

USE conectasucre_ddl;

ALTER TABLE vehicles
 ADD COLUMN vehicle_status VARCHAR(32) NOT NULL DEFAULT 'AVAILABLE',
 ADD CONSTRAINT chk_vehicles_01 CHECK (load_capacity_kg > 0),
 ADD CONSTRAINT chk_vehicles_02 CHECK (vehicle_status IN ('AVAILABLE', 'ON_ROUTE', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE'));

SHOW CREATE TABLE vehicles;
