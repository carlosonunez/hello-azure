## `v0` to-do list!

- Get Terraform working
- Get our deployment script working
- Modify Terraform to use Packer-generated image
- Create example of CI for Packer
- Get our app working (along with the deployment script)
- Add Azure CDN and DNS
- Confirm that everything works from the Internet

## Debt

- `azcli` commands within `scripts/deploy.sh` should not assume that a previous
  login session exists; we need to use `az login --service-principal`
- Make Ansible testing instructions clearer
- In `infra/infra.tf`: `source_image_id` should ask for specific version of Python and Ubuntu
  through interpolation.
- Use gomplate to reduce `builder` DRY.
- Ensure packer template is valid before deploying infrastructure
