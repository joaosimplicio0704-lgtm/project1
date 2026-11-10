cmake_minimum_required(VERSION 3.24)
project(FortniteExternal VERSION 1.0.0 LANGUAGES CXX)

set(FORTNITE_D3DCOMPILER_LIBRARY d3dcompiler CACHE STRING "D3D shader compiler import library")

if(NOT WIN32)
    message(FATAL_ERROR "FortniteExternal must be built for Windows x64")
endif()

include(FetchContent)
FetchContent_Declare(
    imgui
    GIT_REPOSITORY https://github.com/ocornut/imgui.git
    GIT_TAG v1.91.5
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(imgui)

add_library(imgui STATIC
    ${imgui_SOURCE_DIR}/imgui.cpp
    ${imgui_SOURCE_DIR}/imgui_demo.cpp
    ${imgui_SOURCE_DIR}/imgui_draw.cpp
    ${imgui_SOURCE_DIR}/imgui_tables.cpp
    ${imgui_SOURCE_DIR}/imgui_widgets.cpp
    ${imgui_SOURCE_DIR}/backends/imgui_impl_dx11.cpp
    ${imgui_SOURCE_DIR}/backends/imgui_impl_win32.cpp
)
target_include_directories(imgui PUBLIC
    ${imgui_SOURCE_DIR}
    ${imgui_SOURCE_DIR}/backends
)
target_compile_features(imgui PUBLIC cxx_std_17)
target_link_libraries(imgui PUBLIC d3d11 dxgi)

add_executable(FortniteExternal WIN32
    src/Config.cpp
    src/Game.cpp
    src/Input.cpp
    src/Overlay.cpp
    src/ProcessHandle.cpp
    src/StealthyOpenProcess.cpp
    src/closehandle.cpp
)
target_compile_features(FortniteExternal PRIVATE cxx_std_17)
target_link_libraries(FortniteExternal PRIVATE imgui d3d11 ${FORTNITE_D3DCOMPILER_LIBRARY} dxgi dwmapi user32 gdi32)

add_executable(FortLoader src/Loader.cpp)
target_compile_features(FortLoader PRIVATE cxx_std_17)

if(MSVC)
    target_compile_options(FortniteExternal PRIVATE /W4 /permissive- /EHsc /utf-8)
    target_compile_options(imgui PRIVATE /W3 /EHsc /utf-8)
    target_compile_options(FortLoader PRIVATE /W4 /permissive- /EHsc /utf-8)
else()
    target_compile_options(FortniteExternal PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(FortLoader PRIVATE -Wall -Wextra -Wpedantic)
endif()
