#include <windows.h>

#include <iostream>
#include <string>
#include <string_view>

namespace {
    [[nodiscard]] std::wstring ModuleDirectory() {
        std::wstring path(32768, L'\0');
        const DWORD length = ::GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
        if (length == 0 || length >= path.size()) return {};
        path.resize(length);
        const std::size_t separator = path.find_last_of(L"\\/");
        return separator == std::wstring::npos ? std::wstring(L".") : path.substr(0, separator);
    }

    [[nodiscard]] bool FileExists(const std::wstring& path) {
        const DWORD attributes = ::GetFileAttributesW(path.c_str());
        return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
    }

    [[nodiscard]] std::wstring Quote(std::wstring_view value) {
        return L"\"" + std::wstring(value) + L"\"";
    }

    int Fail(const std::wstring& text) {
        std::wcerr << text << L'\n';
        ::MessageBoxW(nullptr, text.c_str(), L"FortLoader", MB_OK | MB_ICONERROR);
        return 1;
    }
}

int main() {
    ::SetConsoleOutputCP(CP_UTF8);
    const std::wstring directory = ModuleDirectory();
    if (directory.empty()) return Fail(L"Nao foi possivel localizar a pasta do loader.");

    const std::wstring executable = directory + L"\\FortniteExternal.exe";
    if (!FileExists(executable)) {
        return Fail(L"FortniteExternal.exe nao encontrado ao lado de FortLoader.exe.");
    }

    const std::wstring config = directory + L"\\fortnite-config.json";
    const bool loadConfig = FileExists(config);
    std::wstring commandLine = Quote(executable);
    if (loadConfig) commandLine += L" --load-config";

    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    const BOOL created = ::CreateProcessW(
        executable.c_str(),
        commandLine.data(),
        nullptr,
        nullptr,
        FALSE,
        0,
        nullptr,
        directory.c_str(),
        &startup,
        &process);

    if (!created) {
        const DWORD error = ::GetLastError();
        return Fail(L"Falha ao iniciar FortniteExternal.exe. Erro Windows: " + std::to_wstring(error) +
            L". Execute como administrador se o jogo estiver elevado.");
    }

    ::CloseHandle(process.hThread);
    ::CloseHandle(process.hProcess);
    std::cout << "FortniteExternal iniciado (PID " << process.dwProcessId << ").\n";
    std::cout << (loadConfig ? "Configuracao JSON carregada; aim e ESP continuam desligados.\n"
                             : "Nenhum JSON encontrado; usando configuracao padrao.\n");
    return 0;
}
