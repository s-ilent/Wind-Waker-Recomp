# Historical RecompCore patches

These patches record BlueWake's RecompCore changes as they were made. They are history, not a build
input: the series starts at 0008 (0001-0007 were never exported), so it does not apply to the
upstream base 5c3611e, and the local head it led to (3476998) was never published.

The build uses a fork instead. BlueWake's is https://github.com/chrissotraidis/RecompCore, branch
`bluewake`, commit 2d6063614a9bc899f6b4d11c7e7b3cd66e4d96f3: it contains the changes here through 0097
(some were revised by later ones), the files that were never committed on the development Mac, and the
DolRecomp submodule pointing at https://github.com/chrissotraidis/DolRecomp (5c91d6e). Wind Waker Recomp
builds from its own copy, https://github.com/elliotttate/RecompCore, branch `bluewake`, commit
8ab24da: that tree plus 0098 to 0112, with DolRecomp at https://github.com/elliotttate/DolRecomp
(b8b5345, 5c91d6e plus patches/dolrecomp/0019). The Builder fetches it at the commit pinned in
`scripts/builder/profiles/bluewake.sh`; see docs/status/DEVICE_BUILD.md.

0113 is newer than the pinned fork and is not in it yet: it fixes a Linux-only compile error in the
Aurora fork (a `wgpu::VertexBufferLayout` designated initializer written out of declaration order,
which GCC rejects and MSVC does not) and is recorded here for the companion RecompCore pull request.
Until that lands and `RECOMPCORE_SHA` is bumped, a Linux Builder run stops at the pinned-source check
in `bw_fetch_game_sources` with `ref/recompcore` carrying the same one-line change locally.

0114 is newer than the pinned fork and is not in it yet, like 0113: it moves SDL's joystick, gamepad and sensor
enumeration onto SDL's own thread (SDL_HINT_JOYSTICK_THREAD), which otherwise runs inside SDL_PumpEvents on the
presenting thread and has held the game for seconds at a time on desktops with many HID devices. Recorded here for
the companion RecompCore pull request.
