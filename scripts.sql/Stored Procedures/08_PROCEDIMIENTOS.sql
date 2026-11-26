-- ConectaSucre | MySQL 8 | Procedimientos A, B y C
USE conectasucre_ddl;
DROP PROCEDURE IF EXISTS sp_register_dispatch;
DROP PROCEDURE IF EXISTS sp_assign_dispatch_resources;
DROP PROCEDURE IF EXISTS sp_process_integral_delivery;
DELIMITER $$
-- A. Registra salida de pedido PENDING y reserva ambos recursos.
-- Tarifa propuesta para nuevas operaciones: 500 COP/kg, minimo 50000 COP.
-- Ejecutar CALL fuera de una transaccion iniciada por el cliente.
CREATE PROCEDURE sp_register_dispatch(IN p_order_id INT UNSIGNED, IN p_vehicle_id INT UNSIGNED,
 IN p_driver_id INT UNSIGNED, IN p_route_id INT UNSIGNED)
BEGIN
 DECLARE v_weight DECIMAL(12,2);
 DECLARE v_capacity DECIMAL(12,2);
 DECLARE v_destination VARCHAR(120);
 DECLARE v_route_destination VARCHAR(120);
 DECLARE v_order_status VARCHAR(32);
 DECLARE v_vehicle_status VARCHAR(32);
 DECLARE v_driver_status VARCHAR(32);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 SELECT total_weight_kg,order_status,destination_municipality INTO v_weight,v_order_status,v_destination
 FROM orders WHERE order_id=p_order_id FOR UPDATE;
 IF v_order_status IS NULL OR v_order_status<>'PENDING' OR v_weight<=0 THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pedido inexistente, no pendiente o sin peso'; END IF;
 SELECT load_capacity_kg,vehicle_status INTO v_capacity,v_vehicle_status FROM vehicles WHERE vehicle_id=p_vehicle_id FOR UPDATE;
 SELECT driver_status INTO v_driver_status FROM drivers WHERE driver_id=p_driver_id FOR UPDATE;
 SELECT destination_municipality INTO v_route_destination FROM routes WHERE route_id=p_route_id FOR SHARE;
 IF v_route_destination IS NULL OR v_route_destination<>v_destination THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Ruta inexistente o destino incompatible'; END IF;
 IF v_vehicle_status IS NULL OR v_driver_status IS NULL OR v_vehicle_status<>'AVAILABLE' OR v_driver_status<>'AVAILABLE' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Vehiculo o conductor no disponible'; END IF;
 IF v_weight>v_capacity THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Capacidad de carga excedida'; END IF;
 IF EXISTS (SELECT 1 FROM dispatch_assignments WHERE dispatch_status IN ('ASSIGNED','IN_TRANSIT')
 AND (order_id=p_order_id OR vehicle_id=p_vehicle_id OR driver_id=p_driver_id)) THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Asignacion activa incompatible'; END IF;
 INSERT INTO dispatch_assignments(order_id,vehicle_id,driver_id,route_id,assignment_date,departure_date,dispatch_status,loaded_weight_kg,freight_amount)
 VALUES(p_order_id,p_vehicle_id,p_driver_id,p_route_id,NOW(),NOW(),'IN_TRANSIT',v_weight,GREATEST(50000,v_weight*500));
 UPDATE orders SET order_status='IN_TRANSIT' WHERE order_id=p_order_id;
 UPDATE vehicles SET vehicle_status='ON_ROUTE' WHERE vehicle_id=p_vehicle_id;
 UPDATE drivers SET driver_status='ON_ROUTE' WHERE driver_id=p_driver_id;
 COMMIT;
 SELECT LAST_INSERT_ID() AS dispatch_id,'REGISTERED' AS result;
END$$
-- B. El enunciado omite ruta: se resuelve por destino, desde Sincelejo.
-- Se reutiliza A para evitar duplicar validaciones y transacciones.
CREATE PROCEDURE sp_assign_dispatch_resources(IN p_order_id INT UNSIGNED,IN p_vehicle_id INT UNSIGNED,IN p_driver_id INT UNSIGNED)
BEGIN
 DECLARE v_route INT UNSIGNED;
 SELECT MIN(r.route_id) INTO v_route FROM routes r JOIN orders o ON o.destination_municipality=r.destination_municipality
 WHERE o.order_id=p_order_id AND r.origin_municipality='Sincelejo';
 IF v_route IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='No existe ruta desde Sincelejo para el pedido'; END IF;
 CALL sp_register_dispatch(p_order_id,p_vehicle_id,p_driver_id,v_route);
END$$
-- C. Cierra una entrega integral: completa el peso restante del pedido.
-- No cierra parcialmente ni libera recursos ante una entrega incompleta.
CREATE PROCEDURE sp_process_integral_delivery(IN p_dispatch_id INT UNSIGNED,IN p_received_by VARCHAR(120),OUT p_response_code INT)
main: BEGIN
 DECLARE v_order INT UNSIGNED;
 DECLARE v_vehicle INT UNSIGNED;
 DECLARE v_driver INT UNSIGNED;
 DECLARE v_status VARCHAR(32);
 DECLARE v_loaded DECIMAL(12,2);
 DECLARE v_requested DECIMAL(12,2);
 DECLARE v_delivered DECIMAL(12,2);
 DECLARE v_dispatch_delivered DECIMAL(12,2);
 DECLARE v_remaining DECIMAL(12,2);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET p_response_code=-2; END;
 SET p_response_code=-2;
 START TRANSACTION;
 SELECT order_id,vehicle_id,driver_id,dispatch_status,loaded_weight_kg INTO v_order,v_vehicle,v_driver,v_status,v_loaded
 FROM dispatch_assignments WHERE dispatch_id=p_dispatch_id FOR UPDATE;
 IF v_status IS NULL OR v_status<>'IN_TRANSIT' THEN
  ROLLBACK; SET p_response_code=-1; LEAVE main; END IF;
 SELECT total_weight_kg INTO v_requested FROM orders WHERE order_id=v_order FOR UPDATE;
 SELECT COALESCE(SUM(e.delivered_weight_kg),0) INTO v_delivered FROM deliveries e
 JOIN dispatch_assignments a ON a.dispatch_id=e.dispatch_id WHERE a.order_id=v_order AND e.delivery_status IN ('COMPLETED','PARTIAL');
 SELECT COALESCE(SUM(delivered_weight_kg),0) INTO v_dispatch_delivered FROM deliveries
 WHERE dispatch_id=p_dispatch_id AND delivery_status IN ('COMPLETED','PARTIAL');
 SET v_remaining=v_requested-v_delivered;
 IF v_remaining<=0 OR v_remaining>v_loaded-v_dispatch_delivered OR p_received_by IS NULL OR TRIM(p_received_by)='' THEN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Peso restante o receptor invalido'; END IF;
 INSERT INTO deliveries(dispatch_id,actual_delivery_date,delivered_weight_kg,delivery_status,received_by)
 VALUES(p_dispatch_id,NOW(),v_remaining,'COMPLETED',p_received_by);
 UPDATE dispatch_assignments SET dispatch_status='DELIVERED' WHERE dispatch_id=p_dispatch_id;
 UPDATE orders SET order_status='DELIVERED' WHERE order_id=v_order;
 UPDATE vehicles SET vehicle_status='AVAILABLE' WHERE vehicle_id=v_vehicle;
 UPDATE drivers SET driver_status='AVAILABLE' WHERE driver_id=v_driver;
 COMMIT; SET p_response_code=0;
END$$
DELIMITER ;
SHOW PROCEDURE STATUS WHERE Db='conectasucre_ddl';
-- Prueba sin modificar datos: despacho inexistente.
CALL sp_process_integral_delivery(999999,'Prueba',@response_code);
SELECT @response_code AS expected_minus_one;
-- Pruebas positivas MANUALES (confirman cambios). Elegir recursos libres y ruta compatible:
SELECT o.order_id,o.total_weight_kg,r.route_id,r.route_name FROM orders o JOIN routes r ON r.destination_municipality=o.destination_municipality WHERE o.order_status='PENDING' AND r.origin_municipality='Sincelejo' AND NOT EXISTS(SELECT 1 FROM dispatch_assignments a WHERE a.order_id=o.order_id AND a.dispatch_status IN ('ASSIGNED','IN_TRANSIT')) LIMIT 20;
SELECT vehicle_id,load_capacity_kg FROM vehicles WHERE vehicle_status='AVAILABLE';
SELECT driver_id FROM drivers WHERE driver_status='AVAILABLE';
-- CALL sp_register_dispatch(order_id,vehicle_id,driver_id,route_id);
-- CALL sp_assign_dispatch_resources(other_order_id,other_vehicle_id,other_driver_id);
-- CALL sp_process_integral_delivery(new_dispatch_id,'Receptor de prueba',@response_code);
-- SELECT @response_code; -- 0 exito; -1 inexistente/inactivo; -2 error tecnico o inconsistencia.
