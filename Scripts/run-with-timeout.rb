#!/usr/bin/env ruby

require "fileutils"

def fail_usage(message)
  warn "quality watchdog: #{message}"
  warn "usage: Scripts/run-with-timeout.rb SECONDS MARKER_PATH LABEL -- COMMAND [ARGUMENT ...]"
  exit 2
end

timeout_text = ARGV.shift || fail_usage("missing timeout")
marker_path = ARGV.shift || fail_usage("missing marker path")
label = ARGV.shift || fail_usage("missing label")
fail_usage("missing command separator") unless ARGV.shift == "--"
fail_usage("missing command") if ARGV.empty?

timeout_seconds = Integer(timeout_text, exception: false)
fail_usage("timeout must be a positive integer") unless timeout_seconds&.positive?
grace_seconds = Integer(ENV.fetch("CADENCE_WATCHDOG_GRACE_SECONDS", "5"), exception: false)
fail_usage("CADENCE_WATCHDOG_GRACE_SECONDS must be a positive integer") unless grace_seconds&.positive?

command = ARGV.freeze
begin
started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
pid = Process.spawn(*command, pgroup: true)
forwarded_signal = nil

%w[INT TERM].each do |signal|
  Signal.trap(signal) { forwarded_signal ||= signal }
end

terminate_group = lambda do |reason|
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  warn format(
    "quality watchdog: %s after %.1f seconds; sending TERM to process group %d (%s)",
    reason,
    elapsed,
    pid,
    label
  )
  begin
    Process.kill("TERM", -pid)
  rescue Errno::ESRCH
    return
  end

  grace_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + grace_seconds
  parent_reaped = false
  loop do
    parent_reaped ||= !Process.waitpid(pid, Process::WNOHANG).nil?
    begin
      Process.kill(0, -pid)
    rescue Errno::ESRCH
      return
    end
    break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= grace_deadline
    sleep 0.05
  end

  warn "quality watchdog: process group #{pid} exceeded #{grace_seconds}-second grace period; sending KILL"
  begin
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH
    nil
  end
end

deadline = started_at + timeout_seconds
loop do
  waited = Process.waitpid(pid, Process::WNOHANG)
  if waited
    status = $?
    exit(status.exitstatus || 128 + status.termsig)
  end

  if forwarded_signal
    terminate_group.call("received #{forwarded_signal}")
    Process.waitpid(pid) rescue nil
    exit(128 + Signal.list.fetch(forwarded_signal))
  end

  if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    FileUtils.mkdir_p(File.dirname(marker_path))
    File.write(
      marker_path,
      "label=#{label}\ntimeout_seconds=#{timeout_seconds}\ncommand=#{command.join(" ")}\n"
    )
    terminate_group.call("deadline of #{timeout_seconds} seconds expired")
    Process.waitpid(pid) rescue nil
    warn "quality watchdog: #{label} timed out; diagnostics retained at #{marker_path}"
    exit 124
  end

  sleep 0.05
end
rescue SystemCallError => error
  warn "quality watchdog: unable to run #{label}: #{error.message}"
  exit 127
end
