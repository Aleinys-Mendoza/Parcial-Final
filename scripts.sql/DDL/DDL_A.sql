-- DDL A | ConectaSucre 
-- Ejecutar sobre un esquema nuevo.
-- Importar en Workbench o ejecutar en un esquema nuevo. No borra datos.

CREATE SCHEMA IF NOT EXISTS conectasucre_ddl DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

USE conectasucre_ddl;

CREATE TABLE customers (
  customer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_name VARCHAR(120) NOT NULL,
  document_number VARCHAR(30) NOT NULL UNIQUE,
  municipality VARCHAR(120) NOT NULL,
  address VARCHAR(120) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(120) NULL
) ENGINE=InnoDB;

CREATE TABLE producers (
  producer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_name VARCHAR(120) NOT NULL,
  document_number VARCHAR(30) NOT NULL UNIQUE,
  municipality VARCHAR(120) NOT NULL,
  address VARCHAR(120) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(120) NULL
) ENGINE=InnoDB;

CREATE TABLE products (
  product_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  producer_id INT UNSIGNED NOT NULL,
  product_name VARCHAR(120) NOT NULL,
  description TEXT NULL,
  unit_weight_kg DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_products_producer_id FOREIGN KEY (producer_id) REFERENCES producers (producer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_products_01 CHECK (unit_weight_kg > 0),
  CONSTRAINT chk_products_02 CHECK (unit_price >= 0)
) ENGINE=InnoDB;

CREATE TABLE orders (
  order_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id INT UNSIGNED NOT NULL,
  order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  promised_delivery_date DATETIME NOT NULL,
  destination_municipality VARCHAR(120) NOT NULL,
  delivery_address VARCHAR(120) NOT NULL,
  total_weight_kg DECIMAL(12,2) NOT NULL,
  order_status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
  partial_closure_accepted BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_orders_customer_id FOREIGN KEY (customer_id) REFERENCES customers (customer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_orders_01 CHECK (total_weight_kg >= 0),
  CONSTRAINT chk_orders_02 CHECK (order_status = 'PENDING' OR order_status = 'CANCELLED' OR total_weight_kg > 0),
  CONSTRAINT chk_orders_03 CHECK (promised_delivery_date >= order_date),
  CONSTRAINT chk_orders_04 CHECK (partial_closure_accepted IN (0,1)),
  CONSTRAINT chk_orders_05 CHECK (order_status IN ('PENDING', 'CONFIRMED', 'IN_PREPARATION', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'))
) ENGINE=InnoDB;

CREATE TABLE order_details (
  order_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  unit_weight_kg DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_order_details_order_id FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_order_details_product_id FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT uq_order_details_order_product UNIQUE (order_id, product_id),
  CONSTRAINT chk_order_details_01 CHECK (quantity > 0),
  CONSTRAINT chk_order_details_02 CHECK (unit_price >= 0),
  CONSTRAINT chk_order_details_03 CHECK (unit_weight_kg > 0)
) ENGINE=InnoDB;

CREATE TABLE vehicles (
  vehicle_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  license_plate VARCHAR(30) NOT NULL UNIQUE,
  vehicle_type VARCHAR(120) NOT NULL,
  brand VARCHAR(120) NOT NULL,
  model VARCHAR(120) NOT NULL,
  load_capacity_kg DECIMAL(12,2) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE drivers (
  driver_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  document_number VARCHAR(30) NOT NULL UNIQUE,
  first_name VARCHAR(120) NOT NULL,
  last_name VARCHAR(120) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  license_number VARCHAR(30) NOT NULL UNIQUE,
  driver_status VARCHAR(32) NOT NULL DEFAULT 'AVAILABLE',
  CONSTRAINT chk_drivers_01 CHECK (driver_status IN ('AVAILABLE', 'ON_ROUTE', 'UNAVAILABLE'))
) ENGINE=InnoDB;

CREATE TABLE routes (
  route_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  route_name VARCHAR(120) NOT NULL,
  origin_municipality VARCHAR(120) NOT NULL,
  destination_municipality VARCHAR(120) NOT NULL,
  distance_km DECIMAL(12,2) NOT NULL,
  estimated_duration_minutes INT UNSIGNED NOT NULL,
  CONSTRAINT chk_routes_01 CHECK (distance_km >= 0),
  CONSTRAINT chk_routes_02 CHECK (estimated_duration_minutes >= 0)
) ENGINE=InnoDB;

-- PUNTO A: creacion de dispatch_assignments
USE conectasucre_ddl;

CREATE TABLE dispatch_assignments (
  dispatch_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL,
  vehicle_id INT UNSIGNED NOT NULL,
  driver_id INT UNSIGNED NOT NULL,
  route_id INT UNSIGNED NOT NULL,
  assignment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  departure_date DATETIME NULL,
  dispatch_status VARCHAR(32) NOT NULL DEFAULT 'ASSIGNED',
  loaded_weight_kg DECIMAL(12,2) NOT NULL,
  freight_amount DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_dispatch_assignments_order_id FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT fk_dispatch_assignments_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES vehicles (vehicle_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_dispatch_assignments_driver_id FOREIGN KEY (driver_id) REFERENCES drivers (driver_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_dispatch_assignments_route_id FOREIGN KEY (route_id) REFERENCES routes (route_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_dispatch_assignments_01 CHECK (dispatch_status IN ('ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED')),
  CONSTRAINT chk_dispatch_assignments_02 CHECK (loaded_weight_kg >= 0),
  CONSTRAINT chk_dispatch_assignments_03 CHECK (departure_date IS NULL OR departure_date >= assignment_date),
  CONSTRAINT chk_dispatch_assignments_04 CHECK (freight_amount >= 0),
  INDEX idx_dispatch_driver_date (driver_id, assignment_date),
  INDEX idx_dispatch_vehicle_status (vehicle_id, dispatch_status),
  INDEX idx_dispatch_driver_status (driver_id, dispatch_status)
) ENGINE=InnoDB;

SHOW CREATE TABLE dispatch_assignments;
