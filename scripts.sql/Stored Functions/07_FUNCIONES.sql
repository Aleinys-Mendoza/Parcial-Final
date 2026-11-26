-- ConectaSucre | MySQL 8 | Funciones A, B y C
USE conectasucre_ddl;
DROP FUNCTION IF EXISTS fn_calculate_order_delay_days;
DROP FUNCTION IF EXISTS fn_driver_compliance_rate;
DROP FUNCTION IF EXISTS fn_evaluate_freight_penalty;
DELIMITER $$
-- A. Dias calendario de retraso; pedido inexistente devuelve cero.
CREATE FUNCTION fn_calculate_order_delay_days(p_order_id INT UNSIGNED)
RETURNS INT NOT DETERMINISTIC READS SQL DATA
BEGIN
 DECLARE v_promised DATETIME;
 DECLARE v_actual DATETIME;
 DECLARE v_status VARCHAR(32);
 SELECT MAX(promised_delivery_date),MAX(order_status) INTO v_promised,v_status
 FROM orders WHERE order_id=p_order_id;
 IF v_promised IS NULL OR v_status='CANCELLED' THEN RETURN 0; END IF;
 IF v_status='DELIVERED' THEN
  SELECT MAX(e.actual_delivery_date) INTO v_actual FROM deliveries e
  JOIN dispatch_assignments a ON a.dispatch_id=e.dispatch_id
  WHERE a.order_id=p_order_id AND e.delivery_status IN ('COMPLETED','PARTIAL');
 END IF;
 RETURN GREATEST(0,DATEDIFF(COALESCE(v_actual,CURRENT_DATE),v_promised));
END$$
-- B. Porcentaje de entregas COMPLETED puntuales; sin entregas devuelve cero.
CREATE FUNCTION fn_driver_compliance_rate(p_driver_id INT UNSIGNED)
RETURNS DECIMAL(5,2) NOT DETERMINISTIC READS SQL DATA
BEGIN
 DECLARE v_rate DECIMAL(5,2);
 SELECT COALESCE(ROUND(100*SUM(e.actual_delivery_date<=o.promised_delivery_date)/NULLIF(COUNT(*),0),2),0)
 INTO v_rate FROM deliveries e JOIN dispatch_assignments a ON a.dispatch_id=e.dispatch_id
 JOIN orders o ON o.order_id=a.order_id
 WHERE a.driver_id=p_driver_id AND e.delivery_status='COMPLETED';
 RETURN v_rate;
END$$
-- C. Penalizacion propuesta: 10% si demora imputable supera 1440 minutos.
-- Se suman novedades atribuibles al despacho o a sus entregas; no se imputan
-- novedades de una ruta sin vinculo especifico. Se asumen demoras no solapadas.
CREATE FUNCTION fn_evaluate_freight_penalty(p_dispatch_id INT UNSIGNED)
RETURNS DECIMAL(12,2) NOT DETERMINISTIC READS SQL DATA
BEGIN
 DECLARE v_freight DECIMAL(12,2);
 DECLARE v_delay BIGINT DEFAULT 0;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION RETURN -1;
 SELECT MAX(freight_amount) INTO v_freight FROM dispatch_assignments WHERE dispatch_id=p_dispatch_id;
 IF v_freight IS NULL THEN RETURN -1; END IF;
 SELECT COALESCE(SUM(i.delay_minutes),0) INTO v_delay FROM incidents i
 LEFT JOIN deliveries e ON e.delivery_id=i.delivery_id
 WHERE i.company_responsible=TRUE AND (i.dispatch_id=p_dispatch_id OR e.dispatch_id=p_dispatch_id);
 RETURN IF(v_delay>1440,ROUND(v_freight*0.10,2),0);
END$$
DELIMITER ;
SELECT order_id,fn_calculate_order_delay_days(order_id) AS delay_days FROM orders LIMIT 20;
SELECT driver_id,fn_driver_compliance_rate(driver_id) AS compliance_pct FROM drivers;
SELECT dispatch_id,fn_evaluate_freight_penalty(dispatch_id) AS penalty_cop FROM dispatch_assignments WHERE fn_evaluate_freight_penalty(dispatch_id)>0;
SELECT fn_calculate_order_delay_days(999999) AS missing_order,fn_driver_compliance_rate(999999) AS missing_driver,fn_evaluate_freight_penalty(999999) AS missing_dispatch;
