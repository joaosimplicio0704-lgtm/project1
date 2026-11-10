cmake_minimum_required(VERSION 3.16)
project(ss_process_tools LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(ss_process_tools STATIC
    ProcessHandle.cpp
    ThreadHandleMonitor.cpp
)
target_include_directories(ss_process_tools PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(ss_demo demo.cpp)
target_link_libraries(ss_demo PRIVATE ss_process_tools)

if(MSVC)
    target_compile_options(ss_process_tools PRIVATE /utf-8 /W4)
    target_compile_options(ss_demo PRIVATE /utf-8 /W4)
endif()
