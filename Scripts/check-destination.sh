#!/bin/bash

set -euo pipefail

project="$1"
scheme="$2"
destination="$3"
artifact_root="$4"
destination_output="$artifact_root/destinations.txt"

if ! xcodebuild -project "$project" -scheme "$scheme" -showdestinations >"$destination_output" 2>&1; then
  cat "$destination_output" >&2
  echo "quality: unable to query simulator destinations" >&2
  exit 1
fi
if ! xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -destination "$destination" \
  -destination-timeout 5 \
  -showBuildSettings \
  CODE_SIGNING_ALLOWED=NO >/dev/null 2>"$artifact_root/destination-resolution.log"; then
  cat "$artifact_root/destination-resolution.log" >&2
  echo "quality: requested destination is unavailable: $destination" >&2
  echo "quality: compatible destinations:" >&2
  cat "$destination_output" >&2
  exit 1
fi
