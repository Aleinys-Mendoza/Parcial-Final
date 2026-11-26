-- ConectaSucre | 05_TCL.sql | MySQL 8.0.18+
-- Ejecutar como administrador, una vez, sobre el dataset validado.
-- Los procedimientos auxiliares permiten IF y manejo de excepciones en MySQL.
-- Se eliminan al terminar; no forman parte del modelo definitivo.
USE conectasucre_ddl;

-- ============================================================
-- A. COMMIT: despacho del pedido 251 (Toluviejo).
-- ============================================================
DROP PROCEDURE IF EXISTS demo_tcl_a;
DELIMITER $$
CREATE PROCEDURE demo_tcl_a()
BEGIN
    DECLARE v_weight DECIMAL(12,2);
    DECLARE v_capacity DECIMAL(12,2);
    DECLARE v_dispatch INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT total_weight_kg INTO v_weight FROM orders
    WHERE order_id = 251 AND order_status = 'PENDING' FOR UPDATE;
    SELECT load_capacity_kg INTO v_capacity FROM vehicles
    WHERE vehicle_id = 11 AND vehicle_status = 'AVAILABLE' FOR UPDATE;
    IF v_weight IS NULL OR v_capacity IS NULL OR v_weight > v_capacity
       OR NOT EXISTS (SELECT 1 FROM drivers WHERE driver_id = 11 AND driver_status = 'AVAILABLE')
       OR EXISTS (SELECT 1 FROM dispatch_assignments WHERE order_id = 251
           OR (dispatch_status IN ('ASSIGNED','IN_TRANSIT') AND (vehicle_id = 11 OR driver_id = 11))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'TCL A: pedido o recursos no disponibles';
    END IF;

    INSERT INTO dispatch_assignments
        (order_id, vehicle_id, driver_id, route_id, assignment_date,
         departure_date, dispatch_status, loaded_weight_kg, freight_amount)
    VALUES (251, 11, 11, 6, NOW(), NOW(), 'IN_TRANSIT', v_weight, 85000);
    SET v_dispatch = LAST_INSERT_ID();
    UPDATE orders SET order_status = 'IN_TRANSIT' WHERE order_id = 251;
    UPDATE vehicles SET vehicle_status = 'ON_ROUTE' WHERE vehicle_id = 11;
    UPDATE drivers SET driver_status = 'ON_ROUTE' WHERE driver_id = 11;
    COMMIT;

    SELECT 'COMMIT: despacho guardado' AS result, da.dispatch_id,
           o.order_id, o.order_status, da.dispatch_status,
           v.vehicle_status, d.driver_status
    FROM dispatch_assignments da JOIN orders o ON o.order_id = da.order_id
    JOIN vehicles v ON v.vehicle_id = da.vehicle_id
    JOIN drivers d ON d.driver_id = da.driver_id
    WHERE da.dispatch_id = v_dispatch;
END$$
DELIMITER ;
CALL demo_tcl_a();
DROP PROCEDURE demo_tcl_a;

-- ============================================================
-- B. ROLLBACK: pedido 300 (2200 kg), vehiculo 13 (650 kg).
-- Se simula la asignacion dentro de la transaccion y se revierte.
-- ============================================================
DROP PROCEDURE IF EXISTS demo_tcl_b;
DELIMITER $$
CREATE PROCEDURE demo_tcl_b()
BEGIN
    DECLARE v_weight DECIMAL(12,2);
    DECLARE v_capacity DECIMAL(12,2);
    DECLARE v_before VARCHAR(32);
    DECLARE v_dispatch INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT total_weight_kg, order_status INTO v_weight, v_before
    FROM orders WHERE order_id = 300 AND order_status = 'PENDING' FOR UPDATE;
    SELECT load_capacity_kg INTO v_capacity FROM vehicles
    WHERE vehicle_id = 13 AND vehicle_status = 'AVAILABLE' FOR UPDATE;
    IF v_weight IS NULL OR v_capacity IS NULL OR v_weight <= v_capacity
       OR NOT EXISTS (SELECT 1 FROM drivers WHERE driver_id = 13 AND driver_status = 'AVAILABLE')
       OR EXISTS (SELECT 1 FROM dispatch_assignments WHERE order_id = 300
           OR (dispatch_status IN ('ASSIGNED','IN_TRANSIT') AND (vehicle_id = 13 OR driver_id = 13))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'TCL B: escenario de sobrecarga no disponible';
    END IF;

    INSERT INTO dispatch_assignments
        (order_id, vehicle_id, driver_id, route_id, assignment_date,
         departure_date, dispatch_status, loaded_weight_kg, freight_amount)
    VALUES (300, 13, 13, 10, NOW(), NOW(), 'IN_TRANSIT', v_weight, 150000);
    SET v_dispatch = LAST_INSERT_ID();
    UPDATE orders SET order_status = 'IN_TRANSIT' WHERE order_id = 300;

    IF v_weight > v_capacity THEN
        ROLLBACK;
        SELECT 'ROLLBACK: el pedido supera la capacidad del vehiculo' AS result,
               v_weight AS order_weight_kg, v_capacity AS capacity_kg;
    ELSE
        COMMIT;
    END IF;

    SELECT o.order_id, v_before AS previous_status, o.order_status,
           (SELECT COUNT(*) FROM dispatch_assignments WHERE dispatch_id = v_dispatch) AS persisted_dispatches
    FROM orders o WHERE o.order_id = 300;
END$$
DELIMITER ;
CALL demo_tcl_b();
DROP PROCEDURE demo_tcl_b;

-- ============================================================
-- C. SAVEPOINT: pedido 286, ruta Sincelejo - Majagual.
-- El codigo 3819 corresponde a violacion de CHECK en MySQL.
-- ============================================================
DROP PROCEDURE IF EXISTS demo_tcl_c;
DELIMITER $$
CREATE PROCEDURE demo_tcl_c()
BEGIN
    DECLARE v_weight DECIMAL(12,2);
    DECLARE v_capacity DECIMAL(12,2);
    DECLARE v_dispatch INT UNSIGNED;
    DECLARE v_rejected BOOLEAN DEFAULT FALSE;
    DECLARE v_error TEXT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT total_weight_kg INTO v_weight FROM orders
    WHERE order_id = 286 AND order_status IN ('PENDING','CONFIRMED','IN_PREPARATION') FOR UPDATE;
    SELECT load_capacity_kg INTO v_capacity FROM vehicles
    WHERE vehicle_id = 12 AND vehicle_status = 'AVAILABLE' FOR UPDATE;
    IF v_weight IS NULL OR v_capacity IS NULL OR v_weight > v_capacity
       OR NOT EXISTS (SELECT 1 FROM drivers WHERE driver_id = 12 AND driver_status = 'AVAILABLE')
       OR EXISTS (SELECT 1 FROM dispatch_assignments WHERE order_id = 286
           OR (dispatch_status IN ('ASSIGNED','IN_TRANSIT') AND (vehicle_id = 12 OR driver_id = 12))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'TCL C: pedido o recursos no disponibles';
    END IF;

    INSERT INTO dispatch_assignments
        (order_id, vehicle_id, driver_id, route_id, assignment_date,
         departure_date, dispatch_status, loaded_weight_kg, freight_amount)
    VALUES (286, 12, 12, 11, NOW(), NOW(), 'IN_TRANSIT', v_weight, 180000);
    SET v_dispatch = LAST_INSERT_ID();
    UPDATE vehicles SET vehicle_status = 'ON_ROUTE' WHERE vehicle_id = 12;
    UPDATE drivers SET driver_status = 'ON_ROUTE' WHERE driver_id = 12;
    UPDATE orders SET order_status = 'IN_TRANSIT' WHERE order_id = 286;

    SAVEPOINT sp_despacho_ok;
    BEGIN
        DECLARE CONTINUE HANDLER FOR 3819
        BEGIN
            GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
            SET v_rejected = TRUE;
        END;
        INSERT INTO incidents
            (dispatch_id, incident_type, description, incident_date, delay_minutes, company_responsible)
        VALUES (v_dispatch, 'INVALID_TOLL_CODE', 'Prueba de novedad de peaje incorrecta', NOW(), 0, FALSE);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'TCL C: la restriccion CHECK no rechazo la novedad';
    END IF;
    ROLLBACK TO SAVEPOINT sp_despacho_ok;
    COMMIT;

    SELECT 'SAVEPOINT: despacho conservado, novedad descartada' AS result,
           v_error AS rejected_error, da.dispatch_id, da.departure_date,
           da.dispatch_status, v.vehicle_status, d.driver_status, o.order_status,
           (SELECT COUNT(*) FROM incidents i WHERE i.dispatch_id = v_dispatch) AS persisted_incidents
    FROM dispatch_assignments da JOIN vehicles v ON v.vehicle_id = da.vehicle_id
    JOIN drivers d ON d.driver_id = da.driver_id JOIN orders o ON o.order_id = da.order_id
    WHERE da.dispatch_id = v_dispatch;
END$$
DELIMITER ;
CALL demo_tcl_c();
DROP PROCEDURE demo_tcl_c;

-- Validacion final (esperados: 252 despachos, 200 incidentes, sin sobrecargas).
SELECT COUNT(*) AS total_dispatches FROM dispatch_assignments;
SELECT COUNT(*) AS total_incidents FROM incidents;
SELECT da.dispatch_id, da.order_id, da.loaded_weight_kg, v.load_capacity_kg
FROM dispatch_assignments da JOIN vehicles v ON v.vehicle_id = da.vehicle_id
WHERE da.loaded_weight_kg > v.load_capacity_kg;
