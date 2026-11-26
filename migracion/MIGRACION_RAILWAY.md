# Migración de base de datos: MySQL (local) → Railway PostgreSQL

## Resumen
Se migró la base de datos `conectasucre_ddl` (MySQL 8.0.46, local) a PostgreSQL en Railway.
Resultado final: 12 tablas en schema `public`, 1962 filas, 12 PK, 14 FK, 33 índices, secuencias reseteadas.

## Entorno y herramientas
- OS: Ubuntu 24.04 (Linux)
- MySQL local: `127.0.0.1:3306`, usuario `root` / `migration_user`
- Railway PostgreSQL: `crossover.proxy.rlwy.net:13876`, DB `railway`, usuario `postgres`
- pgloader: `3.6.7~devel` (binario extraído de `.deb` en `/tmp/scratchpad/pgloader/usr/bin/pgloader`)
- Docker: `29.1.3` (para MySQL 5.7 temporal)
- Python: `pg8000 1.31.6`, `PyMySQL 2.2.8` (verificación y ajustes)
- OpenSSL: `3.0.13`

## Archivos relevantes
- `/home/vanessa/ConectaSucre/migration/migration.load` — configuración pgloader (origen/destino).
- `/home/vanessa/ConectaSucre/migration/conectasucre_backup.sql` — dump MySQL original.
- `/home/vanessa/ConectaSucre/migration/railway-ca.pem` — CA autofirmada de Railway (para SSL).

## 1. Error de certificado SSL (PostgreSQL Railway)
Al conectar pgloader a Railway se obtuvo:
```
SSL verify error: 19 X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN
```
Causa: el proxy de Railway presenta un certificado emitido por la CA autofirmada `root-ca` (CN `localhost`), no confiada por defecto.

Se extrajo la CA desde el servidor:
```bash
openssl s_client -connect crossover.proxy.rlwy.net:13876 -showcerts </dev/null \
  | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > /tmp/scratchpad/server.pem
```
Se separó el certificado raíz (`root-ca`) y se guardó como:
```bash
/home/vanessa/ConectaSucre/migration/railway-ca.pem
```
La migración se ejecutó con:
```bash
SSL_CERT_FILE=/home/vanessa/ConectaSucre/migration/railway-ca.pem pgloader ...
```

## 2. Error de autenticación MySQL (pgloader vs MySQL 8)
pgloader falló con:
```
Condition QMYND:MYSQL-UNSUPPORTED-AUTHENTICATION
```
pgloader no soporta el handshake de MySQL 8. Solución: usar un MySQL 5.7 temporal en Docker.

### 2.1 Dump de tablas (sin rutinas/triggers)
```bash
TABLES="customers deliveries dispatch_assignments dispatch_audits drivers incidents order_details orders producers products routes vehicles"
mysqldump -u root -proot --skip-triggers --single-transaction \
  --default-character-set=utf8mb4 conectasucre_ddl $TABLES \
  | sed 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g' \
  > /tmp/scratchpad/dump_tables.sql
```

### 2.2 Contenedor MySQL 5.7
```bash
echo 'Aleinis2006' | sudo -S docker pull mysql:5.7
echo 'Aleinis2006' | sudo -S docker run -d --name mysql57 \
  -e MYSQL_ROOT_PASSWORD=root -p 3307:3306 mysql:5.7

mysql -h 127.0.0.1 -P 3307 -u root -proot \
  -e "DROP DATABASE IF EXISTS conectasucre_ddl; CREATE DATABASE conectasucre_ddl;"
mysql -h 127.0.0.1 -P 3307 -u root -proot conectasucre_ddl \
  < /tmp/scratchpad/dump_tables.sql
```

## 3. Configuración pgloader (`migration.load`)
```sql
LOAD DATABASE
    FROM mysql://root:root@127.0.0.1:3307/conectasucre_ddl
    INTO postgresql://postgres:<PASSWORD>@crossover.proxy.rlwy.net:13876/railway?sslmode=require

WITH create tables,
     create indexes,
     reset sequences,
     foreign keys

SET work_mem to '16MB',
    maintenance_work_mem to '64MB';
```
Nota: se eliminó `include no drop` para forzar la creación de PK/FK/índices.

## 4. Ejecución de la migración
```bash
cd /tmp/scratchpad
SSL_CERT_FILE=/home/vanessa/ConectaSucre/migration/railway-ca.pem \
  /tmp/scratchpad/pgloader/usr/bin/pgloader migration_nodropless.load
```
Resultado:
```
fetch meta data          0   59
Create tables            0   24
Create Indexes           0   33
Reset Sequences          0   12
Primary Keys             0   12
Create Foreign Keys      0   14
Total import time        ✓ 1962  136.9 kB
```

## 5. Ajustes finales en Railway
Las tablas se crearon inicialmente en schema `conectasucre_ddl`. Para compatibilidad con clientes por defecto (`public`), se movieron:
```sql
ALTER TABLE conectasucre_ddl.<tabla> SET SCHEMA public;
DROP SCHEMA conectasucre_ddl CASCADE;
ALTER DATABASE railway RESET search_path;
```
Verificación (conteos):
- customers: 200
- deliveries: 220
- dispatch_assignments: 252
- dispatch_audits: 0
- drivers: 25
- incidents: 200
- order_details: 600
- orders: 300
- producers: 30
- products: 100
- routes: 15
- vehicles: 20

Constraints finales en `public`: 12 PK, 14 FK, 77 CHECK, 33 índices.

## 6. Limpieza
```bash
echo 'Aleinis2006' | sudo -S docker rm -f mysql57
```

## Notas
- Vistas MySQL (`v_delivery_compliance_kpi`, `v_pending_orders`, `v_route_delivery_monitor`) no se migraron (el load solo incluyó tablas).
- Rutinas/procedimientos almacenados no se migraron.
- La contraseña de Postgres en `migration.load` debe mantenerse segura (no commitear).
```
Write to /home/vanessa/ConectaSucre/MIGRACION_RAILWAY.md