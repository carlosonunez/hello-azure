#!/usr/bin/env sh
PERSISTENCE_SERVICES="blobstore database graf_database prom_database graf_cache"
MONITORING_SERVICES="grafana prometheus"
INIT_SERVICES="init-database init-blobstore"
PROMETHEUS_PORT=$(get_exposed_port "prometheus")
GRAFANA_PORT=$(get_exposed_port "grafana")

get_exposed_port() {
  if ! which yq > /dev/null
  then
    >&2 echo "ERROR: yq not installed."
    exit 1
  fi
  docker-compose config | yq -r '.services | \
    to_entries | \
    .[] | select(.key == "prometheus") | \
    .value.ports[0]' | \
    cut -f1 -d ':'
}

ensure_persistence_started() {
  for service in "$PERSISTENCE_SERVICES"
  do
    if ! docker-compose ps "$service" | grep -q "Up"
    then
      >&2 echo "ERROR: $service failed to start."
      exit 1
    fi
  done
}

ensure_monitoring_started() {
  for service in "$MONITORING_SERVICES"
  do
    if ! docker-compose ps "$service" | grep -q "Up"
    then
      >&2 echo "ERROR: $service failed to start."
      exit 1
    fi
  done
}

wait_for_persistence() {
  max_seconds_to_wait=60
  seconds_elapsed=0
  while true
  do
    docker-compose --log-level INFO run --service-ports --rm graf_network_check && \
      docker-compose --log-level INFO run --service-ports --rm prom_network_check && \
      docker-compose --log-level INFO run --service-ports --rm app_network_check && \
      break
    sleep 1
    if [ "$seconds_elapsed" == "$max_seconds_to_wait" ]
    then
      >&2 echo "ERROR: Timed out while waiting for network deps to start."
      return 1
    fi
    seconds_elapsed=$((seconds_elapsed+1))
  done
}

wait_for_monitoring() {
  max_seconds_to_wait=60
  seconds_elapsed=0
  while true
  do
    nc -z "$(get_exposed_port "prometheus")" && \
      nc -z "$(get_exposed_port "grafana")" && \
      break
    sleep 1
    if [ "$seconds_elapsed" == "$max_seconds_to_wait" ]
    then
      >&2 echo "ERROR: Timed out while waiting for monitoring to start."
      return 1
    fi
    seconds_elapsed=$((seconds_elapsed+1))
  done
}

docker-compose up -d "$PERSISTENCE_SERVICES" && \
  ensure_persistence_started && \
  wait_for_persistence && \
  docker-compose up -d "$MONITORING_SERVICES" && \
  ensure_monitoring_started && \
  wait_for_monitoring && \
  docker-compose run --service-ports --rm "$INIT_SERVICES" && \
  docker-compose up --build -d hello-azure
