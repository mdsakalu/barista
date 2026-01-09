cask "barista" do
  version "0.1.0"
  sha256 "REPLACE_ME"

  url "https://github.com/mdsakalu/barista/releases/download/v#{version}/Barista-macos.zip"
  name "Barista"
  desc "Menu bar app that wraps caffeinate for keep-awake control"
  homepage "https://github.com/mdsakalu/barista"

  app "Barista.app"

  zap trash: [
    "~/Library/Preferences/com.mdsakalu.barista.plist"
  ]
end
