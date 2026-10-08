#!/bin/bash
# Build d3d12.dll and d3d12core.dll (ARM64EC) without a DXMT PE build: on a
# Windows host (Git Bash) for testing D3D12 changes without a Mac or a new
# IPA, and on macOS, where CI uses it to put the D3D12 runtime built from this
# tree into the app instead of the committed binaries.
#
# Differences from build-pe.sh:
# - the toolchain is llvm-mingw 20260421 (the release build-pe.sh pins): the
#   ucrt-x86_64 build on Windows, ucrt-macos-universal on macOS;
# - the winemetal import library is made from the committed
#   app/Madeira/arm64ec-windows/winemetal.dll, so no DXMT PE build is needed
#   (the dxmt submodule is still needed for winemetal.h);
# - no test executables.
#
# Only PE-side changes can be tested as a drop-in: a change that needs a new
# winemetal call or a change to the unix side needs a full app build.
#
# Usage: bash build/madeira-d3d12/build-pe-windows.sh [tag]
# The optional tag is appended to the build marker in the log's
# "[madeira-d3d12] device created:" line (default: " win-test").
# INSTALL=1 also copies both DLLs into app/Madeira/arm64ec-windows.
#
# Testing on a device: copy out-win/d3d12.dll next to the game's .exe (Files
# app, On My iPhone > Madeira). A native d3d12.dll in the program's folder is
# found before system32. Delete it to go back to the bundled one.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
case "$(uname -s)" in
    Darwin) TC_DEFAULT="$REPO_ROOT/toolchains/llvm-mingw-20260421-ucrt-macos-universal" ;;
    *)      TC_DEFAULT="$REPO_ROOT/toolchains/llvm-mingw-20260421-ucrt-x86_64" ;;
esac
TC="${MADEIRA_MINGW_WIN:-$TC_DEFAULT}"
SRC="$REPO_ROOT/madeira-d3d12/src/pe"
OUT="${OUT:-$REPO_ROOT/build/madeira-d3d12/out-win}"
TAG="${1:- win-test}"
PYTHON="$(command -v python3 || command -v python)"
CC="$TC/bin/arm64ec-w64-mingw32-clang"

[ -x "$CC" ] || [ -x "$CC.exe" ] || {
    echo "llvm-mingw not found at $TC" >&2
    echo "Extract llvm-mingw 20260421 (ucrt-x86_64.zip on Windows, ucrt-macos-universal.tar.xz on macOS) from" >&2
    echo "https://github.com/mstorsjo/llvm-mingw/releases/tag/20260421 into toolchains/." >&2
    exit 1
}
[ -f "$REPO_ROOT/dxmt/src/winemetal/winemetal.h" ] || {
    echo "dxmt/src/winemetal/winemetal.h missing: git submodule update --init --depth 1 dxmt" >&2
    exit 1
}
mkdir -p "$OUT"

# Same stub regeneration as build-pe.sh. The Windows release keeps d3d12.h in
# include/, the macOS one in generic-w64-mingw32/include/.
HEADER="$TC/generic-w64-mingw32/include/d3d12.h"
[ -f "$HEADER" ] || HEADER="$TC/include/d3d12.h"
"$PYTHON" "$SRC/gen_vtables.py" "$HEADER" "$SRC/madeira_d3d12_stubs.h" >/dev/null

echo "=== libwinemetal.a (import library from the committed winemetal.dll) ==="
{
    echo "LIBRARY winemetal.dll"
    echo "EXPORTS"
    "$TC/bin/llvm-readobj" --coff-exports "$REPO_ROOT/app/Madeira/arm64ec-windows/winemetal.dll" \
        | sed -n 's/^ *Name: \(.*\)$/\1/p'
} > "$OUT/winemetal.def"
"$TC/bin/llvm-dlltool" -m arm64ec -d "$OUT/winemetal.def" -l "$OUT/libwinemetal.a"
echo "  $(($(wc -l < "$OUT/winemetal.def") - 2)) exports"

echo "=== d3d12.dll (arm64ec) ==="
"$CC" -shared -O2 -Wall \
    "-DMADEIRA_D3D12_BUILD_TAG=\"$TAG\"" \
    -o "$OUT/d3d12.dll" "$SRC/madeira_d3d12.c" "$SRC/d3d12.def" \
    -I"$SRC" -I"$REPO_ROOT/madeira-d3d12/src" -I"$REPO_ROOT/dxmt/src/winemetal" \
    -L"$OUT" -lwinemetal -luuid -lole32
echo "  built $(wc -c < "$OUT/d3d12.dll") bytes: $OUT/d3d12.dll"
"$TC/bin/llvm-readobj" --file-headers "$OUT/d3d12.dll" | grep -q 'IMAGE_FILE_MACHINE_ARM64EC' \
    || { echo "d3d12.dll is not ARM64EC" >&2; exit 1; }

echo "=== d3d12core.dll (arm64ec) ==="
"$CC" -shared -O2 -Wall -o "$OUT/d3d12core.dll" "$SRC/d3d12core.c" "$SRC/d3d12core.def"
echo "  built $(wc -c < "$OUT/d3d12core.dll") bytes"

if [ "${INSTALL:-0}" = 1 ]; then
    cp "$OUT/d3d12.dll" "$OUT/d3d12core.dll" "$REPO_ROOT/app/Madeira/arm64ec-windows/"
    echo "  installed into app/Madeira/arm64ec-windows"
fi
