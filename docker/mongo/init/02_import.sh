#!/usr/bin/env bash
set -e
echo "Importando tracking_events en MongoDB..."
mongoimport --db conectasucre_nosql --collection tracking_events \
  --file /seed/02_TRACKING_EVENTS.json --jsonArray
echo "Carga NoSQL finalizada."
