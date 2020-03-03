# Storage

- Azure Blob Storage is the equivalent of AWS S3.
- So we need to login, then create a RG, then create a storage account, then
  create a container (their equivalent of a bucket), then upload a blob into the container
  - S3 is WAY easier
- Ran into an issue while trying to add a container without using the default account.
  According to the docs, I should be able to use `AZURITE_ACCOUNTS="account1:key1"` as
  an environment variable to set this up and then use a really long connection
  string with `az storage container create`. Keep getting "Invalid Storage Account" errors (in XML,
  despite my output format being in `json` and successful responses being sent back in JSON.)

  There is NOTHING on the internet about this.

  Anyone just getting started should've run into this.
- Literally FOUR results from Google when I search "Azure \"AZURITE_ACCOUNTS\"". INSANE.

# Testing

- Azurite is Microsoft's equivalent of `localstack`

# `azcli`

- Output from `azcli [command] --help` is really nice (love the feedback link on the bottom)
- Love that I can type `--help` and get what I expect (not a thing with `awscli`)
- `az storage blob copy start` and `az storage blob upload` are confusing
- Deleting resource groups can take a while...

# Azure Portal

- This UI is _super_ nice compared to AWS.

# Flask

- Sinatra feels so much easier to set up
- Can't set host and port with env vars without _not_ using `flask run`. You have
  to use `app.run` and then load it from Python directly wtih `python app.py`

# #random

- A bit of a shame that Microsoft created Azurite instead of the community
- This feels awfully reminiscent of my experience using Terraform's Azure provider.
  Mostly maintained by Microsoft, i.e. the community is still allergic to az.
- Documentation not bad so far
  (https://docs.microsoft.com/en-us/cli/azure/storage/blob?view=azure-cli-latest)
- I was expecting azurite to be chunkier but ~100MB total ain't bad
- But azcli is chunkier at ~200MB; anigeo/awscli is only 112MB
- Meanwhile, searching for "python flask tutorial" yields, like, a trillion results,
  with the first result being from an engineer's blog. I still think that
  "little information from community about software = software targets enterprises =
  it probably sucks since most CIO/CTO's don't know any better and it's too expensive to try"

# Azure APIs

- Apparently `azure_storage` only works with Python 3.5 max. That's nuts (in a bad way).
- Yep, the documentation is wrong. `from azure.storage.blob import BlobServiceClient`
  is outdated despite it being on the quickstart docs that is the top result on Google when
  one searches for "azure storage api python".

  See here for more: https://stackoverflow.com/questions/58768443/error-importing-blobserviceclient-from-azure-storage-blob
- Observe this:

  ```
  hello-azure_1  |     account_url, secondary, credential = parse_connection_str(conn_str, credential, 'blob')
hello-azure_1  |   File "/usr/local/lib/python3.8/site-packages/azure/storage/blob/_shared/base_client.py", line 373, in parse_connection_str
hello-azure_1  |     raise ValueError("Connection string missing required connection details.")
hello-azure_1  | ValueError: Connection string missing required connection details.
  ```

  What the fuck am I supposed to do with that?

# Terraform

- Right out the gate, I get this upon running `tf init` (see the rest of this commit to view the
  code that configures the backend):

  ```
  Error: Failed to get existing workspaces: storage: service returned error: StatusCode=400, ErrorCode=InvalidResourceName, ErrorMessage=The specifed resource name contains invalid characters.
RequestId:b0ada873-601e-0076-60ed-f0a942000000
Time:2020-03-02T23:50:35.0043821Z, RequestInitiated=Mon, 02 Mar 2020 23:50:34 GMT, RequestId=b0ada873-601e-0076-60ed-f0a942000000, API Version=2016-05-31, QueryParameterName=, QueryParameterValue=
  ```

  Can't find anything on this on Google, Stack Overflow or Terraform's GitHub issues page. Very
  frustrating, and very much like my last go at Azure...

- Turns out this was due to there being spaces in the name of one of my `ARM_` environment
  variables.

# Commands and Incantations

## Creating a bucket to store Terraform state in from scratch

1. Login to your Azure account: `az login`
2. Create a service principal for Terraform: `az ad sp create-for-rbac --role="Contributor"
   --scopes="/subscriptions/$SUBSCRIPTION_ID"`

   This takes about two minutes.
2. Create a resource group for the storage account and blob that will store your state:

   ```sh
   az group create --location "South Central US" --name terraform_state
   ```

   The result should look like this:

   ```json
{
  "id": "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/terraform_state",
  "location": "southcentralus",
  "managedBy": null,
  "name": "terraform_state",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
   ```
3. Create a storage account for your blob:

    ```sh
    az storage account create --subscription $SUBSCRIPTION_ID \
      --resource-group terraform_state \
      --name terraformstate$UNIQUE_IDENTIFIER_ALL_LOWER_CASE \
      --sku Standard_LRS \
      --location "South Central US" \
      --kind Storage
    ```

    There are many different storage types; check them out
    [here](https://azure.microsoft.com/en-us/pricing/details/storage/)

   The first time I ran this, it took the API about a minute to respond (I was using
   a Gigabit connection at the time). It came back with this:

   ```
   terraform_state is not a valid storage account name. Storage account name must be between 3 and
   24 characters in length and use numbers and lower-case letters only.
   ```

   Welp.

   After fixing this, I got something like this back:

   ```json
{
  "accessTier": null,
  "azureFilesIdentityBasedAuthentication": null,
  "blobRestoreStatus": null,
  "creationTime": "2020-03-02T23:33:38.678763+00:00",
  "customDomain": null,
  "enableHttpsTrafficOnly": true,
  "encryption": {
    "keySource": "Microsoft.Storage",
    "keyVaultProperties": null,
    "services": {
      "blob": {
        "enabled": true,
        "keyType": "Account",
        "lastEnabledTime": "2020-03-02T23:33:38.756885+00:00"
      },
      "file": {
        "enabled": true,
        "keyType": "Account",
        "lastEnabledTime": "2020-03-02T23:33:38.756885+00:00"
      },
      "queue": null,
      "table": null
    }
  },
  "failoverInProgress": null,
  "geoReplicationStats": null,
  "id": "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/terraform/providers/Microsoft.Storage/storageAccounts/terraformstate$UNIQUE_IDENTIFIER_ALL_LOWER_CASE",
  "identity": null,
  "isHnsEnabled": null,
  "kind": "Storage",
  "largeFileSharesState": null,
  "lastGeoFailoverTime": null,
  "location": "southcentralus",
  "name": "terraformstate$UNIQUE_IDENTIFIER_ALL_LOWER_CASE",
  "networkRuleSet": {
    "bypass": "AzureServices",
    "defaultAction": "Allow",
    "ipRules": [],
    "virtualNetworkRules": []
  },
  "primaryEndpoints": {
    "blob": "https://terraformstate$UNIQUE_IDENTIFIER_ALL_LOWER_CASE.blob.core.windows.net/",
    "dfs": null,
    "file": "https://terraformstate$UNIQUE_IDENTIFIER_ALL_LOWER_CASE.file.core.windows.net/",
    "internetEndpoints": null,
    "microsoftEndpoints": null,
    "queue": "https://terraformstate$UNIQUE_IDENTIFIER_ALL_LOWER_CASE.queue.core.windows.net/",
    "table": "https://terraformstate$UNIQUE_IDENTIFIER_ALL_LOWER_CASE.table.core.windows.net/",
    "web": null
  },
  "primaryLocation": "southcentralus",
  "privateEndpointConnections": [],
  "provisioningState": "Succeeded",
  "resourceGroup": "terraform",
  "routingPreference": null,
  "secondaryEndpoints": null,
  "secondaryLocation": null,
  "sku": {
    "name": "Standard_LRS",
    "tier": "Standard"
  },
  "statusOfPrimary": "available",
  "statusOfSecondary": null,
  "tags": {},
  "type": "Microsoft.Storage/storageAccounts"
}
   ```

4. Create the container: `az storage container create --account-name=$ACCOUNT_NAME
   --name=terraformstate`
