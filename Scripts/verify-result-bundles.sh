#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: Scripts/verify-result-bundles.sh BUILD_XCRESULT TEST_XCRESULT" >&2
  exit 2
fi

for bundle in "$@"; do
  [[ -d "$bundle" ]] || {
    echo "quality: result bundle was not created: $bundle" >&2
    exit 1
  }
done

test_summary="$(mktemp "${TMPDIR:-/tmp}/cadence-test-summary.XXXXXX.json")"
trap 'rm -f "$test_summary"' EXIT
xcrun xcresulttool get test-results summary --path "$2" --compact >"$test_summary"
Scripts/verify-test-summary.rb "$test_summary"
