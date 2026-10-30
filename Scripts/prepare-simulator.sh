#!/bin/bash

set -euo pipefail

destination="$1"
artifact_root="$2"
device_list="$artifact_root/simulator-devices.json"
readiness_log="$artifact_root/simulator-readiness.log"

if [[ "$destination" != *"platform=iOS Simulator"* ]]; then
  echo "quality: simulator readiness requires an iOS Simulator destination: $destination" >&2
  exit 1
fi

destination_value() {
  local key="$1"
  local part
  IFS=',' read -ra parts <<<"$destination"
  for part in "${parts[@]}"; do
    part="${part#"${part%%[![:space:]]*}"}"
    if [[ "$part" == "$key="* ]]; then
      echo "${part#*=}"
      return
    fi
  done
}

device_id="$(destination_value id)"
if [[ -z "$device_id" ]]; then
  device_name="$(destination_value name)"
  requested_os="$(destination_value OS)"
  if [[ -z "$device_name" ]]; then
    echo "quality: simulator destination must include id or name: $destination" >&2
    exit 1
  fi

  if ! xcrun simctl list devices available --json >"$device_list" 2>"$readiness_log"; then
    cat "$readiness_log" >&2
    echo "quality: unable to list available simulators" >&2
    exit 1
  fi

  if ! device_id="$(ruby -rjson -e '
    devices = JSON.parse(File.read(ARGV.fetch(0))).fetch("devices")
    name = ARGV.fetch(1)
    requested_os = ARGV.fetch(2)
    candidates = devices.flat_map do |runtime, entries|
      version = runtime[/iOS-(\d+(?:-\d+)*)\z/, 1]
      next [] unless version
      dotted_version = version.tr("-", ".")
      entries.each_with_object([]) do |device, matches|
        next unless device["isAvailable"] && device["name"] == name
        matches << [dotted_version.split(".").map(&:to_i), dotted_version, device.fetch("udid")]
      end
    end
    candidates.select! { |candidate| candidate[1] == requested_os } unless requested_os.empty? || requested_os == "latest"
    abort("no available simulator matches name=#{name}, OS=#{requested_os}") if candidates.empty?
    puts candidates.max_by(&:first).fetch(2)
  ' "$device_list" "$device_name" "$requested_os" 2>>"$readiness_log")"; then
    cat "$readiness_log" >&2
    echo "quality: unable to resolve simulator for readiness: $destination" >&2
    exit 1
  fi
fi

echo "quality: waiting for simulator readiness ($device_id)"
if ! xcrun simctl bootstatus "$device_id" -b >"$readiness_log" 2>&1; then
  cat "$readiness_log" >&2
  echo "quality: simulator did not become ready: $device_id" >&2
  exit 1
fi
