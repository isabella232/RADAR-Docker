#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")/.."

. ../commons/lib/util.sh

echo "OS version: $(uname -a)"
check_command_exists docker
check_command_exists docker-compose

check_config_present .env etc/env.template

. ./.env

ensure_env_password HOSTNAME "Host Name is not set .env."

sudo-linux docker-compose up -d

KAFKA_TOPIC_LIST=$(docker-compose exec -T kafka-1 bash -c kafka-topics --list --bootstrap-server localhost:9092)

if [[ ! contains-element '_schemas' "${KAFKA_TOPIC_LIST[@]}" ]]; then
  KAFKA_CREATE_SCHEMA_TOPIC_COMMAND='docker exec kafka-brokers_kafka-1_1 kafka-topics --create --topic _schemas --replication-factor 3 --partitions 1 --bootstrap-server localhost:9092'
  sudo-linux docker-compose exec -T kafka-1 bash -c "${KAFKA_CREATE_SCHEMA_TOPIC_COMMAND}"
fi

KAFKA_SCHEMA_RETENTION_MS=${KAFKA_SCHEMA_RETENTION_MS:-5400000000}
KAFKA_SCHEMA_RETENTION_CMD='kafka-configs --zookeeper "${KAFKA_ZOOKEEPER_CONNECT}" --entity-type topics --entity-name _schemas --alter --add-config min.compaction.lag.ms='${KAFKA_SCHEMA_RETENTION_MS}',cleanup.policy=compact'
sudo-linux docker-compose exec -T kafka-1 bash -c "$KAFKA_SCHEMA_RETENTION_CMD"

contains-element () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}
