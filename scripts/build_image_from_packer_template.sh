#!sh
PACKER_TEMPLATE="${1?Please provide the name of the Packer template to process.}"

if ! test -f "$PACKER_TEMPLATE"
then
  >&2 echo "ERROR: Template not found: $PACKER_TEMPLATE"
  exit 1
fi

# Packer will error if the images created by the template already exist
# in the destination repository. The code below works around this.
cat "$PACKER_TEMPLATE" | yq . > /tmp/template.json && \
  packer build -parallel -parallel-builds=0 \
    -machine-readable /tmp/template.json | tee /tmp/result.log
errors_encountered=$(cat /tmp/result.log | \
  egrep 'Build .* errored:' | \
  egrep -v 'the managed image named .* already exists in the resource group')
if ! test -z "$errors_encountered"
then
  >&2 echo "ERROR: Packer encountered these errors: $errors_encountered"
  exit 1
fi
