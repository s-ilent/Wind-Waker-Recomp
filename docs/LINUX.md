# Linux

Wind Waker Recomp runs natively on Linux as `bluewake_host`, a plain window app
rendered through the same Aurora renderer as the Windows and Mac builds: WebGPU
via [Dawn](https://dawn.googlesource.com/dawn/), which uses **Vulkan** here, with
**SDL3** for the window, input and controllers. The game code, translator,
runtime, mods and tests are identical to the other platforms.

Like everywhere else: bring your own legally obtained disc (GZLE01, USA,
revision 0). Nothing in the repository or the build downloads game data.

## What is supported

- Building the app (`bluewake_host`), the game module and the translator on
  x86-64 (aarch64 works the same way; nothing here is x86-specific)
- The full Builder pipeline: `scripts/builder/build.sh DISC.iso --game bluewake-linux`
  produces the translated game module, the app and a `run.sh` launcher
- The whole test suite (216 CTest cases)
- Widescreen and Better Wind Waker mods, save states, controllers, mouse camera

## Not yet on Linux

- **Compressed disc images**: the Builder and the runtime read raw `.iso`/`.gcm`
  only. Convert a `.gcm`/`.gcz`/`.rvz` first with Dolphin (**right-click the
  game › Convert… › ISO**, or `dolphin-tool convert --format RAW` if packaged).
- **Local optimization training** (`profile_train`): the Builder skips it, so a
  Linux build compiles the game module without a profile and plays a little
  slower. Pass `--no-pgo` to the same effect; the flag is not needed.
- **A packaged release**: you run the app from the build directory with the
  generated launcher; there is no installer or AppImage yet.
- **Use the native Wayland session.** Forcing `SDL_VIDEODRIVER=x11` hangs in
  Xlib window creation with the DSP build (blocked in `XIfEvent`); the same
  binary runs correctly on Wayland.
- **Exit skips GPU teardown.** On Wayland, NVIDIA's userspace driver crashes
  inside Dawn's device destruction (wl_proxy calls on a dead connection), so
  on Linux the host saves and closes everything, then leaves the device to
  process exit. Saves and settings are unaffected.

## Build it yourself

### Dependencies

Any recent distribution. You need:

- CMake 3.25+, Ninja, git, curl, python3
- A C/C++ compiler (gcc or clang)
- SDL3 (3.4 or newer): from your distribution (`sdl3`/`libsdl3-dev`) or let the
  build compile a pinned copy from source automatically (needs the usual X11,
  Wayland and audio development packages for a windowed build, for example on
  Debian/Ubuntu: `libx11-dev libxext-dev libwayland-dev libxkbcommon-dev
  libasound2-dev libpulse-dev libdbus-1-dev`)
- Vulkan loader and drivers at runtime (`vulkan-tools`' `vulkaninfo` is a good
  check); the Dawn package is downloaded prebuilt by the build itself

Arch Linux ships it as `sdl3`, Debian/Ubuntu as `libsdl3-dev` where packaged,
Fedora as `SDL3-devel`; otherwise let the build compile its pinned SDL3 from
source as described above.

### Build and run, with your own disc

```sh
git clone https://github.com/elliotttate/Wind-Waker-Recomp.git
cd Wind-Waker-Recomp
scripts/builder/build.sh "/path/to/The Legend Of Zelda The Wind Waker.iso" \
    --game bluewake-linux
```

This extracts and translates the game from your disc (the long step compiles
the translated code), builds `bluewake_host`, and leaves a private directory at
`build/linux/` containing:

- `app/bluewake_host` — the app
- `app/gGZLE01_recomp.so` — the translated game module, built from your disc
- `app/run.sh` — the launcher
- `app/BuilderProvenance.json` — what this build was made from

The game reads its files from your disc image while playing, so the launcher
needs it once per session:

```sh
BLUEWAKE_DISC="/path/to/The Legend Of Zelda The Wind Waker.iso" build/linux/app/run.sh
```

Everything the build produced stays in `build/linux/` (git-ignored); never
share or upload the module, it contains code translated from your disc.

Add `--source-only` to stop after the disc checks, translation and composite
generation — a few minutes, no app.

### Just the app and tests (no disc needed)

```sh
scripts/bootstrap.sh                       # clones the pinned sources into ref/
# One-line Linux compile fix in the vendored Aurora fork, not in the pinned
# RecompCore yet (see below). Drop this line once the companion PR has landed.
git -C ref/recompcore apply patches/recompcore/0113-aurora-vertex-buffer-layout-designators-in-header-order.patch
cmake -S runtime/host -B build/linux -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/linux -j"$(nproc)"
ctest --test-dir build/linux --output-on-failure
```

Without game data the app runs and exits with a message about `BLUEWAKE_DOL`;
that is expected. The same configure/build is what CI runs
(`.github/workflows/linux-build.yml`).

## One dependency lives in the RecompCore fork

The app builds against the pinned RecompCore checkout (`ref/recompcore`), which
carries GXRuntime and the vendored Aurora fork. A Linux compile of that tree
needs the one-line fix recorded as
[patches/recompcore/0113](../patches/recompcore/0113-aurora-vertex-buffer-layout-designators-in-header-order.patch);
until the companion RecompCore pull request lands and `RECOMPCORE_SHA` is
bumped in `scripts/builder/profiles/bluewake.sh`, a full Builder run stops at
the pinned-source check. The app-and-tests build above works the same way: apply
0113 to `ref/recompcore` locally while the companion PR is open.
