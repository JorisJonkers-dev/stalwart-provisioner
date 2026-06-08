#!/bin/sh
# Development bootstrap entrypoint. It runs the same apply path once with a
# local manifest and then exits.
set -eu

: "${STALWART_URL:=http://stalwart:8080}"
: "${STALWART_USER:=admin}"
: "${STALWART_MANIFEST:=/opt/stalwart-provisioner/examples/dev-manifest.json}"
: "${APPLY_IDLE:=false}"

export STALWART_URL STALWART_USER STALWART_MANIFEST APPLY_IDLE

exec /usr/local/bin/stalwart-provisioner-apply
