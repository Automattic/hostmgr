.DEFAULT_GOAL := lint

RELEASE_VERSION = $(shell .build/release/hostmgr --version)

lint:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.50.3 swiftlint lint --strict

lintfix:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.50.3 swiftlint --autocorrect

build-release:
	@echo "--- Building Release"
	swift build -c release

release: build-release
	@echo "--- Tagging Release"
	git tag $(RELEASE_VERSION)
	git push origin $(RELEASE_VERSION)

run-vm-create-debug:
	@echo "--- Building and Signing hostmgr for Local Development"
	swift build
	codesign --entitlements Sources/hostmgr/hostmgr.entitlements -s "Apple Development: Created via API" .build/arm64-apple-macosx/debug/hostmgr -v
	./.build/arm64-apple-macosx/debug/hostmgr vm create --name test
