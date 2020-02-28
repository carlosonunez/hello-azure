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
