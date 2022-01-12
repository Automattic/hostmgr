#!/bin/bash -eu

# Install the `gh` binary if needed
if ! command -v gh &> /dev/null; then
	brew install gh
fi

swift build -c release --arch arm64 --arch x86_64
BUILDDIR=.build/artifacts/release
mkdir -p $BUILDDIR

cp .build/apple/Products/Release/hostmgr $BUILDDIR/hostmgr
tar -czf hostmgr.tar.gz -C $BUILDDIR .
mv hostmgr.tar.gz .build/artifacts/hostmgr.tar.gz

CHECKSUM=$(openssl sha256 .build/artifacts/hostmgr.tar.gz | awk '{print $2}')

echo "Build complete: .build/artifacts/hostmgr.tar.gz"
echo "  Checksum: $CHECKSUM"

gh auth status
gh release create $BUILDKITE_TAG --title $BUILDKITE_TAG --notes "Checksum: $CHECKSUM" .build/artifacts/hostmgr.tar.gz
