#!/bin/bash

set -euo pipefail

for bundle in "$@"; do
  [[ -d "$bundle" ]] || {
    echo "quality: result bundle was not created: $bundle" >&2
    exit 1
  }
done
