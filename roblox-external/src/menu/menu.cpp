#include "menu.h"

#include <windows.h>

#include <cmath>
#include <cstdio>

#include "../features/aim.h"
#include "../features/detector.h"
#include "../features/memview.h"
#include "../features/trigger.h"
#include "../features/esp.h"
#include "../features/fly.h"
#include "../imgui/imgui.h"
#include "../offsets.h"
#include "../overlay/overlay.h"

namespace menu {

static char g_status[128] = "";
static int g_binding = 0;   // 0 = nenhum, 1 = tecla do aim, 2 = tecla do tiro, 3 = voo
static bool g_pressed[256]{};
static bool g_prev[256]{};

// botoes fisicos do mouse: VK_LBUTTON(01) RBUTTON(02) MBUTTON(04) XBUTTON1(05) XBUTTON2(06)
static constexpr int kMouseFirst = 0x01;
static constexpr int kMouseLast  = 0x06;
// teclado comeca depois do bloco do mouse (0x03 e 0x07 sao VK_CANCEL/indefinido)
static constexpr int kKeyFirst   = 0x08;

// transicoes de tecla amostradas uma vez por frame
// sincroniza o estado sem gerar "press" (usado ao entrar em modo bind,
// senao o proprio clique que abriu o bind viraria a tecla capturada)
static void PrimeKeys() {
    for (int vk = 0; vk < 256; ++vk) {
        g_prev[vk] = (GetAsyncKeyState(vk) & 0x8000) != 0;
        g_pressed[vk] = false;
    }
}

static void SampleKeys() {
    for (int vk = 0; vk < 256; ++vk) {
        const bool down = (GetAsyncKeyState(vk) & 0x8000) != 0;
        g_pressed[vk] = down && !g_prev[vk];
        g_prev[vk] = down;
    }
}

// tecla apertada neste frame. 0 = nenhuma.
// o teclado e varrido inteiro (0x08..0xFF) e so depois o mouse: antes o laco
// parava no ESC e as teclas acima de 0x1A (espaco, letras, numeros, F1..F12,
// setas) nunca eram capturadas — so os botoes do mouse, que ficam em 0x01..0x06.
static int CapturedKey() {
    for (int vk = kKeyFirst; vk < 256; ++vk)
        if (g_pressed[vk])
            return vk;

    for (int vk = kMouseFirst; vk <= kMouseLast; ++vk)
        if (g_pressed[vk])
            return vk;

    return 0;
}

// teclas que o menu ja usa como atalho global
static bool ReservedKey(int vk) {
    return vk == cfg::kMenuKey || vk == cfg::kEspKey || vk == cfg::kBoxKey ||
           vk == cfg::kExitKey || vk == VK_F5 || vk == VK_F9;
}

static const char* KeyName(int vk) {
    switch (vk) {
    case 0x00: return "Nenhuma";
    case 0x01: return "Mouse 1";
    case 0x02: return "Mouse 2";
    case 0x04: return "Mouse 3";
    case 0x05: return "Mouse 4";
    case 0x06: return "Mouse 5";
    case VK_BACK: return "Backspace";
    case VK_TAB: return "Tab";
    case VK_RETURN: return "Enter";
    case VK_SHIFT: case VK_LSHIFT: case VK_RSHIFT: return "Shift";
    case VK_CONTROL: case VK_LCONTROL: case VK_RCONTROL: return "Ctrl";
    case VK_MENU: case VK_LMENU: case VK_RMENU: return "Alt";
    case VK_PAUSE: return "Pause";
    case VK_CAPITAL: return "CapsLock";
    case VK_ESCAPE: return "Esc";
    case VK_SPACE: return "Space";
    case VK_PRIOR: return "PageUp";
    case VK_NEXT: return "PageDown";
    case VK_END: return "End";
    case VK_HOME: return "Home";
    case VK_INSERT: return "Insert";
    case VK_DELETE: return "Delete";
    case VK_LWIN: case VK_RWIN: return "Win";
    case VK_APPS: return "Menu";
    case VK_NUMLOCK: return "NumLock";
    case VK_SCROLL: return "ScrollLock";
    case VK_SNAPSHOT: return "PrintScreen";
    case VK_LEFT: return "Esquerda";
    case VK_RIGHT: return "Direita";
    case VK_UP: return "Cima";
    case VK_DOWN: return "Baixo";
    case VK_OEM_1: return ";";
    case VK_OEM_PLUS: return "=";
    case VK_OEM_COMMA: return ",";
    case VK_OEM_MINUS: return "-";
    case VK_OEM_PERIOD: return ".";
    case VK_OEM_2: return "/";
    case VK_OEM_3: return "`";
    case VK_OEM_4: return "[";
    case VK_OEM_5: return "\\";
    case VK_OEM_6: return "]";
    case VK_OEM_7: return "'";
    default: break;
    }

    static char buffer[16];
    if (vk >= VK_F1 && vk <= VK_F24) {
        std::snprintf(buffer, sizeof(buffer), "F%d", vk - VK_F1 + 1);
        return buffer;
    }
    if (vk >= VK_NUMPAD0 && vk <= VK_NUMPAD9) {
        std::snprintf(buffer, sizeof(buffer), "Num %d", vk - VK_NUMPAD0);
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

// slot: 1 = aim, 2 = tiro, 3 = voo
static void KeyBindButton(int slot, int& key, cfg::Settings& settings) {
    ImGui::PushID(slot);

    // largura fixa nos dois estados: o layout nao pula ao entrar em captura
    constexpr float kWidth = 170.f;

    if (g_binding == slot) {
        // nao e botao de verdade: qualquer clique dentro da area serve de tecla
        ImGui::Button("aperte uma tecla... (ESC)", ImVec2(kWidth, 0.f));

        const int vk = CapturedKey();
        if (vk == VK_ESCAPE) {
            g_binding = 0;
        } else if (vk != 0) {
            key = vk;
            g_binding = 0;
            cfg::Save(settings);
            std::snprintf(g_status, sizeof(g_status), "tecla salva: %s", KeyName(vk));
        }
    } else {
        char label[64];
        std::snprintf(label, sizeof(label), "%s###bind", KeyName(key));
        if (ImGui::Button(label, ImVec2(kWidth, 0.f))) {
            g_binding = slot;
            PrimeKeys();
        }
        if (ImGui::IsItemHovered())
            ImGui::SetTooltip("clique e aperte qualquer tecla ou botao do mouse");
    }

    // limpar o bind (0 = nenhuma tecla; o tiro ainda tem o modo automatico)
    ImGui::SameLine();
    if (ImGui::SmallButton("x")) {
        key = 0;
        g_binding = 0;
        cfg::Save(settings);
        std::snprintf(g_status, sizeof(g_status), "bind limpo (Nenhuma)");
    }
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("limpar: fica sem tecla");

    ImGui::SameLine();
    ImGui::TextDisabled("tecla");

    if (g_binding == slot)
        ImGui::TextDisabled("aperte qualquer tecla: letras, numeros, F1..F12, setas ou mouse");
    else if (key == 0)
        ImGui::TextDisabled("sem tecla: este modulo nao responde a bind");
    else if (ReservedKey(key))
        ImGui::TextColored(ImVec4(1.f, 0.6f, 0.2f, 1.f),
                           "%s e atalho do menu: vai ligar/desligar as duas coisas", KeyName(key));

    ImGui::PopID();
}

// ------------------------------------------------------------
static void DrawEspTab(cfg::Settings& settings) {
    ImGui::Checkbox("ESP  (F1)", &settings.espEnabled);
    ImGui::Checkbox("Caixa  (F2)", &settings.boxes);
    ImGui::Checkbox("Nome", &settings.names);
    ImGui::Checkbox("Barra de vida", &settings.healthBar);
    ImGui::Checkbox("Distancia", &settings.distance);
    ImGui::Checkbox("Esqueleto", &settings.espSkeleton);
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("R15/R6 por nome de parte — custa 15 leituras por alvo");
    ImGui::SameLine();
    ImGui::Checkbox("Tracador", &settings.espTracer);
    ImGui::SameLine();
    ImGui::Checkbox("Ponto na cabeca", &settings.espHeadDot);

    ImGui::Spacing();
    ImGui::SeparatorText("Filtro");
    ImGui::Checkbox("Ignorar mesmo time", &settings.teamCheck);

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Distancia max", &settings.maxDistance, 50.f, 5000.f, "%.0f studs");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderInt("Tick (ms)", &settings.tickMs, 1, 50);
}

// ------------------------------------------------------------
static void DrawAimTab(cfg::Settings& settings, AimAssist& aimAssist, bool attached) {
    cfg::AimSettings& aim = settings.aim;

    ImGui::Checkbox("Aim assist", &aim.enabled);

    ImGui::SameLine(200.f);
    KeyBindButton(1, aim.key, settings);

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

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Antecipacao (ms)", &aim.leadMs, 0.f, 200.f, "%.0f");
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("projeta o alvo pela velocidade dele (AssemblyLinearVelocity)");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Mira exata (px)", &aim.snapPx, 0.f, 80.f, "%.0f");
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("dentro desse raio a correcao e quase total (o crosshair encosta no osso "
                          "em 1-2 ticks, que e o que faz o tiro sair na direcao do inimigo). 0 = desliga");

    ImGui::Spacing();
    ImGui::SeparatorText("Sensibilidade do mouse");
    if (aimAssist.Calibrated())
        ImGui::TextColored(ImVec4(0.55f, 0.9f, 0.55f, 1.f), "calibrado: %.2f counts por pixel",
                           aimAssist.CountsPerPixel());
    else
        ImGui::TextDisabled("calibrando... segure a tecla da mira e puxe o alvo");
    ImGui::TextDisabled("mede o giro real da camera por count (independe da sensibilidade do jogo)");
    if (ImGui::Button("Recalibrar mira"))
        aimAssist.ResetCalibration();

    ImGui::SeparatorText("FOV");
    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Raio (px)", &aim.fovPx, 20.f, 600.f, "%.0f");
    ImGui::Checkbox("Desenhar circulo", &aim.drawFov);
    ImGui::Checkbox("So com o jogo em foco", &aim.requireForeground);

    ImGui::Spacing();
    ImGui::TextDisabled("ganho real por tick: %.3f", aim.strength / (aim.smoothing < 1.f ? 1.f : aim.smoothing));
    if (!attached)
        ImGui::TextDisabled("sem processo: nada e enviado");
}

// ------------------------------------------------------------
static void DrawFireTab(cfg::Settings& settings, const AimAssist& aim, const Trigger& trigger) {
    cfg::TriggerSettings& fire = settings.fire;

    ImGui::Checkbox("Disciplina de tiro", &fire.enabled);
    ImGui::SameLine(200.f);
    KeyBindButton(2, fire.key, settings);

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
static void DrawFlyTab(cfg::Settings& settings, const Fly& fly, const Esp& esp) {
    const auto scene = esp.Snapshot();
    const LocalState local = scene ? scene->local : LocalState{};
    cfg::FlySettings& v = settings.fly;

    ImGui::Checkbox("Voo", &v.enabled);
    ImGui::SameLine(200.f);
    KeyBindButton(3, v.key, settings);

    ImGui::TextColored(ImVec4(1.f, 0.55f, 0.35f, 1.f),
                       "unico modulo que ESCREVE em memoria (VM_WRITE)");
    ImGui::TextDisabled("WASD no plano da camera, Space/Ctrl sobem/descem");

    ImGui::SeparatorText("Ajuste");
    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Velocidade", &v.speed, 5.f, 300.f, "%.0f studs/s");

    ImGui::Checkbox("Zerar velocidade", &v.zeroVelocity);
    ImGui::SameLine();
    ImGui::TextDisabled("(gravidade nao briga)");

    ImGui::Checkbox("Paira parado", &v.hoverOnIdle);
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("sem WASD segura a altura (zera a velocidade todo tick) em vez de cair");

    ImGui::Checkbox("Modo toggle", &v.toggleMode);
    ImGui::Checkbox("So com o jogo em foco", &v.requireForeground);

    ImGui::Spacing();
    ImGui::Text("handle     %s", esp.Mem().CanWrite() ? "VM_WRITE ok" : "read-only (reatacha ao ligar)");
    ImGui::Text("estado     %s", !fly.Active() ? "parado"
                            : (fly.Hovering() ? "pairando" : "voando"));
    const Vector3 shown = fly.Active() && fly.HasPosition() ? fly.Position() : local.position;
    ImGui::Text("posicao    %.1f, %.1f, %.1f", shown.x, shown.y, shown.z);
    ImGui::Text("passo      %.1f studs/s (dt limitado a 50 ms)", v.speed);
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
    const auto scene = esp.Snapshot();
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
    ImGui::Text("processo  %s", (scene && scene->attached) ? "conectado" : "offline");
    ImGui::Text("leitura   %s", scene ? scene->status.c_str() : "iniciando");
    ImGui::Text("alvos     %d", scene ? static_cast<int>(scene->targets.size()) : 0);
    ImGui::Text("players   %d", scene ? scene->playerCount : 0);
    ImGui::Text("quadro    %d  (%.0f Hz)", scene ? scene->frame : 0, scene ? scene->tickRate : 0.f);
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
          MemView& memView, AimAssist& aim, const Trigger& trigger, const Fly& fly, bool* open) {
    if (!open || !*open) {
        g_binding = 0;   // fecha o menu no meio do bind: nao pode ficar armado
        return;
    }

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
            const auto scene = esp.Snapshot();
            DrawAimTab(settings, aim, scene && scene->attached);
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
        if (ImGui::BeginTabItem("Voo")) {
            DrawFlyTab(settings, fly, esp);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Memoria")) {
            memView.Draw(esp.Mem(), esp);
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
