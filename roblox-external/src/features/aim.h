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
//
// Como o tiro sai da camera (crosshair no centro), acertar o alvo e
// garantir que a camera esteja EXATAMENTE em cima dele no frame do
// disparo. Duas coisas fazem isso:
//
//   1. calibracao automatica: mede quantos radianos a camera gira por
//      count de mouse (lendo a matriz da camera antes/depois do
//      SendInput) e converte erro em pixels -> counts de verdade.
//      Sem isso o laco usa 1 px = 1 count, que e chute.
//   2. passo exato perto do alvo (snapPx): dentro desse raio a
//      correcao e aplicada quase inteira, sem suavizacao, em vez de
//      gastar 10 ticks para chegar.
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
    uintptr_t TargetPlayer() const { return m_lockedPlayer; }   // 0 = nenhum

    // calibracao de sensibilidade (px de tela -> counts de mouse)
    bool  Calibrated() const { return m_calibrated; }
    float CountsPerPixel() const { return m_countsPerPx; }
    void  ResetCalibration();

private:
    bool  m_hasTarget = false;
    float m_targetX = 0.f;
    float m_targetY = 0.f;
    float     m_targetError = 0.f;
    uintptr_t m_lockedPlayer = 0;   // alvo travado ate soltar a tecla

    float m_accumX = 0.f;   // resto fracionario do delta
    float m_accumY = 0.f;

    bool  m_toggled = false;
    bool  m_lastDown = false;

    // --- calibracao ---
    float m_radPerCountYaw = 0.f;   // radianos de yaw por count de mouse
    float m_radPerCountPitch = 0.f;
    float m_countsPerPx = 0.f;      // counts por pixel (derivado, pra UI)
    int   m_samples = 0;
    bool  m_calibrated = false;

    // amostra em andamento: mandamos o delta e medimos o giro depois
    int   m_probeLeft = 0;          // ticks restantes para colher a amostra
    int   m_probeAccumX = 0;        // soma dos deltas enviados na janela
    int   m_probeAccumY = 0;
    float m_probeYaw = 0.f;
    float m_probePitch = 0.f;
    int   m_probeFrame = -1;        // frame do snapshot em que enviamos
};
