#!sh
PACKER_TEMPLATE="${1?Please provide the name of the Packer template to process.}"

if ! test -f "$PACKER_TEMPLATE"
then
  >&2 echo "ERROR: Template not found: $PACKER_TEMPLATE"
  exit 1
fi

cat "$PACKER_TEMPLATE" | yq . > /tmp/template.json && \
  packer build /tmp/template.json
