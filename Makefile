# ColdCoach — build & packaging
#
#   make selftest   Run the dependency-free core self-test (no Xcode needed)
#   make test       Run the XCTest suite (needs full Xcode; also runs in CI)
#   make app        Compile the release app binary (pulls WhisperKit)
#   make bundle     Assemble ColdCoach.app (ad-hoc signed) into build/
#   make dmg        Package build/ColdCoach.app into build/ColdCoach.dmg
#   make run        Build + open the app
#   make clean

APP_NAME   := ColdCoach
BUILD_DIR  := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
RELEASE_BIN := .build/release/$(APP_NAME)

.PHONY: selftest test app bundle dmg run clean

selftest:
	swift run coldcoach-selftest

test:
	swift test

app:
	COLDCOACH_BUILD_APP=1 swift build -c release

bundle: app
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(RELEASE_BIN) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp dist/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	# SwiftPM resource bundles must sit next to the executable and in Resources.
	-cp -R .build/release/*.bundle $(APP_BUNDLE)/Contents/MacOS/ 2>/dev/null
	-cp -R .build/release/*.bundle $(APP_BUNDLE)/Contents/Resources/ 2>/dev/null
	# Ad-hoc sign (no paid Apple Developer account required for local/OSS builds).
	codesign --force --deep --options runtime \
		--entitlements dist/entitlements.plist --sign - $(APP_BUNDLE) \
		|| codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"
	@echo "First launch: right-click the app > Open (Gatekeeper), or: xattr -dr com.apple.quarantine $(APP_BUNDLE)"

dmg: bundle
	rm -f $(BUILD_DIR)/$(APP_NAME).dmg
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(APP_BUNDLE) -ov -format UDZO $(BUILD_DIR)/$(APP_NAME).dmg
	@echo "Built $(BUILD_DIR)/$(APP_NAME).dmg"

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf .build $(BUILD_DIR)
