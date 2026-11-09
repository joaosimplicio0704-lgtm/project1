#include <windows.h>

#include <cstdio>

#include "config.h"
#include "features/aim.h"
#include "features/detector.h"
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
    std::printf("INSERT menu | F1 esp | F2 caixa | END sair\n");
    std::printf("aim: configurar tecla/FOV/forca na aba Aim\n\n");

    cfg::Settings settings;
    if (cfg::Load(settings))
        std::printf("[cfg] config carregado (%d perfis de jogo)\n", static_cast<int>(settings.profiles.size()));

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

    overlay.SetGamePid(esp.Pid());

    Detector  detector;
    AimAssist aim;

    bool  menuOpen = false;
    bool  running = true;
    uint64_t lastPlaceId = 0;

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

        overlay.SetGamePid(esp.Pid());

        overlay.BeginFrame();

        esp.Tick();
        detector.Tick(esp.Mem(), esp.DataModel(), esp.TargetCount());

        // entrou em outro jogo: aplica o perfil salvo daquele PlaceId, se existir
        const GameInfo& game = detector.Info();
        if (game.valid && game.placeId != lastPlaceId) {
            lastPlaceId = game.placeId;
            if (const cfg::Profile* profile = cfg::FindProfile(settings, game.placeId)) {
                cfg::ApplyProfile(settings, *profile);
                std::printf("[jogo] place %llu — perfil aplicado\n",
                            static_cast<unsigned long long>(game.placeId));
            } else {
                std::printf("[jogo] place %llu (sem perfil salvo)\n",
                            static_cast<unsigned long long>(game.placeId));
            }
        }

        ImDrawList* drawList = ImGui::GetBackgroundDrawList();
        esp.Draw(drawList, overlay.Width(), overlay.Height());

        aim.Tick(settings, esp, overlay.Width(), overlay.Height(), overlay.IsInteractive());
        aim.DrawFov(drawList, settings, overlay.Width(), overlay.Height());

        menu::Draw(settings, esp, overlay, detector, &menuOpen);

        // menu fechado pelo X da janela tambem devolve o mouse pro jogo
        if (!menuOpen && overlay.IsInteractive())
            overlay.SetInteractive(false);

        overlay.EndFrame();

        // menu aberto: frame curto, sem vsync — widget responde na hora
        Sleep(overlay.IsInteractive() ? 1u : static_cast<DWORD>(settings.tickMs > 0 ? settings.tickMs : 1));
    }

    std::printf("[exit] fechando\n");
    aim.Reset();
    HandleCleanup::Stop();
    esp.Shutdown();
    overlay.Shutdown();
    StealthyOpenProcess::Shutdown();
    return 0;
}
