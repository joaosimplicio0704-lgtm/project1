#include "menu.h"

#include <cstdio>

#include "../features/esp.h"
#include "../imgui/imgui.h"
#include "../offsets.h"
#include "../overlay/overlay.h"

namespace menu {

static char g_status[128] = "";

static void DrawEspTab(cfg::Settings& settings) {
    ImGui::TextUnformatted("Visual");
    ImGui::Separator();

    ImGui::Checkbox("ESP  (F1)", &settings.espEnabled);
    ImGui::Checkbox("Caixa  (F2)", &settings.boxes);
    ImGui::Checkbox("Nome", &settings.names);
    ImGui::Checkbox("Barra de vida", &settings.healthBar);
    ImGui::Checkbox("Distancia", &settings.distance);

    ImGui::Spacing();
    ImGui::TextUnformatted("Filtro");
    ImGui::Separator();
    ImGui::Checkbox("Ignorar mesmo time", &settings.teamCheck);

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderFloat("Distancia max", &settings.maxDistance, 50.f, 5000.f, "%.0f studs");

    ImGui::SetNextItemWidth(180.f);
    ImGui::SliderInt("Tick (ms)", &settings.tickMs, 1, 50);
}

static void DrawConfigTab(cfg::Settings& settings, Esp& esp, Overlay& overlay) {
    ImGui::TextUnformatted("Handle");
    ImGui::Separator();
    ImGui::Checkbox("Abrir via StealthyOpenProcess", &settings.stealthOpen);
    ImGui::Checkbox("Fechar handles de thread orfaos", &settings.handleWatch);
    if (ImGui::Button("Reatachar"))
        esp.RequestReattach();

    ImGui::Spacing();
    ImGui::TextUnformatted("Arquivo");
    ImGui::Separator();
    if (ImGui::Button("Salvar config.json")) {
        if (cfg::Save(settings))
            std::snprintf(g_status, sizeof(g_status), "config.json salvo");
        else
            std::snprintf(g_status, sizeof(g_status), "falha ao salvar");
    }
    ImGui::SameLine();
    if (ImGui::Button("Carregar config.json")) {
        if (cfg::Load(settings))
            std::snprintf(g_status, sizeof(g_status), "config.json carregado");
        else
            std::snprintf(g_status, sizeof(g_status), "config.json nao existe");
    }
    if (g_status[0])
        ImGui::TextDisabled("%s", g_status);

    ImGui::Spacing();
    ImGui::TextUnformatted("Estado");
    ImGui::Separator();
    ImGui::Text("offsets: %s", rbx::kVersion);
    ImGui::Text("processo: %s", esp.Attached() ? "conectado" : "offline");
    ImGui::Text("leitura: %s", esp.Status());
    ImGui::Text("alvos: %d", esp.TargetCount());
    ImGui::Text("fps: %.0f  (overlay %.0fx%.0f)", overlay.Fps(), overlay.Width(), overlay.Height());
}

void Draw(cfg::Settings& settings, Esp& esp, Overlay& overlay, bool* open) {
    if (!open || !*open)
        return;

    ImGui::SetNextWindowSize(ImVec2(340.f, 330.f), ImGuiCond_FirstUseEver);
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
        if (ImGui::BeginTabItem("Config")) {
            DrawConfigTab(settings, esp, overlay);
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }

    ImGui::End();
}

} // namespace menu
