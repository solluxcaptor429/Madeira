#!/bin/bash
# Print the cache key of one CI dependency (fex, llvm, wine or i386) as
# "key=..." for $GITHUB_OUTPUT. The key covers everything that dependency's
# build reads: its submodule commits, the git trees of the build folders it
# uses, and the CI scripts. Anything not listed here does not rebuild it, so a
# new input of a dependency's build must be added to its line.
set -euo pipefail
cd "$(dirname "$0")/.."

# Bump to rebuild every dependency once.
VERSION=1

tree() { git rev-parse "HEAD:$1" 2>/dev/null || echo "absent:$1"; }
sub() { git ls-tree HEAD "$1" | awk '{print $3}'; }
files() { git hash-object "$@"; }

component="${1:?Expected fex, llvm, wine or i386}"
case "$component" in
  fex)  parts="$(sub FEX) $(tree build/fex-ios) $(tree patches)
               $(files scripts/ci-build-dependency.sh scripts/ci-common.sh)" ;;
  llvm) parts="$(files scripts/ci-build-llvm.sh scripts/ci-common.sh)" ;;
  wine) parts="$(sub wine) $(tree build/ntdll-unix) $(tree build/win32u-unix) $(tree build/wineserver)
               $(tree build/madsync) $(tree build/hidpad) $(tree build/crypto-unix) $(tree build/ffmpeg)
               $(tree build/gnutls-ios) $(tree build/freetype-ios) $(tree app/Madeira/Winios)
               $(files build/madeira_cfg.h scripts/ci-build-dependency.sh scripts/ci-common.sh)" ;;
  i386) parts="$(sub wine) $(sub dxmt) $(tree build/wine-i386)
               $(files scripts/ci-build-dependency.sh scripts/ci-common.sh)" ;;
  *) echo "Unknown dependency: $component" >&2; exit 2 ;;
esac
echo "key=ios-$component-v$VERSION-$(echo "$parts" | shasum -a 256 | cut -c1-40)"
