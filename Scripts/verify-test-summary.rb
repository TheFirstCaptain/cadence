#!/usr/bin/env ruby

require "json"

unless ARGV.length == 1
  warn "usage: Scripts/verify-test-summary.rb SUMMARY_JSON"
  exit 2
end

summary = JSON.parse(File.read(ARGV.fetch(0)))
result = summary.fetch("result")
failed_tests = summary.fetch("failedTests")
total_tests = summary.fetch("totalTestCount")
test_failures = summary.fetch("testFailures", [])

if result != "Passed" || failed_tests != 0 || total_tests == 0 || !test_failures.empty?
  failures = test_failures.map do |failure|
    failure["testName"] || failure["testIdentifierString"]
  end.compact
  detail = failures.empty? ? "" : ": #{failures.join(', ')}"
  warn(
    "quality: test result bundle did not pass " \
      "(result=#{result.inspect}, failed=#{failed_tests}, total=#{total_tests})#{detail}"
  )
  exit 1
end

puts "quality: test result bundle passed (#{total_tests} tests)"
