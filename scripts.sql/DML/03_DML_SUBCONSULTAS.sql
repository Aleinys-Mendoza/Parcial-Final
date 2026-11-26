-- ConectaSucre | 03_DML_SUBCONSULTAS | MySQL 8
USE conectasucre_ddl;

-- A. Pedidos confirmados sin ningun despacho registrado.
SELECT o.order_id, o.customer_id, o.order_date, o.total_weight_kg
FROM orders AS o
WHERE o.order_status = 'CONFIRMED'
  AND NOT EXISTS (
      SELECT 1 FROM dispatch_assignments AS da
      WHERE da.order_id = o.order_id
  )
ORDER BY o.order_id;

-- B. Conductores con entregas completadas por encima de la media.
-- La media incluye a TODOS los conductores, incluso los que tienen cero.
-- PARTIAL no equivale a COMPLETED, aunque se haya aceptado el cierre.
SELECT d.driver_id,
       CONCAT(d.first_name, ' ', d.last_name) AS driver_name,
       COUNT(e.delivery_id) AS completed_deliveries
FROM drivers AS d
LEFT JOIN dispatch_assignments AS da ON da.driver_id = d.driver_id
LEFT JOIN deliveries AS e ON e.dispatch_id = da.dispatch_id
                         AND e.delivery_status = 'COMPLETED'
GROUP BY d.driver_id, d.first_name, d.last_name
HAVING COUNT(e.delivery_id) > (
    SELECT AVG(t.completed_deliveries)
    FROM (
        SELECT d2.driver_id, COUNT(e2.delivery_id) AS completed_deliveries
        FROM drivers AS d2
        LEFT JOIN dispatch_assignments AS da2 ON da2.driver_id = d2.driver_id
        LEFT JOIN deliveries AS e2 ON e2.dispatch_id = da2.dispatch_id
                                   AND e2.delivery_status = 'COMPLETED'
        GROUP BY d2.driver_id
    ) AS t
)
ORDER BY completed_deliveries DESC, d.driver_id;

-- C. Despachos con carga superior al promedio de su tipo de vehiculo.
-- La correlacion v2.vehicle_type = v.vehicle_type evita comparar flotas
-- de capacidades y categorias distintas. Se consideran salidas efectivas
-- no canceladas, tanto en la consulta exterior como en el promedio.
SELECT da.dispatch_id, da.vehicle_id, v.vehicle_type, da.loaded_weight_kg
FROM dispatch_assignments AS da
INNER JOIN vehicles AS v ON v.vehicle_id = da.vehicle_id
WHERE da.departure_date <= NOW()
  AND da.dispatch_status IN ('IN_TRANSIT', 'DELIVERED')
  AND da.loaded_weight_kg > (
      SELECT AVG(da2.loaded_weight_kg)
      FROM dispatch_assignments AS da2
      INNER JOIN vehicles AS v2 ON v2.vehicle_id = da2.vehicle_id
      WHERE v2.vehicle_type = v.vehicle_type
        AND da2.departure_date <= NOW()
        AND da2.dispatch_status IN ('IN_TRANSIT', 'DELIVERED')
  )
ORDER BY v.vehicle_type, da.loaded_weight_kg DESC, da.dispatch_id;
