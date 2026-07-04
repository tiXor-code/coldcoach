# Homebrew cask for ColdCoach.
#
# Publish this in a tap repo `tiXor-code/homebrew-coldcoach` (as Casks/coldcoach.rb),
# then: brew install --cask tiXor-code/coldcoach/coldcoach
#
# Homebrew strips the Gatekeeper quarantine on install, so an ad-hoc-signed .dmg needs
# no notarization. The sha256 below is the checksum of the v0.0.1 release .dmg
# (regenerate on each release with: shasum -a 256 build/ColdCoach.dmg).

cask "coldcoach" do
  version "0.0.1"
  sha256 "a0ba8319dc0b402061fee5c9f12a816d23f55ca1cc3b2d4b8b08b890e84a2360"

  url "https://github.com/tiXor-code/coldcoach/releases/download/v#{version}/ColdCoach.dmg"
  name "ColdCoach"
  desc "Local, open-source live coaching for cold calls"
  homepage "https://github.com/tiXor-code/coldcoach"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "ColdCoach.app"

  zap trash: [
    "~/Library/Application Support/ColdCoach",
  ]
end
