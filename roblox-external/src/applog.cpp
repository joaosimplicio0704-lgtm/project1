#include "applog.h"

#include <windows.h>

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <mutex>

namespace applog {

namespace {

std::recursive_mutex g_mutex;
FILE*      g_file = nullptr;
uint64_t   g_lines = 0;

// teto de tamanho: 4 MB, depois reescreve do zero (nao deixa crescer sem fim)
constexpr long kMaxBytes = 4 * 1024 * 1024;

} // namespace

void Init(const char* file) {
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    if (g_file)
        return;

    const char* path = (file && *file) ? file : "roblox-external.log";

    // rotacao simples por tamanho
    FILE* probe = std::fopen(path, "rb");
    if (probe) {
        std::fseek(probe, 0, SEEK_END);
        const long size = std::ftell(probe);
        std::fclose(probe);
        if (size > kMaxBytes)
            std::remove(path);
    }

    g_file = std::fopen(path, "ab");
    if (!g_file)
        return;

    std::setvbuf(g_file, nullptr, _IOLBF, 4096);
    Line("=== roblox-external iniciado ===");
}

void Line(const char* fmt, ...) {
    if (!fmt)
        return;

    char message[1024]{};
    va_list args;
    va_start(args, fmt);
    std::vsnprintf(message, sizeof(message), fmt, args);
    va_end(args);

    SYSTEMTIME st{};
    GetLocalTime(&st);

    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    if (!g_file)
        return;

    std::fprintf(g_file, "[%02d:%02d:%02d.%03d] %s\n", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
                 message);
    ++g_lines;
}

void Shutdown() {
    std::lock_guard<std::recursive_mutex> lock(g_mutex);
    if (!g_file)
        return;

    Line("=== encerrado (%llu linhas) ===", static_cast<unsigned long long>(g_lines));
    std::fclose(g_file);
    g_file = nullptr;
}

} // namespace applog
