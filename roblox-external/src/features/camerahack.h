#pragma once
#include <cstdint>

#include "../config.h"
#include "../sdk/sdk.h"

class Memory;
struct LocalState;
class AimAssist;

// ============================================================
// CAMERA — o unico modulo que mexe em coisa que o servidor nao ve.
//
// A camera do Roblox e 100% local. Enquanto o jogo esta com
// CameraType = Scriptable (6), o modulo de camera dele para de
// reescrever a CFrame e o que a gente escreve FICA. Isso da:
//
//   freecam  — camera desacoplada do personagem, WASD + setas
//              (setas = olhar) atravessa parede e ve o mapa todo
//   mira     — escreve a rotacao exata apontando pro osso do alvo no
//              frame do disparo: sem SendInput, sem sensibilidade,
//              sem mouse lock. O tiro sai na direcao do alvo.
//   fov      — escreve Camera::FieldOfView (70 -> 110 ve tudo)
//   fps      — escreve TaskScheduler::MaxFPS (tira o teto de 60)
//
// Nada disso replica: o servidor nao recebe camera, FOV nem FPS.
// Por isso e o pacote "ousado" de menor risco.
//
// Ao desligar (ou no panic) tudo volta: CameraType original, FOV
// original e MaxFPS original.
// ============================================================

class CameraHack {
public:
    void Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local,
              const AimAssist& aim, bool blocked);

    // devolve o estado do jogo (usar no shutdown e no panic)
    void Release(Memory& memory);

    bool FreecamActive() const { return m_freecam; }
    bool AimActive() const { return m_aim; }
    bool ScriptableOwned() const { return m_typeOwned; }

private:
    void ApplyType(Memory& memory, bool wantScriptable);
    void ApplyFov(Memory& memory, const LocalState& local, const cfg::CameraSettings& camera);
    void ApplyFps(Memory& memory, const cfg::CameraSettings& camera);

    bool      m_freecam = false;
    bool      m_toggled = false;
    bool      m_prevDown = false;
    bool      m_aim = false;
    Vector3   m_pos{};
    bool      m_posValid = false;
    float     m_yaw = 0.f;
    float     m_pitch = 0.f;
    uintptr_t m_camera = 0;

    // CameraType
    bool      m_typeOwned = false;
    int       m_savedType = 0;

    // FOV
    bool      m_fovOwned = false;
    float     m_savedFov = 70.f;
    float     m_writtenFov = 0.f;

    // MaxFPS
    bool      m_fpsOwned = false;
    float     m_savedFps = 0.f;
    float     m_fpsSpeed = 0.f;
    uintptr_t m_lastFpsRefusal = 0;
    float     m_writtenFps = 0.f;

    uint64_t  m_lastTick = 0;
};
