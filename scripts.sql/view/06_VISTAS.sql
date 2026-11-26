-- ConectaSucre | MySQL 8 | Vistas A, B y C
USE conectasucre_ddl;

-- A. Pedidos pendientes o en preparacion.
CREATE OR REPLACE VIEW v_pending_orders AS
SELECT o.order_id, c.business_name AS customer_name,
       o.destination_municipality, o.total_weight_kg, o.order_date,
       DATEDIFF(CURRENT_DATE, o.order_date) AS elapsed_days
FROM orders o JOIN customers c ON c.customer_id=o.customer_id
WHERE o.order_status IN ('PENDING','IN_PREPARATION');

-- B. Monitoreo: una fila por entrega; conserva despachos sin entrega.
CREATE OR REPLACE VIEW v_route_delivery_monitor AS
SELECT a.dispatch_id, c.business_name AS customer_name, r.route_name,
       v.license_plate, CONCAT(d.first_name,' ',d.last_name) AS driver_name,
       a.departure_date, COALESCE(e.delivery_status,'PENDING') AS delivery_status
FROM dispatch_assignments a JOIN orders o ON o.order_id=a.order_id
JOIN customers c ON c.customer_id=o.customer_id
JOIN vehicles v ON v.vehicle_id=a.vehicle_id
JOIN drivers d ON d.driver_id=a.driver_id
JOIN routes r ON r.route_id=a.route_id
LEFT JOIN deliveries e ON e.dispatch_id=a.dispatch_id;

-- C. KPI mensual por cliente: un envio por despacho finalizado.
-- Fecha real = ultima entrega efectiva; mes de la entrega.
CREATE OR REPLACE VIEW v_delivery_compliance_kpi AS
SELECT k.*, CASE WHEN compliance_pct >= 90 THEN 'EXCELLENT'
                 WHEN compliance_pct >= 75 THEN 'ACCEPTABLE'
                 ELSE 'CRITICAL' END AS service_classification
FROM (
 SELECT c.customer_id,c.business_name AS customer_name,
        YEAR(e.actual_date) AS delivery_year, MONTH(e.actual_date) AS delivery_month,
        COUNT(*) AS total_shipments,
        SUM(e.actual_date<=o.promised_delivery_date) AS on_time_shipments,
        SUM(e.actual_date>o.promised_delivery_date) AS late_shipments,
        ROUND(100*SUM(e.actual_date<=o.promised_delivery_date)/COUNT(*),2) AS compliance_pct
 FROM dispatch_assignments a JOIN orders o ON o.order_id=a.order_id
 JOIN customers c ON c.customer_id=o.customer_id
 JOIN (SELECT dispatch_id,MAX(actual_delivery_date) AS actual_date FROM deliveries
       WHERE delivery_status IN ('COMPLETED','PARTIAL') GROUP BY dispatch_id) e
 ON e.dispatch_id=a.dispatch_id
 WHERE a.dispatch_status='DELIVERED'
 GROUP BY c.customer_id,c.business_name,YEAR(e.actual_date),MONTH(e.actual_date)
) k;

-- Pruebas de lectura.
SELECT * FROM v_pending_orders LIMIT 20;
SELECT * FROM v_route_delivery_monitor LIMIT 20;
SELECT * FROM v_delivery_compliance_kpi ORDER BY delivery_year DESC,delivery_month DESC,compliance_pct LIMIT 30;
