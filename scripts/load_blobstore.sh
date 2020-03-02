#!/usr/bin/env sh
set -ex

AZURE_STORAGE_ENDPOINT=${AZURE_STORAGE_ENDPOINT}
export AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT_NAME}
export AZURE_STORAGE_KEY=${AZURE_STORAGE_ACCOUNT_KEY}

endpoint="DefaultEndpointsProtocol=http;\
AccountName=${AZURE_STORAGE_ACCOUNT};\
AccountKey=${AZURE_STORAGE_ACCOUNT_KEY};\
BlobEndpoint=${AZURE_STORAGE_ENDPOINT}/${AZURE_STORAGE_ACCOUNT}"

if ! az storage container list --connection-string=$endpoint | \
  grep -q "app_images"
then
  az storage container create --connection-string=$endpoint --name='app_images'
fi

for image in $(find $PWD/images/*)
do
  blob_name=$(basename "$image")
  az storage blob upload --file "$image" --container 'app_images' \
    --name "$blob_name" --connection-string=$endpoint
done
