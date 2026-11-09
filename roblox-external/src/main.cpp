#include <windows.h>

#include <cstdio>

#include "config.h"
#include "features/esp.h"
#include "imgui/imgui.h"
#include "menu/menu.h"
#include "offsets.h"
#include "overlay/overlay.h"
#include "stealth/StealthyOpenProcess.h"
#include "stealth/handle_cleanup.h"

namespace {

// debounce de tecla: dispara uma vez por aperto
bool PressedOnce(int vk) {
    static bool state[256]{};
    if (vk < 0 || vk > 255)
        return false;

    const bool down = (GetAsyncKeyState(vk) & 0x8000) != 0;
    const bool pressed = down && !state[vk];
    state[vk] = down;
    return pressed;
}

} // namespace

int main() {
    SetConsoleTitleA("roblox-external");
    std::printf("roblox-external — offsets %s\n", rbx::kVersion);
    std::printf("INSERT menu | F1 esp | F2 caixa | END sair\n\n");

    cfg::Settings settings;
    if (cfg::Load(settings))
        std::printf("[cfg] config.json carregado\n");

    StealthyOpenProcess::Initialize();

    bool handleWatchRunning = false;
    if (settings.handleWatch && HandleCleanup::Start()) {
        handleWatchRunning = true;
        std::printf("[handle] monitor de handles orfaos ativo\n");
    }

    Esp esp;
    if (esp.Initialize(settings))
        std::printf("[mem] conectado (pid %lu, base 0x%llX)\n",
                    static_cast<unsigned long>(esp.Pid()),
                    static_cast<unsigned long long>(esp.Base()));
    else
        std::printf("[mem] %s — o loop tenta reatachar a cada segundo\n", esp.Status());

    Overlay overlay;
    if (!overlay.Initialize()) {
        std::printf("[d3d] falha ao criar device/swapchain\n");
        MessageBoxW(nullptr, L"Falha ao inicializar D3D11 (driver ou VM sem GPU).",
                    L"roblox-external", MB_ICONERROR);
        HandleCleanup::Stop();
        StealthyOpenProcess::Shutdown();
        return 1;
    }

    bool menuOpen = false;
    bool running = true;

    while (running && overlay.Pump()) {
        if (PressedOnce(cfg::kExitKey))
            break;

        if (PressedOnce(cfg::kMenuKey)) {
            menuOpen = !menuOpen;
            overlay.SetInteractive(menuOpen);
        }
        if (PressedOnce(cfg::kEspKey))
            settings.espEnabled = !settings.espEnabled;
        if (PressedOnce(cfg::kBoxKey))
            settings.boxes = !settings.boxes;

        if (settings.handleWatch && !handleWatchRunning) {
            handleWatchRunning = HandleCleanup::Start();
        } else if (!settings.handleWatch && handleWatchRunning) {
            HandleCleanup::Stop();
            handleWatchRunning = false;
        }

        overlay.BeginFrame();

        esp.Tick();
        esp.Draw(ImGui::GetBackgroundDrawList(), overlay.Width(), overlay.Height());
        menu::Draw(settings, esp, overlay, &menuOpen);

        // menu fechado pelo X da janela tambem devolve o mouse pro jogo
        if (!menuOpen && overlay.IsInteractive())
            overlay.SetInteractive(false);

        overlay.EndFrame();

        Sleep(static_cast<DWORD>(settings.tickMs > 0 ? settings.tickMs : 1));
    }

    std::printf("[exit] fechando\n");
    HandleCleanup::Stop();
    esp.Shutdown();
    overlay.Shutdown();
    StealthyOpenProcess::Shutdown();
    return 0;
}
