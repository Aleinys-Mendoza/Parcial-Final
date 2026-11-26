-- DDL C | ConectaSucre
-- Ejecutar despues de DDL_B.sql.

USE conectasucre_ddl;

ALTER TABLE dispatch_assignments DROP FOREIGN KEY fk_dispatch_assignments_order_id;
ALTER TABLE dispatch_assignments ADD CONSTRAINT fk_dispatch_assignments_order_id FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX idx_order_dispatch_status USING BTREE ON dispatch_assignments (order_id, dispatch_status);

-- El indice B-Tree facilita la busqueda por order_id y por la combinacion
-- de order_id y dispatch_status, reduciendo las filas examinadas en el rastreo.
-- No garantiza mejoras para consultas que filtren solo por dispatch_status.

SHOW CREATE TABLE dispatch_assignments;
SHOW INDEX FROM dispatch_assignments;

-- Tablas dependientes: completan el modelo aprobado.
USE conectasucre_ddl;

CREATE TABLE deliveries (
  delivery_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  dispatch_id INT UNSIGNED NOT NULL,
  actual_delivery_date DATETIME NULL,
  delivered_weight_kg DECIMAL(12,2) NOT NULL,
  delivery_status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
  received_by VARCHAR(120) NULL,
  observations TEXT NULL,
  CONSTRAINT fk_deliveries_dispatch_id FOREIGN KEY (dispatch_id) REFERENCES dispatch_assignments (dispatch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_deliveries_01 CHECK (delivered_weight_kg >= 0),
  CONSTRAINT chk_deliveries_02 CHECK (delivery_status IN ('PENDING', 'COMPLETED', 'PARTIAL', 'CANCELLED')),
  CONSTRAINT chk_deliveries_03 CHECK (delivery_status NOT IN ('COMPLETED','PARTIAL') OR (actual_delivery_date IS NOT NULL AND delivered_weight_kg > 0)),
  INDEX idx_delivery_date (actual_delivery_date)
) ENGINE=InnoDB;

CREATE TABLE incidents (
  incident_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  dispatch_id INT UNSIGNED NULL,
  delivery_id INT UNSIGNED NULL,
  route_id INT UNSIGNED NULL,
  incident_type VARCHAR(32) NOT NULL,
  description TEXT NOT NULL,
  incident_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  delay_minutes INT UNSIGNED NOT NULL,
  company_responsible BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_incidents_dispatch_id FOREIGN KEY (dispatch_id) REFERENCES dispatch_assignments (dispatch_id),
  CONSTRAINT fk_incidents_delivery_id FOREIGN KEY (delivery_id) REFERENCES deliveries (delivery_id),
  CONSTRAINT fk_incidents_route_id FOREIGN KEY (route_id) REFERENCES routes (route_id),
  CONSTRAINT chk_incidents_01 CHECK (incident_type IN ('MECHANICAL_FAILURE', 'ROAD_BLOCKAGE', 'TRAFFIC_DELAY', 'ACCESS_DIFFICULTY', 'ROUTE_CHANGE', 'DAMAGED_GOODS', 'PARTIAL_RETURN', 'TOLL_EVENT', 'OTHER')),
  CONSTRAINT chk_incidents_02 CHECK (delay_minutes >= 0),
  CONSTRAINT chk_incidents_03 CHECK ((dispatch_id IS NOT NULL) + (delivery_id IS NOT NULL) + (route_id IS NOT NULL) = 1),
  CONSTRAINT chk_incidents_04 CHECK (company_responsible IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE dispatch_audits (
  audit_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  dispatch_id INT UNSIGNED NOT NULL,
  delivery_id INT UNSIGNED NULL,
  modification_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  database_user VARCHAR(120) NOT NULL,
  previous_status VARCHAR(32) NOT NULL,
  new_status VARCHAR(32) NOT NULL,
  observation TEXT NULL,
  CONSTRAINT fk_dispatch_audits_dispatch_id FOREIGN KEY (dispatch_id) REFERENCES dispatch_assignments (dispatch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_dispatch_audits_delivery_id FOREIGN KEY (delivery_id) REFERENCES deliveries (delivery_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_dispatch_audits_01 CHECK (previous_status <> new_status)
) ENGINE=InnoDB;

SHOW TABLES;
