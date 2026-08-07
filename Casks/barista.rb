cask "barista" do
  version "0.1.5"
  sha256 "86d4ecf0f9a73434f0a2c521fc60e04590c5978f56684be4a2ef61ba00d4ac8f"

  url "https://github.com/mdsakalu/barista/releases/download/v#{version}/Barista-macos.zip"
  name "Barista"
  desc "Menu bar app that wraps caffeinate for keep-awake control"
  homepage "https://github.com/mdsakalu/barista"

  depends_on macos: :ventura

  app "Barista.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Barista.app"]
  end

  zap trash: "~/Library/Preferences/com.mdsakalu.barista.plist"
end
