#!/bin/sh
# Build and push the private treescanr dev image to ghcr.io.
#
# Usage: .devcontainer/build.sh <path/to/treescan.X.Y.Z.tar.gz> [tag]
#
# Requires docker or podman, and a login to ghcr.io with a token that has the
# write:packages scope, e.g.:
#   gh auth refresh -s write:packages,read:packages
#   gh auth token | podman login ghcr.io -u <github-user> --password-stdin
set -eu

TARBALL=${1:?"path to the TreeScan Linux tarball"}
TAG=${2:-latest}
IMAGE=ghcr.io/epiforesite/treescanr-dev
ENGINE=$(command -v docker || command -v podman)
DIR=$(cd "$(dirname "$0")" && pwd)

cp "$TARBALL" "$DIR/treescan.tar.gz"
trap 'rm -f "$DIR/treescan.tar.gz"' EXIT

# The TreeScan Linux binary is x86-64 only
"$ENGINE" build --platform linux/amd64 -f "$DIR/Containerfile" \
  -t "$IMAGE:$TAG" "$DIR"

"$ENGINE" push "$IMAGE:$TAG"
