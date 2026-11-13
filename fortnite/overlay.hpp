#pragma once
#include "entity.hpp"
#include "mem.hpp"

// menu INSERT (tabbed, draggable, immediate-mode) — >3 toggles exige menu.
// Acionado com a tecla INSERT; mostra/oculta o menu. O ESP roda por baixo independentemente.
struct OverlayCfg {
    bool menuOpen = true;
    bool esp = true;
    bool aimbot = true;
    bool teamCheck = true;
    bool visibleOnly = false;
    bool showDistance = true;
    bool showHealth = true;
    bool showFOV = true;
};

// loop do overlay. roda em thread separada do loop de leitura.
void overlayThread(Mem& mem, Entities& ents, LocalPlayer& local, OverlayCfg& cfg,
                   HWND gameWnd, int screenW, int screenH);
