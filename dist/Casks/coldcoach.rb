# Homebrew cask for ColdCoach.
#
# Publish this in a tap repo `tiXor-code/homebrew-coldcoach` (as Casks/coldcoach.rb),
# then: brew install --cask tiXor-code/coldcoach/coldcoach
#
# Homebrew strips the Gatekeeper quarantine on install, so an ad-hoc-signed .dmg needs
# no notarization. Replace `sha256 :no_check` with the real release checksum once a
# GitHub release exists (shasum -a 256 ColdCoach.dmg).

cask "coldcoach" do
  version "0.0.1"
  sha256 :no_check

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
