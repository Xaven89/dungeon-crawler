# Voxelith
C++20 / Vulkan 1.3 voxel engine. Design: `docs/design.md` (text export of the Claude doc "Voxelith Engine — Design & Implementation Document").
Progress, findings and next steps: `docs/HANDOVER.md`.

    source env.sh
    cmake --preset release && cmake --build --preset release -j6
    build/release/vx_tests                 # unit tests
    build/release/vx_bench                 # CPU edit throughput
    build/release/vx_demolish 20 700       # headless demolition benchmark of the generated tower
    build/release/vx_gravity_bench         # gravity sampler throughput, Surface re-bake
    build/release/voxelith --headless --screenshot out.png --preset 1
    build/release/voxelith --headless --manual --spot 6 --script "idle:60,jump,idle:540" --screenshot out.png   # scripted player (Phase 3 demo scene)
    build/release/voxelith --script tour    # windowed gravity tour (any key = take control)
    build/release/voxelith --headless --collapse 300 --screenshot out.png   # simulate the tower demolition first
    DISPLAY=:90 XAUTHORITY=/etc/X11/headless.xauth build/release/voxelith   # windowed (streamed with Sunshine)
    build/release/voxelith --headless --manual --spot 1 --time 0.75 --script "turn:-60,pitch:-14,fire:6,idle:220" --frames 150 --screenshot night.png   # night + forest fire
    build/release/vx_gpu_tests             # GPU tests (golden image, water, foliage, GI, TAA)

An AI can work with the engine through its MCP server: `voxelith --mcp` (`docs/MCP.md`, `.mcp.json` for Claude Code). Open tasks: `docs/TASKS.md`.

Guides: `docs/GUIDE.md` (running, controls, editor, projects, settings, replay), `docs/LUA_API.md` (level scripts). Try `build/release/voxelith --project projects/demo_level`.

Phase 4 keys (manual mode): F7 GI, F8 foliage, F9 TAA, F10 light shafts, N time of day, M stop the clock, Y rain, B torch (sets what you look at alight), 7 = liquid yard.

Tools live in ~/tools (LLVM/clang+libc++, CMake, Ninja, glslang, vcpkg). No sudo, no system compiler.

Packaging: `cpack --config build/release/CPackConfig.cmake` writes `Voxelith-<version>-Linux-x86_64.tar.gz`; unpack it, run `./voxelith` from the folder (it needs a Vulkan 1.3 driver and a glibc at least as new as the one it was built on; a demo project writes its `world.vxs` next to itself, so unpack it somewhere writable). Nightly checks: `tools/nightly.sh`. See `docs/GUIDE.md`.
