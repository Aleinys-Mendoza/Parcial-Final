-- ConectaSucre | MySQL 8 | Triggers A, B y C + auditoria de cancelaciones
USE conectasucre_ddl;
DROP TRIGGER IF EXISTS trg_update_order_dispatch_status;
DROP TRIGGER IF EXISTS trg_prevent_double_vehicle_assignment;
DROP TRIGGER IF EXISTS trg_audit_dispatch_changes;
DROP TRIGGER IF EXISTS trg_audit_delivery_cancellation;
DELIMITER $$
-- B. Serializa reservas por pedido, vehiculo y conductor con bloqueos.
-- Los recursos se reservan aqui tambien si se usa INSERT directo.
CREATE TRIGGER trg_prevent_double_vehicle_assignment BEFORE INSERT ON dispatch_assignments
FOR EACH ROW
BEGIN
 DECLARE v_order_status VARCHAR(32);
 DECLARE v_vehicle_status VARCHAR(32);
 DECLARE v_driver_status VARCHAR(32);
 DECLARE v_capacity DECIMAL(12,2);
 IF NEW.dispatch_status IN ('ASSIGNED','IN_TRANSIT') THEN
  SELECT order_status INTO v_order_status FROM orders WHERE order_id=NEW.order_id FOR UPDATE;
  SELECT vehicle_status,load_capacity_kg INTO v_vehicle_status,v_capacity FROM vehicles WHERE vehicle_id=NEW.vehicle_id FOR UPDATE;
  SELECT driver_status INTO v_driver_status FROM drivers WHERE driver_id=NEW.driver_id FOR UPDATE;
  IF v_order_status IS NULL OR v_order_status IN ('IN_TRANSIT','DELIVERED','CANCELLED') OR
     v_vehicle_status IS NULL OR v_vehicle_status<>'AVAILABLE' OR v_driver_status IS NULL OR v_driver_status<>'AVAILABLE' OR
     EXISTS(SELECT 1 FROM dispatch_assignments a WHERE a.dispatch_status IN ('ASSIGNED','IN_TRANSIT')
       AND (a.vehicle_id=NEW.vehicle_id OR a.driver_id=NEW.driver_id OR a.order_id=NEW.order_id)) THEN
   SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pedido, vehiculo o conductor con asignacion incompatible';
  END IF;
  IF NEW.loaded_weight_kg>v_capacity THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Capacidad de carga excedida'; END IF;
  UPDATE vehicles SET vehicle_status='ON_ROUTE' WHERE vehicle_id=NEW.vehicle_id;
  UPDATE drivers SET driver_status='ON_ROUTE' WHERE driver_id=NEW.driver_id;
 END IF;
END$$
-- A. Actualiza automaticamente el pedido al insertar un despacho operativo.
-- Se limita a estados activos para no reabrir pedidos al importar historicos.
CREATE TRIGGER trg_update_order_dispatch_status AFTER INSERT ON dispatch_assignments
FOR EACH ROW
BEGIN
 IF NEW.dispatch_status IN ('ASSIGNED','IN_TRANSIT') THEN
  UPDATE orders SET order_status='IN_TRANSIT' WHERE order_id=NEW.order_id;
 END IF;
END$$
-- C. Audita solamente cambios de estado (USER identifica la sesion).
CREATE TRIGGER trg_audit_dispatch_changes AFTER UPDATE ON dispatch_assignments
FOR EACH ROW
BEGIN
 IF OLD.dispatch_status<>NEW.dispatch_status THEN
  INSERT INTO dispatch_audits(dispatch_id, database_user,previous_status,new_status,observation)
  VALUES(NEW.dispatch_id,USER(),OLD.dispatch_status,NEW.dispatch_status,'Dispatch status changed');
 END IF;
END$$
-- Complemento C: cancelacion de entregas en la misma tabla de auditoria.
CREATE TRIGGER trg_audit_delivery_cancellation AFTER UPDATE ON deliveries
FOR EACH ROW
BEGIN
 IF OLD.delivery_status<>NEW.delivery_status AND NEW.delivery_status='CANCELLED' THEN
  INSERT INTO dispatch_audits(dispatch_id,delivery_id,database_user,previous_status,new_status,observation)
  VALUES(NEW.dispatch_id,NEW.delivery_id,USER(),OLD.delivery_status,NEW.delivery_status,'Delivery cancelled');
 END IF;
END$$
DELIMITER ;
SHOW TRIGGERS FROM conectasucre_ddl;
-- Prueba C sin cambios permanentes. Elegir un despacho activo.
START TRANSACTION;
SET @test_dispatch=(SELECT MIN(dispatch_id) FROM dispatch_assignments WHERE dispatch_status='ASSIGNED');
UPDATE dispatch_assignments SET dispatch_status='IN_TRANSIT' WHERE dispatch_id=@test_dispatch;
SELECT * FROM dispatch_audits WHERE dispatch_id=@test_dispatch ORDER BY audit_id DESC;
ROLLBACK;
-- Pruebas A y B manuales: CALL sp_register_dispatch con pedido pendiente y recursos libres.
-- Comprobar el estado del pedido; luego intentar INSERT directo con ese mismo vehiculo
-- en otro pedido pendiente (debe fallar con SQLSTATE 45000).
-- Para probar auditoria persistente: finalizar despacho con sp_process_integral_delivery.
-- Nota: las reasignaciones directas por UPDATE no se cubren con el trigger BEFORE INSERT;
-- usar los procedimientos para cambios operativos. No manipular los estados manualmente.

-- Prueba A reversible: seleccionar recursos disponibles y pedido pendiente compatible.
START TRANSACTION;
SET @test_order=NULL,@test_vehicle=NULL,@test_driver=NULL,@test_route=NULL,@test_weight=NULL;
SELECT o.order_id,v.vehicle_id,d.driver_id,r.route_id,o.total_weight_kg
INTO @test_order,@test_vehicle,@test_driver,@test_route,@test_weight
FROM orders o JOIN routes r ON r.destination_municipality=o.destination_municipality
JOIN vehicles v ON v.load_capacity_kg>=o.total_weight_kg AND v.vehicle_status='AVAILABLE'
JOIN drivers d ON d.driver_status='AVAILABLE'
WHERE o.order_status='PENDING' AND o.total_weight_kg>0 AND r.origin_municipality='Sincelejo'
AND NOT EXISTS(SELECT 1 FROM dispatch_assignments a WHERE a.dispatch_status IN ('ASSIGNED','IN_TRANSIT') AND (a.order_id=o.order_id OR a.vehicle_id=v.vehicle_id OR a.driver_id=d.driver_id))
ORDER BY o.order_id,v.vehicle_id,d.driver_id,r.route_id LIMIT 1;
INSERT INTO dispatch_assignments(order_id,vehicle_id,driver_id,route_id,dispatch_status,departure_date,loaded_weight_kg,freight_amount)
SELECT @test_order,@test_vehicle,@test_driver,@test_route,'IN_TRANSIT',NOW(),@test_weight,50000 WHERE @test_order IS NOT NULL;
SELECT order_id,order_status FROM orders WHERE order_id=@test_order;
-- Prueba B (ejecutar manualmente ANTES del ROLLBACK si se desea probar el rechazo):
-- INSERT INTO dispatch_assignments(order_id,vehicle_id,driver_id,route_id,dispatch_status,loaded_weight_kg,freight_amount)
-- VALUES(@test_order,@test_vehicle,@test_driver,@test_route,'IN_TRANSIT',@test_weight,50000);
ROLLBACK;

-- Prueba adicional de cancelacion, reversible.
START TRANSACTION;
SET @test_delivery=(SELECT MIN(delivery_id) FROM deliveries WHERE delivery_status='COMPLETED');
UPDATE deliveries SET delivery_status='CANCELLED' WHERE delivery_id=@test_delivery;
SELECT * FROM dispatch_audits WHERE delivery_id=@test_delivery ORDER BY audit_id DESC;
ROLLBACK;
