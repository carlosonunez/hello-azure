#!/usr/bin/env sh

docker-compose up -d database blobstore && \
  docker-compose run --service-ports --rm init-database && \
  docker-compose run --service-ports --rm init-blobstore && \
  docker-compose build hello-azure && \
  docker-compose run --service-ports --rm hello-azure
