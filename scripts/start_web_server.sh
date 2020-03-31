#!/usr/bin/env sh
wait_for_dependencies() {
  max_seconds_to_wait=60
  seconds_elapsed=0
  for service in graf_database prom_database graf_cache database blobstore
  do
    if ! docker-compose ps "$service" | grep -q "Up"
    then
      >&2 echo "ERROR: $service failed to start."
      exit 1
    fi
  done

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

docker-compose up -d database blobstore graf_database graf_cache prom_database && \
  wait_for_dependencies && \
  docker-compose run --service-ports --rm init-database && \
  docker-compose run --service-ports --rm init-blobstore && \
  docker-compose run --service-ports --rm grafana prometheus && \
  docker-compose build hello-azure && \
  docker-compose run --service-ports --rm hello-azure
