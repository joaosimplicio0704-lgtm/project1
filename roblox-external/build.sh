#!/usr/bin/env sh
# build cross-compile (zig / mingw-w64) -> build/RobloxExternal.exe
# linux: pip install ziglang && ZIG="python3 -m ziglang" ./build.sh
# windows/msys: use build.bat com MSVC
set -eu

ZIG="${ZIG:-zig}"
OUT="build/RobloxExternal.exe"

mkdir -p build

$ZIG c++ \
    -target x86_64-windows-gnu \
    -std=c++20 -O2 \
    -DWIN32_LEAN_AND_MEAN -DNOMINMAX -DUNICODE -D_UNICODE \
    -static \
    src/main.cpp \
    src/config.cpp \
    src/sdk/memory.cpp \
    src/stealth/StealthyOpenProcess.cpp \
    src/stealth/handle_cleanup.cpp \
    src/features/esp.cpp \
    src/features/aim.cpp \
    src/features/detector.cpp \
    src/features/trigger.cpp \
    src/features/memview.cpp \
    src/overlay/overlay.cpp \
    src/menu/menu.cpp \
    src/imgui/imgui.cpp \
    src/imgui/imgui_draw.cpp \
    src/imgui/imgui_tables.cpp \
    src/imgui/imgui_widgets.cpp \
    src/imgui/imgui_impl_win32.cpp \
    src/imgui/imgui_impl_dx11.cpp \
    -o "$OUT" \
    -ld3d11 -ldxgi -ld3dcompiler_47 -ldwmapi -lole32 -luuid -luser32 -lgdi32

echo "[ok] $OUT"
