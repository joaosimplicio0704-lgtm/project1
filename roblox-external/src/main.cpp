#include <windows.h>

#include <cstdio>
#include <memory>

#include "config.h"
#include "features/aim.h"
#include "features/camerahack.h"
#include "features/detector.h"
#include "features/esp.h"
#include "features/fly.h"
#include "features/magnet.h"
#include "features/memview.h"
#include "features/trigger.h"
#include "imgui/imgui.h"
#include "applog.h"
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

// mira desenhada no centro: no jogo o cursor do sistema fica escondido,
// entao sem isso voce nao tem referencia de onde o tiro vai sair
void DrawCrosshair(ImDrawList* list, const cfg::Settings& settings, float width, float height) {
    if (!list || !settings.crosshair || width <= 0.f || height <= 0.f)
        return;

    const ImVec2 center(width * 0.5f, height * 0.5f);
    const float arm = settings.crosshairSize < 2.f ? 2.f : settings.crosshairSize;
    const float gap = 2.f;
    const ImU32 color = IM_COL32(0, 255, 130, 225);

    list->AddLine(ImVec2(center.x - arm, center.y), ImVec2(center.x - gap, center.y), color, 1.6f);
    list->AddLine(ImVec2(center.x + gap, center.y), ImVec2(center.x + arm, center.y), color, 1.6f);
    list->AddLine(ImVec2(center.x, center.y - arm), ImVec2(center.x, center.y - gap), color, 1.6f);
    list->AddLine(ImVec2(center.x, center.y + gap), ImVec2(center.x, center.y + arm), color, 1.6f);
    list->AddCircleFilled(center, 1.2f, color, 6);
}

bool ForegroundIsPid(DWORD pid) {
    const HWND foreground = GetForegroundWindow();
    if (!foreground)
        return false;

    DWORD owner = 0;
    GetWindowThreadProcessId(foreground, &owner);
    return owner == pid;
}

} // namespace

int main() {
    SetConsoleTitleA("roblox-external");
    applog::Init();
    applog::Line("[app] offsets %s", rbx::kVersion);

    std::printf("roblox-external — offsets %s\n", rbx::kVersion);
    std::printf("INSERT menu | F1 esp | F2 caixa | F10 panic | END sair\n");
    std::printf("aim/tiro/voo: configurar nas abas\n\n");

    cfg::Settings settings;
    if (cfg::Load(settings))
        std::printf("[cfg] config carregado (%d perfis de jogo)\n", static_cast<int>(settings.profiles.size()));

    // auto-save: qualquer mudanca no menu vira config.json depois de 800 ms parado
    cfg::Settings lastSaved = settings;
    uint64_t saveDirtyAt = 0;

    StealthyOpenProcess::Initialize();

    bool handleWatchRunning = false;
    if (settings.handleWatch && HandleCleanup::Start()) {
        handleWatchRunning = true;
        std::printf("[handle] monitor de handles orfaos ativo\n");
    }

    // o leitor roda em thread propria: nada de ReadProcessMemory no frame
    Esp esp;
    if (!esp.Initialize(settings))
        std::printf("[mem] leitor iniciado, sem processo ainda\n");

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
    MemView   memView;
    Trigger    trigger;
    Fly        fly;
    CameraHack cameraHack;
    Magnet     magnet;

    bool     menuOpen = false;
    bool     running = true;
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
        if (PressedOnce(VK_F5)) {
            const bool ok = cfg::Save(settings);
            std::printf("[cfg] salvar: %s\n", ok ? "ok" : "falhou");
            applog::Line("[cfg] F5 salvar: %s", ok ? "ok" : "falhou");
            if (ok)
                lastSaved = settings;
        }
        if (PressedOnce(VK_F9)) {
            const bool ok = cfg::Load(settings);
            std::printf("[cfg] carregar: %s\n", ok ? "ok" : "config nao existe");
            applog::Line("[cfg] F9 carregar: %s", ok ? "ok" : "nao existe");
            if (ok) {
                lastSaved = settings;
                saveDirtyAt = 0;
            }
        }

        // PANIC: desliga tudo que age na memoria/mouse e devolve o controle
        if (PressedOnce(cfg::kPanicKey)) {
            settings.aim.enabled = false;
            settings.fire.enabled = false;
            settings.fly.enabled = false;
            trigger.Reset();   // solta o botao esquerdo se estiver pressionado
            fly.Reset();
            cameraHack.Release(esp.Mem());   // CameraType/FOV/MaxFPS de volta
            magnet.Reset();
            aim.Reset();
            overlay.SetInteractive(false);
            menuOpen = false;
            std::printf("[panic] aim/tiro/voo desligados, mouse liberado\n");
            applog::Line("[panic] aim/tiro/voo desligados, mouse liberado");
        }

        // auto-save com debounce
        if (!cfg::Same(settings, lastSaved)) {
            if (!saveDirtyAt)
                saveDirtyAt = GetTickCount64();
            else if (GetTickCount64() - saveDirtyAt >= 800) {
                if (cfg::Save(settings)) {
                    lastSaved = settings;
                    std::printf("[cfg] auto-salvo\n");
                    applog::Line("[cfg] auto-salvo");
                }
                saveDirtyAt = 0;
            }
        } else {
            saveDirtyAt = 0;
        }

        if (settings.handleWatch && !handleWatchRunning) {
            handleWatchRunning = HandleCleanup::Start();
        } else if (!settings.handleWatch && handleWatchRunning) {
            HandleCleanup::Stop();
            handleWatchRunning = false;
        }

        esp.UpdateSettings(settings);
        const auto scene = esp.Snapshot();
        static const SceneSnapshot kEmptyScene;

        overlay.SetGamePid(esp.Pid());

        overlay.BeginFrame();

        const SceneSnapshot& view = scene ? *scene : kEmptyScene;
        const bool focused = ForegroundIsPid(esp.Pid());

        detector.Tick(esp.Mem(), view.dataModel, view.playerCount);

        // entrou em outro jogo: aplica o perfil salvo daquele PlaceId, se existir
        const GameInfo& game = detector.Info();
        if (game.valid && game.placeId != lastPlaceId) {
            lastPlaceId = game.placeId;
            if (const cfg::Profile* profile = cfg::FindProfile(settings, game.placeId)) {
                cfg::ApplyProfile(settings, *profile);
                std::printf("[jogo] place %llu — perfil aplicado\n",
                            static_cast<unsigned long long>(game.placeId));
                applog::Line("[jogo] place %llu — perfil aplicado",
                          static_cast<unsigned long long>(game.placeId));
            } else {
                std::printf("[jogo] place %llu (sem perfil salvo)\n",
                            static_cast<unsigned long long>(game.placeId));
            }
        }

        ImDrawList* drawList = ImGui::GetBackgroundDrawList();
        esp.Draw(drawList, settings, overlay.Width(), overlay.Height(), aim.TargetPlayer());
        DrawCrosshair(drawList, settings, overlay.Width(), overlay.Height());

        aim.Tick(settings, view, static_cast<unsigned long>(esp.Pid()),
                 overlay.Width(), overlay.Height(), overlay.IsInteractive());
        aim.DrawFov(drawList, settings, overlay.Width(), overlay.Height());

        trigger.Tick(settings, aim,
                     overlay.IsInteractive() ||
                     (settings.fire.requireForeground && !focused));

        fly.Tick(settings, esp.Mem(), view.local,
                 overlay.IsInteractive() ||
                 (settings.fly.requireForeground && !focused));

        // camera (freecam/mira/FOV/FPS) reusa o mesmo handle de escrita
        cameraHack.Tick(settings, esp.Mem(), view.local, aim,
                        overlay.IsInteractive() ||
                        (settings.aim.requireForeground && !focused));

        // magnet puxa item filtrado pra perto (precisa do handle de escrita)
        magnet.Tick(settings, esp.Mem(), view.local, view, overlay.IsInteractive());

        memView.Tick(esp.Mem());

        menu::Draw(settings, esp, overlay, detector, memView, aim, trigger, fly, cameraHack, magnet,
                   &menuOpen);

        // menu fechado pelo X da janela tambem devolve o mouse pro jogo
        if (!menuOpen && overlay.IsInteractive())
            overlay.SetInteractive(false);

        overlay.EndFrame();

        Sleep(overlay.IsInteractive() ? 1u : static_cast<DWORD>(settings.tickMs > 0 ? settings.tickMs : 1));
    }

    std::printf("[exit] fechando\n");
    applog::Line("[app] saindo");
    trigger.Reset();
    fly.Reset();
    cameraHack.Release(esp.Mem());
    magnet.Reset();
    aim.Reset();
    HandleCleanup::Stop();
    esp.Shutdown();
    overlay.Shutdown();
    StealthyOpenProcess::Shutdown();
    applog::Shutdown();
    return 0;
}
