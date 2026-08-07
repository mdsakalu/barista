# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class RenderCaskTests < Minitest::Test
  REPO_ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(REPO_ROOT, "scripts/render_cask.rb")
  SOURCE_CASK = File.join(REPO_ROOT, "Casks/barista.rb")

  def test_renders_release_metadata_without_dropping_install_policy
    Dir.mktmpdir("barista-cask-test") do |directory|
      destination = File.join(directory, "barista.rb")
      sha256 = "a" * 64

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        SOURCE_CASK,
        destination,
        "9.8.7",
        sha256
      )

      assert status.success?, stderr
      rendered = File.read(destination)
      assert_includes rendered, %(  version "9.8.7")
      assert_includes rendered, %(  sha256 "#{sha256}")
      assert_includes rendered, %(args: ["-dr", "com.apple.quarantine")
      assert_includes rendered, "depends_on macos: :ventura"
    end
  end

  def test_rejects_invalid_release_metadata
    Dir.mktmpdir("barista-cask-test") do |directory|
      destination = File.join(directory, "barista.rb")

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        SCRIPT,
        SOURCE_CASK,
        destination,
        %(9.8.7"),
        "not-a-sha"
      )

      refute status.success?
      assert_match(/Invalid cask version/, stderr)
      refute File.exist?(destination)
    end
  end
end
