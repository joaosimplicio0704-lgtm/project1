#pragma once
#include "entity.hpp"
#include "math.hpp"
#include <windows.h>
#include <cmath>

// Config do aimbot (um só lugar pra tunar — valores mutáveis pra o menu sobrescrever)
namespace aim {
inline DWORD kAimKey = VK_XBUTTON2;     // segurado pra mirar no alvo
inline float kFovPx = 140.f;            // raio em torno da crosshair (px)
inline float kSmoothing = 6.f;          // quanto maior, mais suave (divide o delta por tick)
inline bool kTeamCheck = true;          // nao mira em time proprio
inline bool kVisibleOnly = false;       // true exige trace de visibilidade (// FILL: engine trace)
inline float kAimSens = 1.f;            // conversao angulo -> pixels do mouse (ajuste por feeling)
} // namespace aim

// escolhe o alvo mais perto da crosshair dentre entidades validas
inline const Entity* pickTarget(const std::vector<Entity>& ents, const LocalPlayer& local,
                                int screenW, int screenH) {
    const Entity* best = nullptr;
    float bestDist = aim::kFovPx;
    for (const auto& e : ents) {
        if (!e.valid || e.addr == local.pawn) continue;
        if (e.bDBNO) continue;
        if (aim::kTeamCheck && e.teamIndex >= 0 && local.teamIndex >= 0 && e.teamIndex == local.teamIndex)
            continue;
        if (e.health <= 0.f) continue;
        if (e.head.X == 0 && e.head.Y == 0 && e.head.Z == 0) continue; // sem cabeca (// FILL: osso)

        FVector screen{};
        if (!w2s(e.head, local.camLoc, local.camRot, local.fov, screenW, screenH, screen))
            continue;
        float d = (float)screenDist(screen.X, screen.Y, screenW, screenH);
        if (d < bestDist) { bestDist = d; best = const_cast<Entity*>(&e); }
    }
    return best;
}

// move o mouse via SendInput pra mirar no alvo (suavizado por tick). retorna true se moveu.
inline bool aimAt(const Entity& target, const LocalPlayer& local, int screenW, int screenH) {
    FVector screen{};
    if (!w2s(target.head, local.camLoc, local.camRot, local.fov, screenW, screenH, screen))
        return false;

    double dx = screen.X - screenW / 2.0;
    double dy = screen.Y - screenH / 2.0;
    double dist = std::sqrt(dx * dx + dy * dy);
    if (dist < 1.0) return true;

    double scale = aim::kAimSens * (dist / aim::kFovPx);
    long mx = (long)(dx / aim::kSmoothing * scale);
    long my = (long)(dy / aim::kSmoothing * scale);
    if (mx == 0 && my == 0) return true;

    INPUT inp{};
    inp.type = INPUT_MOUSE;
    inp.mi.dx = mx;
    inp.mi.dy = my;
    inp.mi.dwFlags = MOUSEEVENTF_MOVE;
    inp.mi.time = 0;
    inp.mi.dwExtraInfo = GetMessageExtraInfo();
    SendInput(1, &inp, sizeof(INPUT));
    return true;
}
