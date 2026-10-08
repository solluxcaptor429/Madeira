# Building the IPA with GitHub Actions

`.github/workflows/ios-build.yml` builds an **unsigned** Madeira IPA on
GitHub's hosted `macos-15` runners, so no Mac is needed. Public repositories
get these runners for free. The workflow is adapted from the CI of the
Axoled-Student/Madeira fork, which was itself adapted from
arjunyerevan95-dot/Madeira, and updated for the current tree.

## Running it

- **Automatic:** every push to `windows-d3d12-build` or to a `ci/...` branch
  starts a build, except pushes that change only `docs/`, `research/`, `tests/`
  or Markdown files.
- **Manual:** once the workflow file is on the default branch, the Actions tab
  also offers **Run workflow**, with a Debug or Release choice. Debug is the
  default, because `docs/BUILDING.md` records Release builds crashing the guest.

When the run finishes, download the **Madeira-iPhone** artifact. It is kept for
30 days and contains:

| File | What it is |
|---|---|
| `Madeira-<commit>-unsigned.ipa` | The app. Sign it with your own Apple ID in SideStore, AltStore, Sideloadly or a similar tool. |
| `d3d12.dll` | The D3D12 runtime from the same commit, on its own. Put it next to a game's `.exe` to test D3D12 changes on an installed Madeira without reinstalling. |
| `SHA256SUMS`, `BUILD-NOTES.txt`, `Madeira.entitlements`, `source-commit.txt`, `submodule-commits.txt` | What was built, and from what. |

## How it is built

The job graph is four dependency jobs that run in parallel, followed by one app
job.

| Job | Builds | Rebuilt when these change |
|---|---|---|
| `fex` | `FEX/build-ios` static libraries, with `patches/fex-native-*.patch` applied when they still apply | the FEX submodule, `build/fex-ios`, `patches/` |
| `llvm` | LLVM 15.0.7 libraries for iOS (DXMT's airconv) | `scripts/ci-build-llvm.sh` |
| `wine` | `libwineserver.a`, `libntdll_unix.a`, `libwin32u_unix.a`, FreeType, the FFmpeg archives | the wine submodule, `build/{ntdll-unix,win32u-unix,wineserver,madsync,hidpad,crypto-unix,ffmpeg,gnutls-ios,freetype-ios}`, `build/madeira_cfg.h`, `app/Madeira/Winios` |
| `i386` | The 32-bit Windows farm, `app/Madeira/i386-windows` | the wine and dxmt submodules, `build/wine-i386` |
| app | The DXMT and madeira-d3d12 unix side, `d3d12.dll`/`d3d12core.dll` from source, Madeira Dock, the Rust pairing library, then `xcodebuild` | always |

The CI scripts themselves are also part of every dependency's key. Each
dependency is cached on exactly those inputs (`scripts/ci-cache-key.sh`). When
you add an input to a dependency's build, add it to that key too, or a stale
cached build will be used.

Two inputs that no committed script produces are made in CI:

- **The base `libwineserver.a`:** `build/wineserver/build.sh` now compiles the
  unpatched server sources listed in `wine/server/Makefile.in` when no base
  archive exists.
- **`wine/build-macos`:** the configured tree whose headers the unix-side
  scripts read.

The other Wine PE modules under `app/Madeira/*-windows` are the committed ones.

## Logs

Any failed job uploads a `logs-<job>` artifact. It contains the build log,
`config.log`, and the per-file compile errors.

## Not covered

- **Signing and entitlements:** the IPA is unsigned and carries no
  entitlements. A development signature from your sideloading tool provides
  `get-task-allow`, which JIT needs.
- **Microsoft's Visual C++ runtime DLLs** are not bundled
  (`tools/fetch-vcruntime.md`).
- **Wine Mono** is not bundled; the app downloads it when a .NET program needs
  it.
- **Game compatibility:** a successful build shows that everything compiles,
  links and packages. It says nothing about compatibility on a device.
