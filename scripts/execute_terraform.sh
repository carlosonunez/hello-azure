#!sh

init_terraform() {
  terraform init -backend-config="resource_group_name=terraform" \
    -backend-config="storage_account_name=${TERRAFORM_STATE_STORAGE_ACCOUNT_NAME}" \
    -backend-config="container_name=${TERRAFORM_STATE_STORAGE_CONTAINER_NAME}" \
    -backend-config="key=tfstate"
}

write_outputs() {
  output_json=$(terraform output -json | jq -r '. | to_entries')
  outputs=$(echo "$output_json" | jq -r '.[].key')
  for output in "$outputs"
  do
    echo "$output_json" | jq --arg output "$output" \
      '.[] | select(.key == $output) | .value.value' > "/secrets/${output}"
  done
}

init_terraform && terraform $* && \
  if [ "$1" == "apply" ]; then write_outputs $1; fi
