#!/usr/bin/env sh
set -e

AZURE_STORAGE_ENDPOINT=${AZURE_STORAGE_ENDPOINT}
export AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT_NAME}
export AZURE_STORAGE_KEY=${AZURE_STORAGE_ACCOUNT_KEY}

endpoint="DefaultEndpointsProtocol=http;\
AccountName=${AZURE_STORAGE_ACCOUNT};\
AccountKey=${AZURE_STORAGE_ACCOUNT_KEY};\
BlobEndpoint=${AZURE_STORAGE_ENDPOINT}/${AZURE_STORAGE_ACCOUNT}"

if ! az storage container list --connection-string=$endpoint | \
  grep -q "app-images"
then
  >&2 echo "INFO: Creating app-images container"
  az storage container create --connection-string=$endpoint --name='app-images'
fi

for image in $(find $PWD/static/*.png)
do
  blob_name=$(basename "$image")
  if [ "$blob_name" != "logo.png" ]
  then
    >&2 echo "INFO: Uploading '$image'"
    az storage blob upload --file "$image" --container 'app-images' \
      --name "$blob_name" --connection-string=$endpoint
  fi
done
