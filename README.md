# hello-azure

Learn Azure through this dumb web app! I built this while trying to get my Azure certs (and so I can
convince myself that Azure actually isn't that bad.)

## The app

A simple Flask app that gives you a cute picture and a counter of how many times you clicked the
button.

To run it:

1. `source shortcuts`
2. `webserver`. The page will be at `https://localhost`.

## `v1`: Nothin' but IaaS

### Ansible and Packer

This repository uses Ansible and Packer to provision the Azure shared images used by our Azure VMs.

You can test these Ansible playbooks locally within Docker by running `ansible_test [webservers|databases]`.
The Ansible playbooks use the same version of Ubunut that is deployed into Azure.

### Terraform

Coming soon!

# Errata and troubleshooting

## I want to mock S3 in my tests locally. How do I connect to Azurite Blob store?

Use this connection string:

`"DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://blobstore:10000/devstoreaccount1"`
