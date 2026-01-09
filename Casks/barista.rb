cask "barista" do
  version "0.1.0"
  sha256 "f8e437991cb41dfbc8b5939d9837d98b3861dcc84f3f147168b9dbac3f04a9a4"

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
