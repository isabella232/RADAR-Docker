#!/bin/bash

set -e

. ./util.sh

. ./.env

POSTGRES_NEW_DIR="${MP_POSTGRES_DIR}/data-${POSTGRES_NEW_VERSION}"

echo "Migrating ManagementPortal database to ${POSTGRES_NEW_VERSION}"
if [ -e "${POSTGRES_NEW_DIR}" ]; then
  echo "Please remove old temporary directory $POSTGRES_NEW_DIR before proceeding"
  exit 1
fi

POSTGRES_NEW=$(docker run -d -v "${POSTGRES_NEW_DIR}/:/var/lib/postgresql/data" --env-file ./.env postgres:"${POSTGRES_NEW_VERSION}")
sleep 5

docker-compose exec managementportal-postgresql pg_dumpall -U "${POSTGRES_USER}" \
  | docker exec -i ${POSTGRES_NEW} psql -U "${POSTGRES_USER}"

docker rm -vf "${POSTGRES_NEW}"

echo "Stopping postgres..."
docker-compose stop managementportal-postgresql
docker-compose rm -vf managementportal-postgresql

echo "Moving dumped data to new volume"
mv "${MP_POSTGRES_DIR}/data/" "${MP_POSTGRES_DIR}/data-backup-$(date +%FT%TZ)/"
mv "${POSTGRES_NEW_DIR}" "${MP_POSTGRES_DIR}/data/"

# change postgres version
sed_i 's| image: postgres:.*| image: postgres:${POSTGRES_NEW_VERSION}|' docker-compose.yml

echo "Starting postgres..."

docker-compose up -d managementportal-postgresql


