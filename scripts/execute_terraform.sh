#!sh

init_terraform() {
  terraform init -backend-config="resource_group_name=terraform" \
    -backend-config="storage_account_name=${TERRAFORM_STATE_STORAGE_ACCOUNT_NAME}" \
    -backend-config="container_name=${TERRAFORM_STATE_STORAGE_CONTAINER_NAME}" \
    -backend-config="key=tfstate"
}

init_terraform && terraform $*
