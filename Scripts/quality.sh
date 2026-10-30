#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

mode="full"
if [[ $# -gt 1 ]]; then
  echo "usage: Scripts/quality.sh [--fast]" >&2
  exit 2
fi
if [[ $# -eq 1 ]]; then
  if [[ "$1" != "--fast" ]]; then
    echo "quality: unknown mode: $1" >&2
    echo "usage: Scripts/quality.sh [--fast]" >&2
    exit 2
  fi
  mode="fast"
fi

for command_name in xcodebuild xcrun ruby; do
  command -v "$command_name" >/dev/null || {
    echo "quality: required command not found: $command_name" >&2
    exit 1
  }
done

destination="${CADENCE_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"
if [[ -n "${CADENCE_ARTIFACT_ROOT:-}" ]]; then
  artifact_root="$CADENCE_ARTIFACT_ROOT"
  mkdir -p "$artifact_root"
  owns_artifact_root=0
else
  artifact_root="$(mktemp -d "${TMPDIR:-/tmp}/cadence-quality.XXXXXX")"
  owns_artifact_root=1
fi
derived_data="$artifact_root/DerivedData"
build_results="$artifact_root/Build.xcresult"
test_results="$artifact_root/Tests.xcresult"

cleanup() {
  local result=$?
  if [[ $result -eq 0 && "$owns_artifact_root" == "1" && "${CADENCE_KEEP_ARTIFACTS:-0}" != "1" ]]; then
    rm -rf "$artifact_root"
  else
    echo "quality: artifacts retained at $artifact_root" >&2
  fi
}
trap cleanup EXIT

echo "quality: mode=$mode"
echo "quality: destination=$destination"
echo "quality: Xcode $(xcodebuild -version | head -n 1)"
echo "quality: Swift $(xcrun swift --version | head -n 1)"

echo "quality: running repository policy checks"
Scripts/check-policy.sh

echo "quality: linting Swift formatting"
swift_roots=(App Components Models Services Views Tests)
xcrun swift format lint --strict --recursive --parallel "${swift_roots[@]}"

echo "quality: checking simulator destination availability"
Scripts/check-destination.sh Cadence.xcodeproj Cadence "$destination" "$artifact_root"

common_arguments=(
  -project Cadence.xcodeproj
  -scheme Cadence
  -destination "$destination"
  -derivedDataPath "$derived_data"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)

if [[ "$mode" == "fast" ]]; then
  echo "quality: building app and focused unit tests"
  fast_arguments=("${common_arguments[@]}")
  fast_arguments[3]=CadenceFast
  xcodebuild "${fast_arguments[@]}" \
    -resultBundlePath "$build_results" \
    -only-testing:CadenceTests \
    build-for-testing

  echo "quality: running focused unit tests"
  xcodebuild "${fast_arguments[@]}" \
    -resultBundlePath "$test_results" \
    -only-testing:CadenceTests \
    test-without-building
else
  echo "quality: preparing simulator for UI automation"
  Scripts/prepare-simulator.sh "$destination" "$artifact_root"

  echo "quality: clean build for all tests"
  xcodebuild "${common_arguments[@]}" clean
  xcodebuild "${common_arguments[@]}" \
    -resultBundlePath "$build_results" \
    build-for-testing

  echo "quality: running unit and UI tests"
  xcodebuild "${common_arguments[@]}" \
    -resultBundlePath "$test_results" \
    test-without-building
fi

Scripts/verify-result-bundles.sh "$build_results" "$test_results"

echo "quality: passed ($mode)"
