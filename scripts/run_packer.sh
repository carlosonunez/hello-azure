#!/usr/bin/env sh
PACKER_TEMPLATE="${1?Please provide the name of the Packer template to process.}"
IMAGE_TO_BUILD="${2?Please provide the type of image to build}"

check_for_test() {
  test -f "infra/${IMAGE_TO_BUILD}_test.yml"
}

if ! check_for_test
then
  >&2 echo "ERROR: ${IMAGE_TO_BUILD} does not have a corresponding test."
  exit 1
fi

if ! test -f secrets/packer_resource_group
then
  docker-compose run --rm terraform apply -target=azurerm_resource_group.packer || exit 1
fi
docker-compose run -e PACKER_RESOURCE_GROUP=$(cat secrets/packer_resource_group) \
  -e IMAGE_TO_BUILD=$IMAGE_TO_BUILD \
  --rm packer "$PACKER_TEMPLATE" && \
docker-compose run --rm terraform destroy -target=azurerm_resource_group.packer
