.DEFAULT_GOAL := lint

RELEASE_VERSION = $(shell .build/release/hostmgr --version)

lint:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.50.3 swiftlint lint --strict

lintfix:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.50.3 swiftlint --autocorrect

build-release:
	@echo "--- Building Release"
	swift build -c release
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/release/hostmgr -v
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/release/hostmgr-helper -v
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/release/hostmgr-beacon -v

release: build-release
	@echo "--- Tagging Release"
	git tag $(RELEASE_VERSION)
	git push origin $(RELEASE_VERSION)

run-vm-create-debug:
	@echo "--- Building and Signing hostmgr for Local Development"
	swift build
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/arm64-apple-macosx/debug/hostmgr -v
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/release/hostmgr-helper -v
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/release/hostmgr-beacon -v

	./.build/arm64-apple-macosx/debug/hostmgr vm create xcode-143 --disk-size 92

build-helper-debug:
	@echo "--- Building and Signing helper for Local Development"
	swift build
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/arm64-apple-macosx/debug/hostmgr-helper -v

run-helper-debug: build-helper-debug
	./.build/arm64-apple-macosx/debug/hostmgr-helper --debug true

reload-helper-debug: build-helper-debug
	launchctl unload ~/Library/LaunchAgents/com.hostmgr.helper.plist
	launchctl load ~/Library/LaunchAgents/com.hostmgr.helper.plist

run-helper: build-helper-debug reload-helper-debug
