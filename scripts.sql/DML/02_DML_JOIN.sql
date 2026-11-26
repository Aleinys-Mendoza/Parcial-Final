-- ConectaSucre | 02_DML_JOIN | MySQL 8
USE conectasucre_ddl;

-- A. Rastreo de pedidos. LEFT JOIN conserva pedidos sin despacho.
-- Si existen varios despachos historicos, se muestran por separado.
SELECT c.business_name AS customer_name,
       c.municipality AS municipality,
       o.order_id AS order_number,
       o.order_date,
       o.promised_delivery_date,
       COALESCE(da.dispatch_status, 'NOT_ASSIGNED') AS dispatch_status
FROM customers AS c
INNER JOIN orders AS o ON o.customer_id = c.customer_id
LEFT JOIN dispatch_assignments AS da ON da.order_id = o.order_id
ORDER BY o.order_id, da.assignment_date, da.dispatch_id;

-- B. Carga transportada por conductor durante el ultimo mes movil.
-- Se usa la salida efectiva y el peso cargado, no el peso solicitado.
-- Cada despacho equivale a un viaje en nuestro modelo sin Trip.
SELECT YEAR(da.departure_date) AS dispatch_year,
       MONTH(da.departure_date) AS dispatch_month,
       CONCAT(d.first_name, ' ', d.last_name) AS driver_name,
       COUNT(DISTINCT o.order_id) AS dispatched_orders,
       SUM(da.loaded_weight_kg) AS total_weight_kg,
       ROUND(AVG(da.loaded_weight_kg), 2) AS average_weight_per_trip_kg
FROM drivers AS d
INNER JOIN dispatch_assignments AS da ON da.driver_id = d.driver_id
INNER JOIN orders AS o ON o.order_id = da.order_id
WHERE da.departure_date >= NOW() - INTERVAL 1 MONTH
  AND da.departure_date <= NOW()
  AND da.dispatch_status IN ('IN_TRANSIT', 'DELIVERED')
GROUP BY YEAR(da.departure_date), MONTH(da.departure_date),
         d.driver_id, d.first_name, d.last_name
ORDER BY total_weight_kg DESC, d.driver_id;

-- C. Cumplimiento de carga y tiempo (OTIF), ultimo trimestre movil.
-- Se acumulan las entregas efectivas por despacho, sin multiplicar pesos.
-- Se usa la ultima entrega efectiva como fecha real del despacho.
-- El porcentaje se compara con el peso solicitado del pedido.
SELECT da.dispatch_id, o.order_id,
       CONCAT(d.first_name, ' ', d.last_name) AS driver_name,
       r.route_name,
       o.total_weight_kg AS requested_weight_kg,
       SUM(e.delivered_weight_kg) AS delivered_weight_kg,
       o.promised_delivery_date,
       MAX(e.actual_delivery_date) AS actual_delivery_date,
       ROUND(100 * SUM(e.delivered_weight_kg) / NULLIF(o.total_weight_kg, 0), 2) AS load_compliance_pct,
       TIMESTAMPDIFF(MINUTE, o.promised_delivery_date, MAX(e.actual_delivery_date)) AS time_deviation_minutes,
       CASE WHEN MAX(e.actual_delivery_date) <= o.promised_delivery_date
                  AND SUM(e.delivered_weight_kg) >= o.total_weight_kg
            THEN 'YES' ELSE 'NO' END AS otif
FROM orders AS o
INNER JOIN dispatch_assignments AS da ON da.order_id = o.order_id
INNER JOIN routes AS r ON r.route_id = da.route_id
INNER JOIN drivers AS d ON d.driver_id = da.driver_id
INNER JOIN deliveries AS e ON e.dispatch_id = da.dispatch_id
WHERE e.delivery_status IN ('COMPLETED', 'PARTIAL')
  AND e.actual_delivery_date <= NOW()
GROUP BY da.dispatch_id, o.order_id, d.first_name, d.last_name,
         r.route_name, o.total_weight_kg, o.promised_delivery_date
HAVING MAX(e.actual_delivery_date) >= NOW() - INTERVAL 3 MONTH
ORDER BY time_deviation_minutes DESC, da.dispatch_id;

-- Complemento de la rubrica general: funcion de ventana OVER.
-- Ranking de carga transportada por conductor dentro de cada mes.
WITH monthly_load AS (
    SELECT YEAR(da.departure_date) AS dispatch_year,
           MONTH(da.departure_date) AS dispatch_month,
           d.driver_id, CONCAT(d.first_name, ' ', d.last_name) AS driver_name,
           SUM(da.loaded_weight_kg) AS total_weight_kg
    FROM drivers AS d
    INNER JOIN dispatch_assignments AS da ON da.driver_id = d.driver_id
    WHERE da.departure_date >= NOW() - INTERVAL 1 MONTH
      AND da.departure_date <= NOW()
      AND da.dispatch_status IN ('IN_TRANSIT', 'DELIVERED')
    GROUP BY YEAR(da.departure_date), MONTH(da.departure_date),
             d.driver_id, d.first_name, d.last_name
)
SELECT monthly_load.*,
       DENSE_RANK() OVER (PARTITION BY dispatch_year, dispatch_month
                          ORDER BY total_weight_kg DESC) AS monthly_rank
FROM monthly_load
ORDER BY dispatch_year DESC, dispatch_month DESC, monthly_rank, driver_id;
