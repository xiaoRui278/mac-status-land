cask "macstatusland" do
  version "1.0.0"
  sha256 "4830c33a9c1ec00a05626a3dd4cf060e886d53655b8ce6c9717572f9399b49d2"

  url "https://github.com/xiaoRui278/mac-status-land/releases/download/v#{version}/MacStatusLand-v#{version}.dmg"
  name "MacStatusLand"
  desc "macOS menu bar app to manage status bar icons hidden by the notch"
  homepage "https://github.com/xiaoRui278/mac-status-land"

  depends_on macos: :ventura

  app "MacStatusLand.app"

  zap trash: [
    "~/Library/Preferences/com.xiaorui.MacStatusLand.plist",
  ]
end
