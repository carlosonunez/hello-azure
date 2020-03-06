FROM hashicorp/packer:light

RUN apk add --no-cache py-pip jq && \
    pip install yq
