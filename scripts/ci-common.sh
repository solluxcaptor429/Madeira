#!/bin/bash
# Helpers shared by scripts/ci-build-*.sh on a hosted macOS runner. Source this
# file from the repository root; it is not meant to be executed.

# MADEIRA_XCODE (an Xcode.app path) when set, otherwise the newest released
# Xcode the runner image carries (betas are skipped), otherwise whatever
# xcode-select points at. The committed StikJIT.xcframework's swiftinterface
# uses module selectors (Swift::Sendable), which Xcode 26.3's Swift cannot
# parse, so the image has to carry a newer Xcode (macos-26 does).
madeira_select_xcode() {
  local pick="${MADEIRA_XCODE:-}"
  if [ -z "$pick" ]; then
    pick="$(ls -d /Applications/Xcode_[0-9]*.app 2>/dev/null | grep -vi beta | sort -V | tail -1 || true)"
  fi
  if [ -n "$pick" ] && [ -d "$pick" ]; then
    export DEVELOPER_DIR="$pick/Contents/Developer"
    echo "using $pick"
  else
    echo "warning: no versioned Xcode found; using $(xcode-select -p)" >&2
  fi
  ls -d /Applications/Xcode*.app 2>/dev/null || true
  xcodebuild -version
}

# llvm-mingw cross toolchain (Dock's x86-64 PE, Wine's PE-target configure).
# The tarball hash is the one pinned in docs/BUILDING.md.
madeira_fetch_llvm_mingw() {
  MADEIRA_MINGW=llvm-mingw-20260421-ucrt-macos-universal
  local dir="toolchains/$MADEIRA_MINGW"
  if [ ! -x "$dir/bin/x86_64-w64-mingw32-clang" ]; then
    mkdir -p toolchains
    curl --fail --location --retry 3 \
      "https://github.com/mstorsjo/llvm-mingw/releases/download/20260421/$MADEIRA_MINGW.tar.xz" \
      -o "toolchains/$MADEIRA_MINGW.tar.xz"
    echo "bd85a3975723815cef28dbbd2ca2cb0c926f6b348a12a0453f39f7af273cb3f7  toolchains/$MADEIRA_MINGW.tar.xz" \
      | shasum -a 256 -c -
    tar -xf "toolchains/$MADEIRA_MINGW.tar.xz" -C toolchains
    rm "toolchains/$MADEIRA_MINGW.tar.xz"
  fi
  export MADEIRA_MINGW_BIN="$PWD/$dir/bin"
}
