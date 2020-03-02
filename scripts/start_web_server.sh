#!/usr/bin/env sh

docker-compose up -d database blobstore && \
  docker-compose run --service-port --rm init-database && \
  docker-compose run --service-port --rm init-blobstore && \
  docker-compose up hello-azure
