cask "barista" do
  version "0.1.1"
  sha256 "c6d216596b2c41e79bf574c7e6b30ef9176de8538859c24b46461ce4ea0d0cd2"

  url "https://github.com/mdsakalu/barista/releases/download/v#{version}/Barista-macos.zip"
  name "Barista"
  desc "Menu bar app that wraps caffeinate for keep-awake control"
  homepage "https://github.com/mdsakalu/barista"

  app "Barista.app"

  postflight do
    system_command "/usr/bin/xattr",
      args: ["-cr", "#{appdir}/Barista.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.mdsakalu.barista.plist"
  ]
end
