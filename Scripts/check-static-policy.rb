#!/usr/bin/env ruby

require "pathname"
require "open3"

root = Pathname.new(ARGV.fetch(0, ".")).expand_path

def fail_policy(message)
  warn "policy: #{message}"
  exit 1
end

def read(root, relative)
  path = root.join(relative)
  fail_policy("missing required file: #{relative}") unless path.file?
  path.read
end

def require_text(root, relative, text)
  fail_policy("#{relative} is missing required text: #{text}") unless read(root, relative).include?(text)
end

project = read(root, "Cadence.xcodeproj/project.pbxproj")
full_scheme = read(root, "Cadence.xcodeproj/xcshareddata/xcschemes/Cadence.xcscheme")
fast_scheme = read(root, "Cadence.xcodeproj/xcshareddata/xcschemes/CadenceFast.xcscheme")

%w[Cadence CadenceTests CadenceUITests].each do |target|
  fail_policy("full scheme is missing #{target}") unless full_scheme.include?(%(BlueprintName = "#{target}"))
end
fail_policy("fast scheme must include CadenceTests") unless fast_scheme.include?('BlueprintName = "CadenceTests"')
fail_policy("fast scheme must not include CadenceUITests") if fast_scheme.include?('BlueprintName = "CadenceUITests"')

owned_roots = {
  "App" => "Cadence",
  "Models" => "Cadence",
  "Views" => "Cadence",
  "Components" => "Cadence",
  "Services" => "Cadence",
  "Tests/CadenceTests" => "CadenceTests",
  "Tests/CadenceUITests" => "CadenceUITests"
}
owned_roots.each do |path, target|
  root_pattern = /isa = PBXFileSystemSynchronizedRootGroup;.*?path = #{Regexp.escape(path)};.*?};/m
  match = project.match(root_pattern)
  fail_policy("owned root is not a synchronized project group: #{path}") unless match
  group_id = project[/^\s*([A-F0-9]{24}) \/\* #{Regexp.escape(path.split('/').last)} \*\/ = \{\s*isa = PBXFileSystemSynchronizedRootGroup;.*?path = #{Regexp.escape(path)};/m, 1]
  fail_policy("unable to resolve synchronized group for #{path}") unless group_id
  target_block = project[/\/\* #{Regexp.escape(target)} \*\/ = \{\s*isa = PBXNativeTarget;.*?\n\t\t};/m]
  fail_policy("unable to resolve target #{target}") unless target_block
  fail_policy("#{path} is absent from #{target} target membership") unless target_block.include?(group_id)
end

%w[App Models Views Components Services].each do |path|
  exception = project[/Exceptions for "#{path}" folder.*?membershipExceptions = \((.*?)\);/m, 1]
  fail_policy("#{path} must declare an explicit membership exception") unless exception
  entries = exception.lines.map(&:strip).reject(&:empty?).map { |line| line.delete_suffix(",") }
  fail_policy("#{path} membership exceptions must contain only .gitkeep") unless entries == [".gitkeep"]
end

required_setting_fragments = [
  "IPHONEOS_DEPLOYMENT_TARGET = 27.0;",
  'TARGETED_DEVICE_FAMILY = 1;',
  'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
  'SWIFT_VERSION = 6.0;',
  'SWIFT_STRICT_CONCURRENCY = complete;',
  'SWIFT_TREAT_WARNINGS_AS_ERRORS = YES;'
]
required_setting_fragments.each do |fragment|
  fail_policy("project is missing approved setting: #{fragment}") unless project.include?(fragment)
end
fail_policy("unsupported deployment target found") if project.match?(/IPHONEOS_DEPLOYMENT_TARGET = (?!27\.0;)/)
fail_policy("unsupported device family found") if project.match?(/TARGETED_DEVICE_FAMILY = (?!1;)/)

swift_files = Dir[root.join("{App,Components,Models,Services,Views,Tests}/**/*.swift")]
swift_files.each do |path|
  relative = Pathname.new(path).relative_path_from(root).to_s
  source = File.read(path)
  fail_policy("#{relative}: @unchecked Sendable is forbidden") if source.match?(/@unchecked\s+Sendable/)
  syntax, errors, status = Open3.capture3("xcrun", "swiftc", "-frontend", "-dump-parse", path)
  fail_policy("#{relative}: Swift parser failed: #{errors.strip}") unless status.success?
  imports_swift_data = syntax.match?(/\(import_decl .* module="SwiftData"\)/)
  imports_swift_ui = syntax.match?(/\(import_decl .* module="SwiftUI"\)/)
  if relative.start_with?("Models/") && (imports_swift_data || imports_swift_ui)
    fail_policy("#{relative}: domain models must not import SwiftData or SwiftUI")
  end
  if relative.match?(%r{\A(App|Components|Models|Views|Services/Repositories)/}) && imports_swift_data
    fail_policy("#{relative}: SwiftData imports must remain inside Services/Persistence and persistence tests")
  end
  if relative.match?(%r{\A(Views|Components|Services/Repositories)/}) &&
      syntax.match?(/(?:name|id)="?(?:Query|ModelContext|ModelContainer|PersistentIdentifier|PersistentModel|\w+Record)"?/)
    fail_policy("#{relative}: presentation and repository protocols must not expose SwiftData details")
  end
  if relative.match?(%r{\A(Models|Services)/}) && source.include?("TimeZone.autoupdatingCurrent")
    fail_policy("#{relative}: use a captured time-zone snapshot")
  end
end

persistence_files = Dir[root.join("Services/Persistence/**/*.swift")]
persistence_source = persistence_files.map { |path| File.read(path) }.join("\n")
fail_policy("Schema V1 must not use persistence unique constraints") if persistence_source.match?(/@Attribute\s*\([^)]*\.unique/)
fail_policy("Schema V1 relationships must nullify") if persistence_source.match?(/deleteRule:\s*\.(cascade|deny)/)
fail_policy("SwiftData CloudKit must remain disabled") if persistence_source.match?(/cloudKitDatabase:\s*\.(automatic|private)/)
require_text(root, "Services/Persistence/CadenceModelContainerFactory.swift", "cloudKitDatabase: .none")
require_text(root, "Services/Persistence/CadenceStore.swift", "@ModelActor")

capability_files = Dir[root.join("**/*.{entitlements,pbxproj}")].reject { |path| path.include?("/.git/") }
capability_files.each do |path|
  if File.read(path).match?(/com\.apple\.developer\.icloud|CloudKit/i)
    fail_policy("iCloud or CloudKit capability found; V1 must remain local-only")
  end
end

markdown_files = [root.join("README.md"), *Dir[root.join("Docs/**/*.md")].map { |p| Pathname.new(p) }]
markdown_files.each do |path|
  path.read.scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |link|
    next if link.match?(%r{\A(https?://|mailto:|#)})
    target = path.dirname.join(link.split("#", 2).first).cleanpath
    fail_policy("#{path.relative_path_from(root)}: broken link #{link}") unless target.exist?
  end
end

trackers = {
  "Docs/features/FeatureTracker.md" => %w[Proposed Clarifying Planned Approved Building Validating Reviewing Done Blocked Deferred],
  "Docs/bugs/BugTracker.md" => ["Open", "Investigating", "Fixing", "Validating", "Resolved", "Deferred", "Won't Fix"],
  "Docs/engineering/EngineeringTracker.md" => %w[Proposed Planned Active Validating Done Blocked Deferred]
}
trackers.each do |relative, statuses|
  read(root, relative).lines.grep(/^\|/).drop(2).each do |line|
    cells = line.split("|").map(&:strip)
    next if cells[1] == "—"
    status = relative.include?("FeatureTracker") ? cells[4] : cells[3]
    fail_policy("#{relative}: unsupported status #{status}") unless statuses.include?(status)
    link = line[/\]\(([^)]+)\)/, 1]
    next unless link
    fail_policy("#{relative}: missing tracked record #{link}") unless root.join(File.dirname(relative), link).cleanpath.exist?
  end
end

workflow = read(root, ".github/workflows/quality.yml")
job_environment = workflow[/^    env:\n((?:      [A-Z_]+:.*\n)+)/, 1].to_s
fail_policy("CI job-level environment must not use the step-only runner context") if job_environment.include?("${{ runner.")
%w[pull_request schedule workflow_dispatch].each do |trigger|
  fail_policy("CI workflow is missing #{trigger} trigger") unless workflow.match?(/^\s*#{trigger}:/)
end
fail_policy("CI workflow must validate pushes to main") unless workflow.match?(/push:.*?branches:\s*\[main\]/m)
quality_invocations = workflow.scan(/^\s*run:\s*(.+)$/).flatten
full_gate = 'Scripts/quality.sh 2>&1 | tee "$CADENCE_ARTIFACT_ROOT/quality.log"'
fail_policy("CI must invoke the authoritative full quality command exactly once") unless quality_invocations.count(full_gate) == 1
fail_policy("CI must retain quality artifacts on failure") unless workflow.include?("if: failure()") && workflow.include?("CADENCE_KEEP_ARTIFACTS: 1")

result_verifier = read(root, "Scripts/verify-result-bundles.sh")
unless result_verifier.include?('xcresulttool get test-results summary --path "$2"')
  fail_policy("result-bundle verification must extract the test summary from Tests.xcresult")
end
unless result_verifier.include?('Scripts/verify-test-summary.rb "$test_summary"')
  fail_policy("result-bundle verification must enforce the extracted test summary")
end

puts "policy: static checks passed"
