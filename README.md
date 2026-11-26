# ConectaSucre — Bases de datos (SQL + NoSQL)

Repositorio con el modelo de datos de ConectaSucre:
- **SQL (MySQL 8.0)**: esquema relacional `conectasucre_ddl` con DDL, DML, vistas, funciones, procedimientos y triggers.
- **NoSQL (MongoDB 7)**: colección `tracking_events` en la base `conectasucre_nosql`.

## Requisitos
- Docker 20+ (y Docker Compose si se desea usar `docker-compose.yml`).
- Puertos libres `3306` (MySQL) y `27017` (MongoDB) o configurar `MYSQL_PORT` / `MONGO_PORT`.

## Inicio rápido

### Con Docker Compose
```bash
cp .env.example .env
docker compose up -d
```

### Sin Docker Compose (manual)
```bash
# MySQL
docker run -d --name conectasucre-mysql \
  -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=conectasucre_ddl \
  -p 3306:3306 \
  -v "$(pwd)/scripts.sql:/scripts:ro" \
  -v "$(pwd)/docker/mysql/init:/docker-entrypoint-initdb.d:ro" \
  mysql:8.0

# MongoDB
docker run -d --name conectasucre-mongo \
  -p 27017:27017 \
  -v "$(pwd)/nosql:/seed:ro" \
  -v "$(pwd)/docker/mongo/init:/docker-entrypoint-initdb.d:ro" \
  mongo:7
```

## Conexiones
- MySQL: `mysql -h 127.0.0.1 -P 3306 -u root -p` (DB `conectasucre_ddl`)
- MongoDB: `mongodb://127.0.0.1:27017/conectasucre_nosql`

## Estructura
- `scripts.sql/` — DDL (A/B/C), DML, vistas, funciones, procedimientos, triggers, dataset.
- `nosql/` — JSON extendido y documentación NoSQL.
- `docker/` — scripts de inicialización para los contenedores.
- `docs/` — documentación de implementación.
- `migracion/` — migración a Railway PostgreSQL.

## Documentación
- `docs/IMPLEMENTACION_SQL.md`
- `docs/IMPLEMENTACION_NOSQL.md`
- `migracion/MIGRACION_RAILWAY.md`
