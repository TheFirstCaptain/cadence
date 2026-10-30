#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/cadence-policy-fixtures.XXXXXX")"
cleanup() {
  rm -rf "$fixture_root"
}
trap cleanup EXIT

make_fixture() {
  local name="$1"
  local destination="$fixture_root/$name"
  mkdir -p "$destination"
  find . -path './.git' -prune -o -type f -print0 | while IFS= read -r -d '' file; do
    file="${file#./}"
    mkdir -p "$destination/$(dirname "$file")"
    cp "$file" "$destination/$file"
  done
  echo "$destination"
}

expect_failure() {
  local name="$1"
  local expected="$2"
  local path="$fixture_root/$name"
  local output="$fixture_root/$name.log"
  if ruby Scripts/check-static-policy.rb "$path" >"$output" 2>&1; then
    echo "policy fixtures: $name unexpectedly passed" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$output"; then
    cat "$output" >&2
    echo "policy fixtures: $name failed for the wrong reason" >&2
    exit 1
  fi
  echo "policy fixtures: $name rejected as expected"
}

expect_command_failure() {
  local name="$1"
  local expected="$2"
  shift 2
  local output="$fixture_root/$name-command.log"
  if "$@" >"$output" 2>&1; then
    echo "policy fixtures: $name unexpectedly passed" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$output"; then
    cat "$output" >&2
    echo "policy fixtures: $name failed for the wrong reason" >&2
    exit 1
  fi
  echo "policy fixtures: $name rejected as expected"
}

fixture="$(make_fixture target-membership)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!(/(isa = PBXNativeTarget;.*?fileSystemSynchronizedGroups = \(.*?)\n\s*A10000043090B4C300FB9EF4 \/\* Services \*\/,/m, "\\1"); File.write(path, text)' "$fixture/Cadence.xcodeproj/project.pbxproj"
expect_failure target-membership "Services is absent from Cadence target membership"

fixture="$(make_fixture architecture-boundary)"
printf '\nimport SwiftData\n' >>"$fixture/Views/ContentView.swift"
expect_failure architecture-boundary "SwiftData imports must remain inside"

fixture="$(make_fixture scheme-membership)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("</Testables>", %q{<TestableReference><BuildableReference BlueprintName = "CadenceUITests"></BuildableReference></TestableReference></Testables>}); File.write(path, text)' "$fixture/Cadence.xcodeproj/xcshareddata/xcschemes/CadenceFast.xcscheme"
expect_failure scheme-membership "fast scheme must not include CadenceUITests"

fixture="$(make_fixture cloud-capability)"
printf '<key>com.apple.developer.icloud-services</key>\n' >"$fixture/App/Cadence.entitlements"
expect_failure cloud-capability "iCloud or CloudKit capability found"

fixture="$(make_fixture project-setting)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("IPHONEOS_DEPLOYMENT_TARGET = 27.0;", "IPHONEOS_DEPLOYMENT_TARGET = 26.0;"); File.write(path, text)' "$fixture/Cadence.xcodeproj/project.pbxproj"
expect_failure project-setting "unsupported deployment target found"

fixture="$(make_fixture build-setting-configuration)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("PRODUCT_BUNDLE_IDENTIFIER = com.kirkgartside.cadence;", "PRODUCT_BUNDLE_IDENTIFIER = com.example.wrong;"); File.write(path, text)' "$fixture/Cadence.xcodeproj/project.pbxproj"
expect_command_failure build-setting-configuration "expected PRODUCT_BUNDLE_IDENTIFIER" env CADENCE_SKIP_POLICY_FIXTURES=1 "$fixture/Scripts/check-policy.sh"

fixture="$(make_fixture tracker-consistency)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("| Active | Building |", "| Active | Flying |"); File.write(path, text)' "$fixture/Docs/features/FeatureTracker.md"
expect_failure tracker-consistency "unsupported status Flying"

fixture="$(make_fixture broken-link)"
printf '\n[Missing](./not-here.md)\n' >>"$fixture/README.md"
expect_failure broken-link "broken link ./not-here.md"

fixture="$(make_fixture unchecked-sendable)"
printf '\nstruct UnsafeFixture: @unchecked Sendable {}\n' >>"$fixture/Models/WeekID.swift"
expect_failure unchecked-sendable "@unchecked Sendable is forbidden"

fixture="$(make_fixture timezone-snapshot)"
printf '\nlet fixtureTimeZone = TimeZone.autoupdatingCurrent\n' >>"$fixture/Services/SystemValueProviders.swift"
expect_failure timezone-snapshot "use a captured time-zone snapshot"

fixture="$(make_fixture persistence-unique)"
printf '\n// fixture\n@Attribute(.unique) var fixtureID: String\n' >>"$fixture/Services/Persistence/CadenceSchemaV1.swift"
expect_failure persistence-unique "must not use persistence unique constraints"

fixture="$(make_fixture persistence-delete-rule)"
printf '\n// fixture deleteRule: .cascade\n' >>"$fixture/Services/Persistence/CadenceSchemaV1.swift"
expect_failure persistence-delete-rule "relationships must nullify"

fixture="$(make_fixture cloud-configuration)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path).sub("cloudKitDatabase: .none", "cloudKitDatabase: .automatic"); File.write(path, text)' "$fixture/Services/Persistence/CadenceModelContainerFactory.swift"
expect_failure cloud-configuration "SwiftData CloudKit must remain disabled"

fixture="$(make_fixture model-actor)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path).sub("@ModelActor", ""); File.write(path, text)' "$fixture/Services/Persistence/CadenceStore.swift"
expect_failure model-actor "missing required text: @ModelActor"

fixture="$(make_fixture ci-parity)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("Scripts/quality.sh 2>&1", "Scripts/quality.sh --fast 2>&1"); File.write(path, text)' "$fixture/.github/workflows/quality.yml"
expect_failure ci-parity "authoritative full quality command exactly once"

fixture="$(make_fixture ci-pipefail)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("          set -o pipefail\n", ""); File.write(path, text)' "$fixture/.github/workflows/quality.yml"
expect_failure ci-pipefail "CI quality log pipeline must propagate gate failures"

fixture="$(make_fixture ci-artifact-path)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("          path: /tmp/cadence-quality", "          path: /tmp/wrong-quality-path"); File.write(path, text)' "$fixture/.github/workflows/quality.yml"
expect_failure ci-artifact-path "CI failure upload path must match CADENCE_ARTIFACT_ROOT"

fixture="$(make_fixture ci-context)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!("CADENCE_ARTIFACT_ROOT: /tmp/cadence-quality", "CADENCE_ARTIFACT_ROOT: ${{ runner.temp }}/cadence-quality"); File.write(path, text)' "$fixture/.github/workflows/quality.yml"
expect_failure ci-context "step-only runner context"

expect_command_failure unknown-quality-mode "quality: unknown mode" Scripts/quality.sh --invalid

missing_results="$fixture_root/missing-results"
mkdir -p "$missing_results"
expect_command_failure result-bundle-check "result bundle was not created" Scripts/verify-result-bundles.sh "$missing_results/Build.xcresult" "$missing_results/Tests.xcresult"

failed_summary="$fixture_root/failed-test-summary.json"
ruby -rjson -e 'File.write(ARGV.fetch(0), JSON.generate({result: "Failed", failedTests: 2, totalTestCount: 3, testFailures: [{testName: "CadenceUITests.testAppLaunchesWithMyDaySelected()"}]}))' "$failed_summary"
expect_command_failure result-bundle-failure "test result bundle did not pass" Scripts/verify-test-summary.rb "$failed_summary"

fixture="$(make_fixture result-bundle-wiring)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!(%q{Scripts/verify-test-summary.rb "$test_summary"}, %q{echo "summary ignored"}); File.write(path, text)' "$fixture/Scripts/verify-result-bundles.sh"
expect_failure result-bundle-wiring "result-bundle verification must enforce the extracted test summary"

fixture="$(make_fixture simulator-readiness-wiring)"
ruby -e 'path = ARGV.fetch(0); text = File.read(path); text.sub!(%q{Scripts/prepare-simulator.sh "$destination" "$artifact_root"}, %q{echo "simulator readiness skipped"}); File.write(path, text)' "$fixture/Scripts/quality.sh"
expect_failure simulator-readiness-wiring "full quality gate must prepare the simulator before UI tests"

simulator_fixture="$fixture_root/simulator-readiness-behavior"
simulator_bin="$simulator_fixture/bin"
simulator_artifacts="$simulator_fixture/artifacts"
simulator_calls="$simulator_fixture/calls.log"
mkdir -p "$simulator_bin" "$simulator_artifacts"
printf '%s\n' '#!/bin/bash' 'echo "$*" >>"$FAKE_SIMCTL_CALLS"' '[[ "${FAKE_SIMCTL_FAILURE:-0}" != "1" ]]' >"$simulator_bin/xcrun"
chmod +x "$simulator_bin/xcrun"
FAKE_SIMCTL_CALLS="$simulator_calls" PATH="$simulator_bin:$PATH" Scripts/prepare-simulator.sh "platform=iOS Simulator,id=fixture-udid" "$simulator_artifacts"
grep -Fxq 'simctl bootstatus fixture-udid -b' "$simulator_calls" || {
  echo "policy fixtures: simulator readiness did not request boot-if-needed readiness" >&2
  exit 1
}
expect_command_failure simulator-readiness-failure "simulator did not become ready" env FAKE_SIMCTL_CALLS="$simulator_calls" FAKE_SIMCTL_FAILURE=1 PATH="$simulator_bin:$PATH" Scripts/prepare-simulator.sh "platform=iOS Simulator,id=fixture-udid" "$simulator_artifacts"
echo "policy fixtures: simulator-readiness behavior passed"

destination_artifacts="$fixture_root/destination"
mkdir -p "$destination_artifacts"
expect_command_failure destination-diagnostic "requested destination is unavailable" Scripts/check-destination.sh Cadence.xcodeproj Cadence "platform=iOS Simulator,name=Cadence Missing Device,OS=latest" "$destination_artifacts"

echo "policy fixtures: passed"
