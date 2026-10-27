#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fail() {
  echo "policy: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

require_text() {
  local file="$1"
  local text="$2"
  grep -Fq "$text" "$file" || fail "$file is missing required text: $text"
}

echo "policy: checking required project structure"
require_file "Cadence.xcodeproj/project.pbxproj"
require_file "Cadence.xcodeproj/xcshareddata/xcschemes/Cadence.xcscheme"
require_file "App/CadenceApp.swift"
require_file "Views/ContentView.swift"
require_file "Tests/CadenceTests/CadenceTests.swift"
require_file "Tests/CadenceUITests/CadenceUITests.swift"

project_file="Cadence.xcodeproj/project.pbxproj"
scheme_file="Cadence.xcodeproj/xcshareddata/xcschemes/Cadence.xcscheme"

echo "policy: checking approved project settings"
require_text "$scheme_file" 'BlueprintName = "Cadence"'
require_text "$scheme_file" 'BlueprintName = "CadenceTests"'
require_text "$scheme_file" 'BlueprintName = "CadenceUITests"'

command -v xcodebuild >/dev/null || fail "required command not found: xcodebuild"
settings_root="$(mktemp -d "${TMPDIR:-/tmp}/cadence-settings.XXXXXX")"
cleanup_settings() {
  rm -rf "$settings_root"
}
trap cleanup_settings EXIT

for target in Cadence CadenceTests CadenceUITests; do
  for configuration in Debug Release; do
    output="$settings_root/$target-$configuration.json"
    log="$settings_root/$target-$configuration.log"
    if ! xcodebuild \
      -project Cadence.xcodeproj \
      -target "$target" \
      -configuration "$configuration" \
      -showBuildSettings \
      -json \
      CODE_SIGNING_ALLOWED=NO \
      OBJROOT="$settings_root/obj" \
      SYMROOT="$settings_root/sym" >"$output" 2>"$log"; then
      cat "$log" >&2
      fail "unable to inspect $target $configuration build settings"
    fi
  done
done

ruby -rjson -e '
  root = ARGV.fetch(0)
  expected_bundles = {
    "Cadence" => "com.kirkgartside.cadence",
    "CadenceTests" => "com.kirkgartside.cadence.tests",
    "CadenceUITests" => "com.kirkgartside.cadence.uitests"
  }
  failures = []
  expected_bundles.each do |target, bundle|
    %w[Debug Release].each do |configuration|
      path = File.join(root, "#{target}-#{configuration}.json")
      entries = JSON.parse(File.read(path))
      entry = entries.find { |candidate| candidate["target"] == target }
      unless entry
        failures << "#{target} #{configuration}: target settings missing"
        next
      end
      settings = entry.fetch("buildSettings")
      expected = {
        "IPHONEOS_DEPLOYMENT_TARGET" => "27.0",
        "TARGETED_DEVICE_FAMILY" => "1",
        "SUPPORTED_PLATFORMS" => "iphoneos iphonesimulator",
        "SWIFT_VERSION" => "6.0",
        "SWIFT_STRICT_CONCURRENCY" => "complete",
        "SWIFT_TREAT_WARNINGS_AS_ERRORS" => "YES",
        "PRODUCT_BUNDLE_IDENTIFIER" => bundle,
        "CODE_SIGN_STYLE" => "Automatic"
      }
      expected["INFOPLIST_KEY_UISupportedInterfaceOrientations"] = "UIInterfaceOrientationPortrait" if target == "Cadence"
      expected.each do |key, value|
        actual = settings[key]
        failures << "#{target} #{configuration}: expected #{key}=#{value}, found #{actual.inspect}" unless actual == value
      end
    end
  end
  abort(failures.join("\n")) unless failures.empty?
' "$settings_root"

if find . -path './.git' -prune -o -type f \( -name '*.entitlements' -o -name '*.pbxproj' \) -print0 |
  xargs -0 grep -Eqi 'com\.apple\.developer\.icloud|CloudKit'; then
  fail "iCloud or CloudKit capability found; V1 must remain local-only"
fi

if grep -R -n --include='*.swift' '@unchecked[[:space:]]\+Sendable' App Components Models Services Views Tests; then
  fail "@unchecked Sendable is forbidden"
fi

echo "policy: checking Markdown links"
ruby -e '
  files = Dir["{README.md,Docs/**/*.md}"]
  failures = []
  files.each do |file|
    File.read(file).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |link|
      next if link.match?(%r{^(https?://|mailto:|#)})
      relative_path = link.split("#", 2).first
      target = File.expand_path(relative_path, File.dirname(file))
      failures << "#{file}: broken link #{link}" unless File.exist?(target)
    end
  end
  abort(failures.join("\n")) unless failures.empty?
'

echo "policy: checking tracker links and statuses"
ruby -e '
  trackers = {
    "Docs/features/FeatureTracker.md" => %w[Proposed Clarifying Planned Approved Building Validating Reviewing Done Blocked Deferred],
    "Docs/bugs/BugTracker.md" => ["Open", "Investigating", "Fixing", "Validating", "Resolved", "Deferred", "Won\x27t Fix"],
    "Docs/engineering/EngineeringTracker.md" => %w[Proposed Planned Active Validating Done Blocked Deferred]
  }
  failures = []
  trackers.each do |file, statuses|
    File.readlines(file).grep(/^\|/).drop(2).each do |line|
      cells = line.split("|").map(&:strip)
      next if cells[1] == "—"
      status = file.include?("FeatureTracker") ? cells[4] : cells[3]
      failures << "#{file}: unsupported status #{status}" unless statuses.include?(status)
      link = line[/\]\(([^)]+)\)/, 1]
      next unless link
      target = File.expand_path(link, File.dirname(file))
      failures << "#{file}: missing tracked record #{link}" unless File.exist?(target)
    end
  end
  abort(failures.join("\n")) unless failures.empty?
'

echo "policy: passed"
