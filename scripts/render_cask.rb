#!/usr/bin/env ruby
# frozen_string_literal: true

source_path, destination_path, version, sha256 = ARGV

unless source_path && destination_path && version && sha256
  abort "Usage: scripts/render_cask.rb SOURCE DESTINATION VERSION SHA256"
end

unless version.match?(/\A[0-9]+(?:\.[0-9]+)*(?:[-+][0-9A-Za-z.-]+)?\z/)
  abort "Invalid cask version: #{version.inspect}"
end

unless sha256.match?(/\A[0-9a-f]{64}\z/)
  abort "Invalid SHA256: #{sha256.inspect}"
end

contents = File.read(source_path)

def replace_once(contents, pattern, replacement, field)
  count = contents.scan(pattern).length
  abort "Expected one #{field} declaration, found #{count}" unless count == 1

  contents.sub(pattern, replacement)
end

contents = replace_once(
  contents,
  /^  version "[^"]+"$/,
  %(  version "#{version}"),
  "version"
)
contents = replace_once(
  contents,
  /^  sha256 "[0-9a-f]{64}"$/,
  %(  sha256 "#{sha256}"),
  "sha256"
)

File.write(destination_path, contents)
