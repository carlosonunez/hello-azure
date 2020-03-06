#!/usr/bin/env bash
set -e
SKIP_IMAGES="${SKIP_IMAGES:-false}"

run() {
  echo "INFO: --- Running $@ ---"
  $@
}

create_images() {
  if [ "$SKIP_IMAGES" == "false" ]
  then
    scripts/run_packer.sh python-3.8_ubuntu-19.04-x86-64.yaml
  fi
}

deploy_infrastructure() {
  docker-compose run --rm terraform apply
}

verify_that_all_secrets_populated() {
  for secret in azure_storage_account_key \
      azure_storage_account_name \
      azure_storage_endpoint \
      common_private_key \
      databases \
      machine_user \
      postgres_password \
      postgres_user \
      webservers
  do
    file="secrets/${secret}"
    if ! test -f "$file" || test -z "$file"
    then
      >&2 echo "ERROR: Secret not found or populated: $file"
      exit 1
    fi
  done
}

build_ansible_inventory() {
  cat >inventory <<-INVENTORY_FROM_TERRAFORM
[all]
$(cat secrets/webservers)
$(cat secrets/databases)

[webservers]
$(cat secrets/webservers)

[databases]
$(cat secrets/databases)
INVENTORY_FROM_TERRAFORM
}

copy_images_to_storage_container() {
  endpoint="AccountName=$(cat secrets/azure_storage_account_name);\
  AccountKey=$(cat secrets/azure_storage_account_key);\
  BlobEndpoint=$(cat secrets/azure_storage_endpoint)/$(cat secrets/azure_storage_account_name)"

  for image in $(find $PWD/static/*.png)
  do
    blob_name=$(basename "$image")
    if [ "$blob_name" != "logo.png" ]
    then
      path="/workdir/static/$blob_name"
      >&2 echo "INFO: Uploading '$image'"
      docker-compose run --rm \
        -v $PWD:/workdir \
        -w /workdir \
        azcli storage blob upload --file "$path" --container 'app-images' \
          --name "$blob_name" \
          --account-name "$(cat secrets/azure_storage_account_name)" \
          --account-key "$(cat secrets/azure_storage_account_key)" || exit 1
    fi
  done
}

create_env_file() {
  cp .env.test .env && \
    gsed -i "s#\(POSTGRES_USER\)=.*\$#\1=$(cat secrets/postgres_user)#" .env && \
    gsed -i "s#\(POSTGRES_PASSWORD\)=.*\$#\1=$(cat secrets/postgres_password)#" .env && \
    gsed -i "s#\(SESSION_DB_USER\)=.*\$#\1=$(cat secrets/postgres_user)#" .env && \
    gsed -i "s#\(SESSION_DB_PASSWORD\)=.*\$#\1=$(cat secrets/postgres_password)#" .env && \
    gsed -i "s#\(SESSION_DB_HOST\)=.*\$#\1=$(cat secrets/databases | head -1)#" .env && \
    gsed -i "s#\(AZURE_STORAGE_ACCOUNT_NAME\)=.*\$#\1=$(cat secrets/azure_storage_account_name)#" .env && \
    gsed -i "s#\(AZURE_STORAGE_ACCOUNT_KEY\)=.*\$#\1=$(cat secrets/azure_storage_account_key)#" .env && \
    gsed -i "s#\(AZURE_STORAGE_ENDPOINT\)=.*\$#\1=$(cat secrets/azure_storage_endpoint)#" .env
}

tighten_access_to_private_key() {
  chmod 600 secrets/common_private_key
}

copy_env_file_to_servers() {
  docker-compose run --entrypoint ansible \
    -v $PWD:/app \
    -w /app \
    ansible-with-systemd -i inventory \
      --module-name copy \
      --become \
      --args "src=.env dest=/.env" \
      --user "$(cat secrets/machine_user)" \
      --private-key secrets/common_private_key \
      all
}

deploy_app() {
  env $(cat $PWD/.env | grep -v '#' | tr '\n' ' ') \
  docker-compose run -v $PWD:/app -w /app \
      --entrypoint ansible-playbook ansible-with-systemd \
      -i inventory \
      -u "$(cat secrets/machine_user)" \
      --private-key secrets/common_private_key \
      app.yml
}

run create_images && \
  run deploy_infrastructure && \
  run verify_that_all_secrets_populated && \
  run create_env_file && \
  run copy_images_to_storage_container && \
  run tighten_access_to_private_key && \
  run build_ansible_inventory && \
  run copy_env_file_to_servers && \
  run deploy_app
