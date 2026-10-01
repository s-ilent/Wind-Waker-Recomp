# BlueWake Linux profile: the same game as bluewake.sh, built as a native
# Linux app (bluewake_host, Aurora rendering through Dawn's Vulkan backend and
# SDL3). Sources the game profile for the disc, translator, composite and mod
# hooks, then overrides the platform ones. See docs/LINUX.md.
#
#   scripts/builder/build.sh DISC.iso --game bluewake-linux

# Inherit the game's identity, digests and pinned sources.
# shellcheck source=bluewake.sh
. "$root/scripts/builder/profiles/bluewake.sh"

PROFILE_NAME=bluewake-linux
PROFILE_MODULE=gGZLE01_recomp.so
PROFILE_DEFAULT_OUT=build/linux
# The bundled optimization profiles were trained on Apple silicon, so they do
# not apply to a Linux build; it compiles without PGO and runs a little slower.
PROFILE_COMPOSITE_PGO=
PROFILE_HOST_PGO=

profile_check_tools() {
    # clang provides the PGO instrumentation and the module compile when a
    # profile is supplied; a plain gcc build works without them.
    if [ ${#composite_pgo[@]} -gt 0 ] && ! command -v llvm-profdata >/dev/null 2>&1; then
        die "--composite-pgo on Linux needs llvm-profdata in PATH (llvm or clang-tools package)"
    fi
}

# The Externals submodules the donor DSP build needs on Linux (Qt, FFmpeg and
# the other frontend-only ones are not built; see docs/LINUX.md).
BW_DONOR_SUBMODULES="Externals/cpp-ipc/cpp-ipc Externals/cpp-optparse/cpp-optparse \
Externals/fmt/fmt Externals/xxhash/xxHash Externals/zlib-ng/zlib-ng Externals/zstd \
Externals/lz4 Externals/bzip2/bzip2 Externals/minizip-ng Externals/libspng \
Externals/pugixml/pugixml Externals/glslang Externals/spirv_cross/SPIRV-Cross \
Externals/VulkanMemoryAllocator Externals/Vulkan-Headers Externals/gtest \
Externals/cubeb Externals/libusb/libusb Externals/hidapi/hidapi-src \
Externals/enet Externals/SFML/SFML Externals/curl Externals/miniupnpc \
Externals/rcheevos/rcheevos Externals/imgui/imgui Externals/implot/implot \
Externals/tinygltf/tinygltf Externals/watcher Externals/wil"

profile_dependencies() {
    bw_fetch_game_sources
    # The donor DSP: RecompCore's core library built with interprocedural
    # optimization (the DSP object set only links against an IPO donor; see
    # runtime/host/CMakeLists.txt). Built inside the private build directory
    # so ref/ stays at the pinned source exactly.
    if [ ! -f "$out/dsp-donor/Source/Core/Core/libcore.a" ]; then
        run donor-submodules git -C "$recompcore" submodule update --init --depth 1 \
            ${BW_DONOR_SUBMODULES}
        run donor-configure cmake -S "$recompcore" -B "$out/dsp-donor" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
            -DENABLE_QT=OFF -DENABLE_TESTS=OFF -DENABLE_NOGUI=OFF \
            -DENABLE_ALSA=OFF -DENABLE_PULSEAUDIO=OFF -DENABLE_CUBEB=OFF \
            -DENABLE_LLVM=OFF -DENABLE_VULKAN=OFF -DUSE_UPNP=OFF \
            -DUSE_DISCORD_PRESENCE=OFF -DUSE_MGBA=OFF -DENABLE_AUTOUPDATE=OFF \
            -DUSE_RETRO_ACHIEVEMENTS=OFF -DENCODE_FRAMEDUMPS=OFF
        run donor-build cmake --build "$out/dsp-donor" --target core -j "$jobs"
    fi
    echo "donor DSP core: $out/dsp-donor"
    # Dawn (pinned prebuilt, linux-x86_64) and SDL3 are fetched and wired by
    # the app's CMake through Aurora's providers: package for Dawn, and system
    # SDL3 3.4+ or a vendored build from source (docs/LINUX.md).
    echo "Dawn linux-x86_64 and SDL3 are provided by the app build's CMake"
}

profile_train() {
    # Local training builds and plays a headless host on the Mac. The Linux
    # host can train too, but that is not wired up yet; the build proceeds
    # without a game profile (about 10 percent slower; docs/LINUX.md).
    echo "skipped: local optimization training is not supported on Linux yet"
}

profile_compile() {
    local flags=""
    if [ ${#composite_pgo[@]} -gt 0 ]; then
        run composite-pgo-merge llvm-profdata merge -o "$out/composite.profdata" "${composite_pgo[@]}"
        # The profile is a compiler input but not a C header dependency. Put
        # its hash in the flag so Ninja recompiles when the counters change.
        local profile_hash profile_path
        profile_hash=$(sha256_file "$out/composite.profdata")
        mkdir -p "$out/profiles"
        profile_path=$out/profiles/composite-$profile_hash.profdata
        cp "$out/composite.profdata" "$profile_path"
        flags="$(pgo_flags "$profile_path")"
        echo "with the composite profile(s): ${composite_pgo[*]}"
    fi
    run composite-configure cmake -S cmake/composite -B "$out/composite" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_FLAGS=$flags" \
        -DCOMPOSITE_OPTIMIZATION_LEVEL="$opt_level" \
        -DCOMPOSITE_DIR="$out/composite-src" -DGXRUNTIME_DIR="$recompcore/GXRuntime" \
        -DABI_DIR="$recompcore/Source/Core/Core/PowerPC/StaticRecomp"
    run composite-build cmake --build "$out/composite" -j "$jobs"
    module=$out/composite/$PROFILE_MODULE
}

profile_build_app() {
    local host_flags=""
    if [ -n "$host_pgo" ]; then
        local profile_hash profile_path
        profile_hash=$(sha256_file "$host_pgo")
        mkdir -p "$out/profiles"
        profile_path=$out/profiles/host-$profile_hash.profdata
        cp "$host_pgo" "$profile_path"
        host_flags=$(pgo_flags "$profile_path")
        echo "with the host profile $host_pgo"
    fi
    run app-configure cmake -S runtime/host -B "$out/app" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_FLAGS=$host_flags" "-DCMAKE_CXX_FLAGS=$host_flags" \
        -DBLUEWAKE_ENABLE_DSP_ADAPTER=ON -DBLUEWAKE_ENABLE_DSP_IPO=OFF \
        -DBLUEWAKE_DSP_DONOR_DIR="$recompcore" \
        -DBLUEWAKE_DSP_DONOR_BUILD_DIR="$out/dsp-donor"
    run app-build cmake --build "$out/app" --target bluewake_host -j "$jobs"
    app=$out/app/bluewake_host
    # The launcher points the app at the translated module, the game files
    # extracted from the disc, the player's disc image (which the game
    # streams its files from while playing) and the donor DSP ROMs.
    cat > "$out/app/run.sh" <<EOF
#!/bin/sh
# BlueWake Linux launcher: runs the app from this build directory.
# The game reads its files from your own disc image while playing, so the
# launcher needs it once per session:
#   BLUEWAKE_DISC=/path/to/your/Wind-Waker.iso ./run.sh
cd "\$(dirname "\$0")" || exit 1
if [ -z "\${BLUEWAKE_DISC:-}" ]; then
    echo "run.sh: set BLUEWAKE_DISC to your Wind Waker disc image" \\
        "(GZLE01, USA, revision 0) and rerun, e.g." >&2
    echo "  BLUEWAKE_DISC=/path/to/disc.iso ./run.sh" >&2
    exit 1
fi
BLUEWAKE_ROOT="$out/game" \\
BLUEWAKE_DOL="$out/game/main.dol" \\
BLUEWAKE_RELS_DIR="$out/game/rels" \\
BLUEWAKE_DSP_IROM="$recompcore/Data/Sys/GC/dsp_rom.bin" \\
BLUEWAKE_DSP_COEF="$recompcore/Data/Sys/GC/dsp_coef.bin" \\
exec ./bluewake_host "\$PWD/$PROFILE_MODULE" "\$@"
EOF
    chmod +x "$out/app/run.sh"
}
