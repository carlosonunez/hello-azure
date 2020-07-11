#!/usr/bin/env bash
#vim: set ft=sh:
TOPLEVEL=$(git rev-parse --show-toplevel)
DEFAULT_DOCKER_REGISTRY_LOCATION=10.0.2.2:5000
DOCKER_REGISTRY_LOCATION="${DOCKER_REGISTRY_LOCATION:-$DEFAULT_DOCKER_REGISTRY_LOCATION}"
DOCKER_IMAGE_NAME="hello-azure"
HELM_CHART_NAME="hello-azure"

provision_local_k3s_cluster_and_registry() {
  sh "$TOPLEVEL/scripts/deploy_k3s"
}

build_docker_image() {
  docker build -t "$DOCKER_IMAGE_NAME" "$TOPLEVEL/hello_azure_app"
  docker tag "$DOCKER_IMAGE_NAME" "${DOCKER_REGISTRY_LOCATION}/${DOCKER_IMAGE_NAME}"
}

push_into_private_registry() {
  docker push "${DOCKER_REGISTRY_LOCATION}/${DOCKER_IMAGE_NAME}"
}

deploy_helm_chart() {
  helm --kubeconfig=/tmp/k3s-kubeconfig install "$HELM_CHART_NAME" "${TOPLEVEL}/helm/hello-azure"
}

if ! (provision_local_k3s_cluster_and_registry &&
  build_docker_image &&
  push_into_private_registry &&
  deploy_helm_chart)
then
  >&2 echo "ERROR: Failed to deploy; see logs."
  exit 1
fi
