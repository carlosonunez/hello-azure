#!/usr/bin/env sh
PACKER_TEMPLATE="${1?Please provide the name of the Packer template to process.}"

if ! test -f secrets/packer_resource_group
then
  docker-compose run --rm terraform apply -target=azurerm_resource_group.packer || exit 1
fi
docker-compose run -e PACKER_RESOURCE_GROUP=$(cat secrets/packer_resource_group) \
  -e IMAGE_TO_BUILD=$IMAGE_TO_BUILD \
  --rm packer "$PACKER_TEMPLATE"
