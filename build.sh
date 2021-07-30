#!/bin/bash

BUILDDIR=.build/artifacts/release
mkdir -p $BUILDDIR
echo $BUILDDIR
swift build -c release

cp .build/release/hostmgr $BUILDDIR/hostmgr
cp Sources/hostmgr/resources/com.automattic.hostmgr.sync.plist $BUILDDIR/
cp Sources/hostmgr/resources/com.automattic.hostmgr.git-mirror-sync.plist $BUILDDIR/
cp Sources/hostmgr/resources/com.automattic.hostmgr.git-mirror-server.plist $BUILDDIR/

tar -czf hostmgr.tar.gz -C $BUILDDIR .
mv hostmgr.tar.gz .build/artifacts/hostmgr.tar.gz

rm -rf $BUILDDIR

echo "Build complete: .build/artifacts/hostmgr.tar.gz"
echo "  Checksum: $(sha256sum .build/artifacts/hostmgr.tar.gz | cut -f1 -d ' ')"
