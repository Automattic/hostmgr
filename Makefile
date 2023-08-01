.DEFAULT_GOAL := lint

RELEASE_VERSION = $(shell .build/release/hostmgr --version)

lint:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.47.1 swiftlint lint --strict

lintfix:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.47.1 swiftlint --autocorrect

build:
	@echo "--- Building Release"
	swift build -c release --arch arm64 --arch x86_64

release: build-release
	@echo "--- Tagging Release"
	git tag $(RELEASE_VERSION)
	git push origin $(RELEASE_VERSION)
