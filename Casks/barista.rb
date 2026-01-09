cask "barista" do
  version "0.1.2"
  sha256 "b1498951c5a44d11b4a729d0422672e7680db85ed577f846fc8f18026822f953"

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
