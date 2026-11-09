#pragma once
#include "../config.h"

struct ImDrawList;
struct SceneSnapshot;

// ============================================================
// Aim assist externo.
//
// Nao escreve view angle nem estado do player: le a posicao do osso,
// projeta pra tela, e move o mouse com SendInput (MOUSEEVENTF_MOVE).
// O erro em pixels converge porque a camera gira e a projecao se
// recalcula no tick seguinte.
// ============================================================

class AimAssist {
public:
    // blocked = overlay interativo (menu aberto) ou qualquer coisa que
    // nao deva roubar o mouse
    void Tick(const cfg::Settings& settings, const SceneSnapshot& scene, unsigned long pid,
              float width, float height, bool blocked);

    void DrawFov(ImDrawList* list, const cfg::Settings& settings, float width, float height) const;

    void Reset();

    bool  HasTarget() const { return m_hasTarget; }
    float TargetError() const { return m_targetError; }   // px ate o centro
    float TargetX() const { return m_targetX; }
    float TargetY() const { return m_targetY; }

private:
    bool  m_hasTarget = false;
    float m_targetX = 0.f;
    float m_targetY = 0.f;
    float m_targetError = 0.f;
    float m_fovCenterX = 0.f;
    float m_fovCenterY = 0.f;

    float m_accumX = 0.f;   // resto fracionario do delta
    float m_accumY = 0.f;

    bool  m_toggled = false;
    bool  m_lastDown = false;
};
