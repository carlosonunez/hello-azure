# Grafana

- I like how easy it is to set up, especially wrt SSL and external OAuth
  (I was able to get Google OAuth working in two commits)
- So many 404s in their documentation around provisioning. This is janky.

# General

- The `ec2instances.info` equivalent for Azure is `azureprice.net`
- Search query `"az monitor alert create" "Billing Total"` == 299 results. LOLOSAD
  - Turns out: you can't create cost alerts in the CLI, at least not in a way
    that makes sense to me.
- This is confusing: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6016
- Here's an interesting story about why committing (and pushing) early and often is a really
  good idea.

  I was wrapping up some work on my deployment script. One of the steps I do during
  the deployment is clone this repository onto my webserver before starting the
  Flask app with systemd. I was running into some weird errors with this step; specifically,
  I kept getting errors that the directory I was cloning into was "busy".

  Trying to brute-force my way into a solution, I edited the Ansible playbook that deploys this app
  to delete the folder I was cloning into before actually cloning it. Ansible runs in a Docker
  container with my application volume-mounted to `/app`. On the webserver, my application is
  deployed into `/app`.

  This was all well and good, except for one thing: the plays within this playbook were copied from
  another playbook I wrote earlier that is executed on the server itself (i.e. not over SSH).
  `connection: local` is the directive that tells Ansible to do this.

  I forgot to remove that line. Since the folder I'm deploying into on the webserver is called
  `/app` and my app is mounted into `/app` in the Ansible container that runs my deployment
  playbook, every time I ran this script, I would lose _my entire codebase_.

  Because I forgot to push my work after committing it, I lost two hours of work that I had to redo.

  Commit and push early and often, people!

# Compute

- Holy fuck; Azure is expensive compared to AWS!
- Price compare:
  - AWS t2.micro (1 vCPU, 1GB RAM, 8GB EBS, 2.25h burst = $0.011/hour in `us-east-2`)
  - Azure `Standard_B1s` (1 vCPU, 1 GB RAM, 8GB EBS, 2.67 hours burst max) = $0.013/hour in `South Central US`)
    - `Standard_B1s` comes with 30 credits with a 10% CPU baseline and a 100% max
    - Credit redemption formula (per hour): `(($percent_baseline - $percent_usage)/100)*60 minutes`
    - `((10-100)/100)*60 = 54 credits/hour`
    - You receive 6 credits per hour up to a cap of 144 credits
- why is picking the latest Ubuntu platform image so hard
  - Fortunately you can specify that you want the latest version in Terraform
    by setting `version` to "latest"
- Availability Zones _still_ aren't offered in all Azure regions. Like, really?
- You don't get public IPs for free like you do with AWS. You _have_ to allocate a public IP
  address to the instance, which costs money ($0.002/hr). WACK AS FUCK.
- It took NINE MINUTES to get a dynamic public IP allocated to me. THAT IS NUTS.
  - Follow-on calls were faster over the same connection, which is weird.
- Deleting/creating resource groups can take a while.
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
- LOL the progress bar uses FOUR significant digits for progress. Someone at MSFT is very exact!

# Networking

- Okay. So there are Network Security Groups (NSGs) and Application Security Groups (ASGs).
  NSGs behave like AWS security groups, so that's easy to understand. But I can't restrict traffic
  based on NSGs; I have to use ASGs for that.

  So what are ASGs?

  Turns out: this is a relatively new feature that provides "micro-segmentation" of a vNET
  by allowing you to filter traffic based on ASGs that resources belong to.

  https://azure.microsoft.com/en-us/blog/applicationsecuritygroups/

  i.e. 2013 called; AWS wants its security groups back.

# Testing

- Azurite is Microsoft's equivalent of `localstack`

# `azcli`

- Output from `azcli [command] --help` is really nice (love the feedback link on the bottom)
- Love that I can type `--help` and get what I expect (not a thing with `awscli`)
- `az storage blob copy start` and `az storage blob upload` are confusing
- Deleting resource groups can take a while...

# Terraform

- So far, not bad. HashiCorp still has the non-AzureRM-based provider out there for some
  reason which fucks with Google search results, but...

- Please don't tell me that NSG names need to be globally-unique...
  nope; just a derp.

- TF is a lot faster than it was when I used it two years ago.

- I have to create my own vNICs to bond to VMs. AWS, you've spoiled me.

- ARE YOU MOTHER FUCKING KIDDING ME: https://github.com/terraform-providers/terraform-provider-azurerm/issues/5907#issuecomment-594231887
  - Discovered that I can't change the name of an OS disk for an existing VM
  - I thought that it was odd that this didn't trigger a new resource creation, so I went to
    the provider's GitHub repo to log a bug
  - Found an existing bug here: https://github.com/terraform-providers/terraform-provider-azurerm/issues/5907
  - `azurerm_virtual_machine` feature frozen a week ago; no reason provided
  - `azurerm_linux_virtual_machine` replaces it
  - Okay; I'm less mad since this was documented at the top of the page.

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
