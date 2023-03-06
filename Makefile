.DEFAULT_GOAL := lint

RELEASE_VERSION = $(shell swift run hostmgr --version)

build-release:
	@echo "--- Building Release"
	swift build -c release --arch arm64 --arch x86_64

	mkdir -p .build/artifacts/release
	cp .build/apple/Products/Release/hostmgr .build/artifacts/release/hostmgr
	cp .build/apple/Products/Release/hostmgr-helper .build/artifacts/release/hostmgr-helper

	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API (886NX39KP6)" .build/artifacts/release/hostmgr --force --verbose
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API (886NX39KP6)" .build/artifacts/release/hostmgr-helper --force --verbose

release: build-release
	@echo "--- Tagging Release"
	git tag $(RELEASE_VERSION)
	git push origin $(RELEASE_VERSION)

create-vm-debug:
	@echo "--- Building and Signing hostmgr for Local Development"
	swift build
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/arm64-apple-macosx/debug/hostmgr -v

	./.build/arm64-apple-macosx/debug/hostmgr vm create xcode-143 --disk-size 92

build-debug:
	@echo "--- Building and Signing for Local Development"
	swift build
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/arm64-apple-macosx/debug/hostmgr -v

build-helper-debug:
	@echo "--- Building and Signing helper for Local Development"
	swift build
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/arm64-apple-macosx/debug/hostmgr-helper -v

run-helper-debug: build-helper-debug
	./.build/arm64-apple-macosx/debug/hostmgr-helper --debug true

reload-helper-debug: build-helper-debug
	launchctl unload ~/Library/LaunchAgents/com.automattic.hostmgr.helper.plist
	launchctl load ~/Library/LaunchAgents/com.automattic.hostmgr.helper.plist

run-helper: build-helper-debug reload-helper-debug

## High-level operations
lint: lint-swift lint-ruby
lintfix: lintfix-swift lintfix-ruby

## Swift Tooling
lint-swift:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.50.3 swiftlint lint --strict

lintfix-swift:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.50.3 swiftlint --autocorrect

## Ruby Tooling
lint-ruby:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ruby:2.7.7 /bin/bash -c "bundle install && bundle exec rubocop"

lintfix-ruby:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ruby:2.7.7 /bin/bash -c "bundle install && bundle exec rubocop --autocorrect"
