#pragma once
#include <cstdint>

#include "../config.h"

class AimAssist;

// ============================================================
// Disciplina de tiro.
//
// Espalhamento de bala em Roblox mora no lado do jogo (raycast em Lua /
// servidor) — externo nao mexe nisso sem escrever memoria. O que da pra
// fazer de verdade: so soltar o clique quando o crosshair esta em cima do
// osso (|erro| <= maxErrorPx), e com cadencia limitada, pra nao empilhar
// recoil nem sair tiro torto.
// ============================================================

class Trigger {
public:
    void Tick(const cfg::Settings& settings, const AimAssist& aim, bool blocked);
    void Reset();

    bool Firing() const { return m_pressed; }
    int  ShotsFired() const { return m_shots; }

private:
    void Press();
    void Release();

    bool     m_pressed = false;
    uint64_t m_releaseAt = 0;
    uint64_t m_nextShotAt = 0;
    int      m_shotsLeft = 0;
    int      m_shots = 0;
    bool     m_prevHeld = false;
};
