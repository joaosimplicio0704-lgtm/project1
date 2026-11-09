#include "menu.h"

#include <windows.h>

#include <cmath>
#include <cstdio>

#include "../features/aim.h"
#include "../features/detector.h"
#include "../features/memview.h"
#include "../features/trigger.h"
#include "../features/esp.h"
#include "../imgui/imgui.h"
#include "../offsets.h"
#include "../overlay/overlay.h"

namespace menu {

static char g_status[128] = "";
static int g_binding = 0;   // 0 = nenhum, 1 = tecla do aim, 2 = tecla do tiro
static bool g_pressed[256]{};
static bool g_prev[256]{};

// transicoes de tecla amostradas uma vez por frame
// sincroniza o estado sem gerar "press" (usado ao entrar em modo bind,
// senao o proprio clique que abriu o bind viraria a tecla capturada)
static void PrimeKeys() {
    for (int vk = 1; vk < 256; ++vk) {
        g_prev[vk] = (GetAsyncKeyState(vk) & 0x8000) != 0;
        g_pressed[vk] = false;
    }
}

static void SampleKeys() {
    for (int vk = 1; vk < 256; ++vk) {
        const bool down = (GetAsyncKeyState(vk) & 0x8000) != 0;
        g_pressed[vk] = down && !g_prev[vk];
        g_prev[vk] = down;
    }
}

static const char* KeyName(int vk) {
    switch (vk) {
    case 0x01: return "Mouse 1";
    case 0x02: return "Mouse 2";
    case 0x04: return "Mouse 3";
    case 0x05: return "Mouse 4";
    case 0x06: return "Mouse 5";
    case VK_SHIFT: case VK_LSHIFT: return "Shift";
    case VK_CONTROL: case VK_LCONTROL: return "Ctrl";
    case VK_MENU: case VK_LMENU: return "Alt";
    case VK_SPACE: return "Space";
    case VK_TAB: return "Tab";
    case VK_CAPITAL: return "CapsLock";
    case VK_INSERT: return "Insert";
    case VK_HOME: return "Home";
    case VK_END: return "End";
    case VK_PRIOR: return "PageUp";
    case VK_NEXT: return "PageDown";
    default: break;
    }

    static char buffer[16];
    if (vk >= VK_F1 && vk <= VK_F12) {
        std::snprintf(buffer, sizeof(buffer), "F%d", vk - VK_F1 + 1);
        return buffer;
    }
    if ((vk >= '0' && vk <= '9') || (vk >= 'A' && vk <= 'Z')) {
        buffer[0] = static_cast<char>(vk);
        buffer[1] = '\0';
        return buffer;
    }
    std::snprintf(buffer, sizeof(buffer), "VK %02X", vk);
    return buffer;
}

static void KeyBindButton(int slot, int& key) {
    if (g_binding == slot) {
        ImGui::Button("apertar tecla...", ImVec2(120.f, 0.f));
        for (int vk = 1; vk < 256; ++vk) {
            if (vk == VK_ESCAPE) {
                if (g_pressed[vk]) g_binding = 0;
                break;
            }
            if (g_pressed[vk]) {
                key = vk;
                g_binding = 0;
                break;
            }
        }
    } else {
        if (ImGui::Button(KeyName(key), ImVec2(120.f, 0.f))) {
            g_binding = slot;
            PrimeKeys();
        }
    }
    ImGui::SameLine();
    ImGui::TextDisabled("tecla");
}

// ------------------------------------------------------------
static void DrawEspTab(cfg::Settings& settings) {
    ImGui::Checkbox("ESP  (F1)", &settings.espEnabled);
    ImGui::Checkbox("Caixa  (F2)", &settings.boxes);
    ImGui::Checkbox("Nome", &settings.names);
    ImGui::Checkbox("Barra de vida", &settings.healthBar);
    ImGui::Checkbox("Distancia", &settings.distance);

    ImGui::Spacing();
    ImGui::SeparatorText("Filtro");
    ImGui::Checkbox("Ignorar mesmo time", &settings.teamCheck);

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Distancia max", &settings.maxDistance, 50.f, 5000.f, "%.0f studs");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderInt("Tick (ms)", &settings.tickMs, 1, 50);
}

// ------------------------------------------------------------
static void DrawAimTab(cfg::Settings& settings, Esp& esp) {
    cfg::AimSettings& aim = settings.aim;

    ImGui::Checkbox("Aim assist", &aim.enabled);

    ImGui::SameLine(200.f);
    KeyBindButton(1, aim.key);

    ImGui::Checkbox("Modo toggle", &aim.toggleMode);
    ImGui::SameLine();
    ImGui::TextDisabled(aim.toggleMode ? "(aperta e solta)" : "(segurar)");

    ImGui::SeparatorText("Alvo");
    int bone = aim.bone;
    ImGui::RadioButton("Cabeca", &bone, cfg::kHead);
    ImGui::SameLine();
    ImGui::RadioButton("Peito", &bone, cfg::kChest);
    ImGui::SameLine();
    ImGui::RadioButton("Raiz", &bone, cfg::kRoot);
    aim.bone = bone;

    ImGui::SeparatorText("Quanto a mira puxa");
    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Forca", &aim.strength, 0.05f, 1.0f, "%.2f");
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("fracao do erro aplicada por tick. 1.00 = cola, 0.10 = encosta devagar");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Suavizacao", &aim.smoothing, 1.0f, 20.0f, "%.1f");
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("divisor do passo. maior = mais devagar e mais discreto");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Passo max (px)", &aim.maxStepPx, 5.f, 200.f, "%.0f");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Zona morta (px)", &aim.deadzonePx, 0.f, 20.f, "%.0f");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Jitter (px)", &aim.jitterPx, 0.f, 5.f, "%.1f");

    ImGui::SeparatorText("FOV");
    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Raio (px)", &aim.fovPx, 20.f, 600.f, "%.0f");
    ImGui::Checkbox("Desenhar circulo", &aim.drawFov);
    ImGui::Checkbox("So com o jogo em foco", &aim.requireForeground);

    ImGui::Spacing();
    ImGui::TextDisabled("ganho real por tick: %.3f", aim.strength / (aim.smoothing < 1.f ? 1.f : aim.smoothing));
    if (!esp.Attached())
        ImGui::TextDisabled("sem processo: nada e enviado");
}

// ------------------------------------------------------------
static void DrawFireTab(cfg::Settings& settings, const AimAssist& aim, const Trigger& trigger) {
    cfg::TriggerSettings& fire = settings.fire;

    ImGui::Checkbox("Disciplina de tiro", &fire.enabled);
    ImGui::SameLine(200.f);
    KeyBindButton(2, fire.key);

    ImGui::Checkbox("Auto (sem tecla)", &fire.autoFire);
    ImGui::Checkbox("So com o jogo em foco", &fire.requireForeground);

    ImGui::SeparatorText("Portao");
    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Erro max (px)", &fire.maxErrorPx, 0.5f, 20.f, "%.1f");
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("só solta o clique com o crosshair dentro desse raio do osso");

    ImGui::SeparatorText("Cadencia");
    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderInt("Intervalo (ms)", &fire.minIntervalMs, 16, 1000);
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("%d tiros/s no maximo", 1000 / (fire.minIntervalMs < 1 ? 1 : fire.minIntervalMs));

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderInt("Hold (ms)", &fire.holdMs, 1, 100);

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderInt("Rajada", &fire.burst, 1, 10);

    ImGui::Spacing();
    ImGui::Text("alvo     %s  (%.1f px)", aim.HasTarget() ? "sim" : "nao", aim.TargetError());
    ImGui::Text("tiros    %d", trigger.ShotsFired());
    ImGui::TextDisabled("espalhamento e do jogo (raycast em Lua/servidor).");
    ImGui::TextDisabled("aqui: cada tiro sai com o crosshair no centro e com cadencia.");
}

// ------------------------------------------------------------
static void DrawGameTab(cfg::Settings& settings, Detector& detector) {
    const GameInfo& game = detector.Info();

    ImGui::SeparatorText("Detectado");
    if (!game.valid) {
        ImGui::TextDisabled("nenhum DataModel carregado");
    } else {
        ImGui::Text("PlaceId     %llu", static_cast<unsigned long long>(game.placeId));
        ImGui::Text("GameId      %llu", static_cast<unsigned long long>(game.gameId));
        ImGui::Text("CreatorId   %llu", static_cast<unsigned long long>(game.creatorId));
        ImGui::Text("Versao      %d", game.placeVersion);
        ImGui::Text("JobId       %s", game.jobId.c_str());
        ImGui::Text("Players     %d", game.playerCount);
    }

    ImGui::Spacing();
    ImGui::SeparatorText("Perfil por jogo");

    const bool hasGame = game.valid && game.placeId != 0;
    const cfg::Profile* existing = hasGame ? cfg::FindProfile(settings, game.placeId) : nullptr;

    ImGui::BeginDisabled(!hasGame);
    if (ImGui::Button("Salvar config atual neste PlaceId")) {
        cfg::Profile profile{};
        profile.placeId = game.placeId;
        profile.fovPx = settings.aim.fovPx;
        profile.smoothing = settings.aim.smoothing;
        profile.strength = settings.aim.strength;
        profile.bone = settings.aim.bone;
        cfg::UpsertProfile(settings, profile);
        cfg::Save(settings);
        std::snprintf(g_status, sizeof(g_status), "perfil salvo para %llu",
                      static_cast<unsigned long long>(game.placeId));
    }
    ImGui::EndDisabled();

    if (existing) {
        ImGui::SameLine();
        if (ImGui::Button("Aplicar")) {
            cfg::ApplyProfile(settings, *existing);
            std::snprintf(g_status, sizeof(g_status), "perfil aplicado");
        }
    }

    if (!settings.profiles.empty()) {
        ImGui::Spacing();
        ImGui::TextDisabled("perfis salvos (%d)", static_cast<int>(settings.profiles.size()));
        for (size_t i = 0; i < settings.profiles.size(); ++i) {
            const cfg::Profile& profile = settings.profiles[i];
            ImGui::PushID(static_cast<int>(i));
            ImGui::Text("%llu", static_cast<unsigned long long>(profile.placeId));
            ImGui::SameLine(120.f);
            ImGui::TextDisabled("fov %.0f  forc %.2f  suav %.1f", profile.fovPx, profile.strength, profile.smoothing);
            ImGui::SameLine(300.f);
            if (ImGui::SmallButton("aplicar"))
                cfg::ApplyProfile(settings, profile);
            ImGui::SameLine();
            if (ImGui::SmallButton("x")) {
                settings.profiles.erase(settings.profiles.begin() + static_cast<long>(i));
                cfg::Save(settings);
                ImGui::PopID();
                break;
            }
            ImGui::PopID();
        }
    }

    if (g_status[0])
        ImGui::TextDisabled("%s", g_status);
}

// ------------------------------------------------------------
static void DrawConfigTab(cfg::Settings& settings, Esp& esp, Overlay& overlay) {
    ImGui::SeparatorText("Handle");
    ImGui::Checkbox("Abrir via StealthyOpenProcess", &settings.stealthOpen);
    ImGui::Checkbox("Fechar handles de thread orfaos", &settings.handleWatch);
    if (ImGui::Button("Reatachar"))
        esp.RequestReattach();

    ImGui::Spacing();
    ImGui::SeparatorText("Arquivo");
    if (ImGui::Button("Salvar config")) {
        std::snprintf(g_status, sizeof(g_status), cfg::Save(settings) ? "config salvo" : "falha ao salvar");
    }
    ImGui::SameLine();
    if (ImGui::Button("Carregar config")) {
        std::snprintf(g_status, sizeof(g_status), cfg::Load(settings) ? "config carregado" : "config nao existe");
    }
    if (g_status[0])
        ImGui::TextDisabled("%s", g_status);

    ImGui::Spacing();
    ImGui::SeparatorText("Estado");
    ImGui::Text("offsets   %s", rbx::kVersion);
    ImGui::Text("processo  %s", esp.Attached() ? "conectado" : "offline");
    ImGui::Text("leitura   %s", esp.Status());
    ImGui::Text("alvos     %d", esp.TargetCount());
    ImGui::Text("fps       %.0f  (%.0fx%.0f)", overlay.Fps(), overlay.Width(), overlay.Height());

    ImGui::Spacing();
    ImGui::SeparatorText("Input (diagnostico)");
    POINT cursor{};
    GetCursorPos(&cursor);
    const ImGuiIO& io = ImGui::GetIO();
    ImGui::Text("cursor os     %ld, %ld", cursor.x, cursor.y);
    ImGui::Text("cursor imgui  %.0f, %.0f", io.MousePos.x, io.MousePos.y);
    ImGui::Text("dpi           %.0f%%", overlay.DpiScale() * 100.f);
    if (ImGui::IsMousePosValid() && (std::abs(static_cast<float>(cursor.x) - io.MousePos.x) > 2.f ||
                                     std::abs(static_cast<float>(cursor.y) - io.MousePos.y) > 2.f)) {
        ImGui::TextColored(ImVec4(1.f, 0.6f, 0.2f, 1.f), "cursor os e imgui divergem: escala/deslocamento");
    }
}

// ------------------------------------------------------------
void Draw(cfg::Settings& settings, Esp& esp, Overlay& overlay, Detector& detector,
          MemView& memView, const AimAssist& aim, const Trigger& trigger, bool* open) {
    if (!open || !*open)
        return;

    if (g_binding)
        SampleKeys();

    ImGui::SetNextWindowSize(ImVec2(470.f, 470.f), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(40.f, 40.f), ImGuiCond_FirstUseEver);

    if (!ImGui::Begin("roblox-external", open, ImGuiWindowFlags_NoCollapse)) {
        ImGui::End();
        return;
    }

    if (ImGui::BeginTabBar("##tabs")) {
        if (ImGui::BeginTabItem("ESP")) {
            DrawEspTab(settings);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Aim")) {
            DrawAimTab(settings, esp);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Tiros")) {
            DrawFireTab(settings, aim, trigger);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Jogo")) {
            DrawGameTab(settings, detector);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Memoria")) {
            memView.Draw(esp.Mem());
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Config")) {
            DrawConfigTab(settings, esp, overlay);
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }

    ImGui::End();
}

} // namespace menu
