#!/usr/bin/env bash
set -e

DB="conectasucre_ddl"
echo "Importando DDL/DML de ConectaSucre en MySQL..."

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${DB}" < /scripts/DDL/DDL_A.sql
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${DB}" < /scripts/DDL/DDL_B.sql
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${DB}" < /scripts/DDL/DDL_C.sql
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${DB}" < /scripts/DATASET/INSERT_DATA.sql

# Objetos adicionales (vistas, funciones, procedimientos, triggers)
for f in /scripts/view/*.sql /scripts/Stored\ Functions/*.sql /scripts/Stored\ Procedures/*.sql /scripts/TRIGGER/*.sql; do
  [ -f "$f" ] && mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${DB}" < "$f"
done

echo "Carga SQL finalizada."
