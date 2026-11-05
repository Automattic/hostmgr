#!/usr/bin/env bash

set -euo pipefail

target="$1"

certificate_name() {
  awk -F ' = ' -v key="$1" '$1 == key { print $2 }' Makefile
}

debug_identity="$(certificate_name CERTIFICATE_NAME_DEBUG)"
release_identity="$(certificate_name CERTIFICATE_NAME_RELEASE)"

if [[ -z "$debug_identity" || -z "$release_identity" ]]; then
  echo "FAIL: could not read the certificate names from the Makefile"
  exit 1
fi

identities() {
  security find-identity -v -p codesigning
}

assert_identity_present() {
  local listed
  listed="$(identities)"
  echo "$listed"
  if ! grep -qF "\"$1\"" <<<"$listed"; then
    echo "FAIL: expected identity '$1' is not in the keychain"
    exit 1
  fi
  echo "OK: found '$1'"
}

assert_identity_absent() {
  local listed
  listed="$(identities)"
  echo "$listed"
  if grep -qF "\"$1\"" <<<"$listed"; then
    echo "FAIL: identity '$1' should not be in the keychain"
    exit 1
  fi
  echo "OK: '$1' is absent"
}

echo "--- :lock: Identities before $target"
assert_identity_absent "$debug_identity"
assert_identity_absent "$release_identity"

echo "--- :rubygems: Installing gems"
install_gems

echo "--- :closed_lock_with_key: make $target"
make "$target"

echo "--- :mag: Identities after $target"
case "$target" in
  fetch-codesigning)
    assert_identity_present "$debug_identity"
    assert_identity_present "$release_identity"
    ;;
  fetch-codesigning-debug)
    assert_identity_present "$debug_identity"
    assert_identity_absent "$release_identity"
    ;;
  fetch-codesigning-release)
    assert_identity_present "$release_identity"
    assert_identity_absent "$debug_identity"
    ;;
  *)
    echo "FAIL: unknown target '$target'"
    exit 1
    ;;
esac

if [[ "$target" == "fetch-codesigning-debug" ]]; then
  echo "--- :swift: make build-debug signs with the fetched certificate"
  install_swiftpm_dependencies
  make build-debug

  signature="$(codesign --display --verbose=2 "$(swift build -c debug --show-bin-path)/hostmgr" 2>&1)"
  echo "$signature"
  if ! grep -qF "Authority=$debug_identity" <<<"$signature"; then
    echo "FAIL: the debug binary was not signed by '$debug_identity'"
    exit 1
  fi
  echo "OK: debug binary signed by '$debug_identity'"
fi
