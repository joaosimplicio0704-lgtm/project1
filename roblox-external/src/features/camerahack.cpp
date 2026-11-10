#include "camerahack.h"

#include <windows.h>

#include <cmath>

#include "aim.h"
#include "../applog.h"
#include "esp.h"
#include "../offsets.h"
#include "../sdk/mathx.h"

namespace {

// CameraType do Roblox: Fixed=0, Attach=1, Watch=2, Track=3, Follow=4,
// Custom=5, Scriptable=6, Orbital=7. Scriptable = o jogo para de mandar.
constexpr int kScriptable = 6;

constexpr float kLookSpeed = 1.7f;    // rad/s nas setas
constexpr float kMaxPitch = 1.52f;    // ~87 graus

bool Down(int vk) {
    return vk > 0 && (GetAsyncKeyState(vk) & 0x8000) != 0;
}

} // namespace

void CameraHack::Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                      const AimAssist& aim, bool blocked) {
    const cfg::CameraSettings& camera = settings.camera;

    const uint64_t now = GetTickCount64();
    const float dt = mathx::ClampDt(m_lastTick ? static_cast<float>(now - m_lastTick) / 1000.f : 0.004f,
                                   0.05f);
    m_lastTick = now;

    // FOV e FPS nao dependem da camera estar sendo controlada por nos
    ApplyFov(memory, local, camera);
    ApplyFps(memory, camera);

    if (local.camera)
        m_camera = local.camera;

    if (!m_camera || !memory.CanWrite() || !local.Valid()) {
        m_freecam = false;
        m_aim = false;
        return;
    }

    // ---- freecam: toggle pela tecla ----
    const bool down = Down(camera.freecamKey);
    if (camera.freecam && down && !m_prevDown)
        m_toggled = !m_toggled;
    m_prevDown = down;

    const bool wantFreecam = camera.freecam && !blocked && m_toggled;

    // ---- mira por camera: freecam tem prioridade ----
    const bool wantAim = !wantFreecam && !blocked && settings.aim.enabled &&
                         settings.aim.cameraMode && aim.Armed() && aim.HasTarget();

    ApplyType(memory, wantFreecam || wantAim);

    if (wantFreecam && !m_freecam) {
        // entrou agora: comeca de onde a camera esta
        m_pos = local.cameraPosition;
        m_posValid = m_pos.NonZero();
        if (!mathx::CameraAngles(local.cameraRotation, m_yaw, m_pitch)) {
            m_yaw = 0.f;
            m_pitch = 0.f;
        }
    }

    m_freecam = wantFreecam;
    m_aim = wantAim;

    if (wantFreecam) {
        if (!m_posValid) {
            m_pos = local.cameraPosition;
            m_posValid = m_pos.NonZero();
        }

        // setas giram: com Scriptable, ninguem mais gira a camera
        if (Down(VK_LEFT))  m_yaw += kLookSpeed * dt;
        if (Down(VK_RIGHT)) m_yaw -= kLookSpeed * dt;
        if (Down(VK_UP))    m_pitch += kLookSpeed * dt;
        if (Down(VK_DOWN))  m_pitch -= kLookSpeed * dt;
        m_pitch = std::clamp(m_pitch, -kMaxPitch, kMaxPitch);

        float rot[9]{};
        if (!mathx::RotationFromYawPitch(m_yaw, m_pitch, rot))
            return;

        const Vector3 forward{ -rot[2], -rot[5], -rot[8] };
        const Vector3 right{ rot[0], rot[3], rot[6] };

        Vector3 dir{};
        if (Down('W')) { dir.x += forward.x; dir.y += forward.y; dir.z += forward.z; }
        if (Down('S')) { dir.x -= forward.x; dir.y -= forward.y; dir.z -= forward.z; }
        if (Down('D')) { dir.x += right.x;   dir.y += right.y;   dir.z += right.z; }
        if (Down('A')) { dir.x -= right.x;   dir.y -= right.y;   dir.z -= right.z; }
        if (Down(VK_SPACE))   dir.y += 1.f;
        if (Down(VK_CONTROL)) dir.y -= 1.f;

        const float len = dir.Length();
        if (len > 0.001f && std::isfinite(len)) {
            dir.x /= len;
            dir.y /= len;
            dir.z /= len;
            m_pos = mathx::FlyStep(m_pos, dir, camera.freecamSpeed, dt);
        }

        if (!m_pos.Finite())
            return;

        memory.Write(m_camera + rbx::Camera::Position, m_pos);
        memory.Write(m_camera + rbx::Camera::Rotation, rot);
        return;
    }

    m_posValid = false;

    if (wantAim) {
        Vector3 target{};
        float rot[9]{};
        if (aim.TargetWorld(target) && mathx::LookRotation(local.cameraPosition, target, rot))
            memory.Write(m_camera + rbx::Camera::Rotation, rot);
    }
}

void CameraHack::ApplyType(Memory& memory, bool wantScriptable) {
    if (!m_camera)
        return;

    if (wantScriptable) {
        if (!m_typeOwned) {
            int current = 0;
            if (!memory.Read(m_camera + rbx::Camera::CameraType, current))
                current = 0;

            if (memory.Write(m_camera + rbx::Camera::CameraType, kScriptable)) {
                m_savedType = current;
                m_typeOwned = true;
                applog::Line("[camera] CameraType %d -> %d (Scriptable)", current, kScriptable);
            }
        }
        return;
    }

    if (m_typeOwned) {
        memory.Write(m_camera + rbx::Camera::CameraType, m_savedType);
        m_typeOwned = false;
        applog::Line("[camera] CameraType restaurado (%d)", m_savedType);
    }
}

void CameraHack::ApplyFov(Memory& memory, const LocalState& local, const cfg::CameraSettings& camera) {
    if (!local.camera || !memory.CanWrite())
        return;

    const float wanted = std::clamp(camera.fov, 20.f, 120.f);

    if (camera.fovHack) {
        if (!m_fovOwned) {
            m_savedFov = memory.ReadOr<float>(local.camera + rbx::Camera::FieldOfView, 70.f);
            m_fovOwned = true;
            m_writtenFov = 0.f;
        }

        if (std::fabs(wanted - m_writtenFov) > 0.05f) {
            if (memory.Write(local.camera + rbx::Camera::FieldOfView, wanted)) {
                m_writtenFov = wanted;
                applog::Line("[camera] FOV %.0f (era %.0f)", wanted, m_savedFov);
            }
        }
        return;
    }

    if (m_fovOwned && local.camera) {
        memory.Write(local.camera + rbx::Camera::FieldOfView, m_savedFov);
        m_fovOwned = false;
        m_writtenFov = 0.f;
        applog::Line("[camera] FOV restaurado (%.0f)", m_savedFov);
    }
}

void CameraHack::ApplyFps(Memory& memory, const cfg::CameraSettings& camera) {
    if (!memory.CanWrite()) {
        m_fpsOwned = false;
        return;
    }

    const uintptr_t base = memory.Base();
    if (!base)
        return;

    const uintptr_t scheduler = memory.ReadPtr(base + rbx::TaskScheduler::Pointer);
    if (!scheduler)
        return;

    if (!camera.unlockFps) {
        if (m_fpsOwned) {
            memory.Write(scheduler + rbx::TaskScheduler::MaxFPS, m_savedFps);
            m_fpsOwned = false;
            m_writtenFps = 0.f;
            applog::Line("[fps] teto restaurado (%.0f)", m_savedFps);
        }
        return;
    }

    const float wanted = static_cast<float>(std::clamp(camera.maxFps, 30, 1000));
    if (m_fpsOwned && std::fabs(wanted - m_writtenFps) < 0.5f)
        return;

    if (!m_fpsOwned) {
        const float current = memory.ReadOr<float>(scheduler + rbx::TaskScheduler::MaxFPS, 0.f);

        // trava de seguranca: se o campo nao for um float plausivel (30..1000),
        // e outro tipo nesse build — escrever float aqui travaria o scheduler
        if (!(current >= 30.f && current <= 1000.f)) {
            if (m_lastFpsRefusal != scheduler) {
                m_lastFpsRefusal = scheduler;
                applog::Line("[fps] MaxFPS nao parece float (lido %.1f) — unlock desligado", current);
            }
            return;
        }

        m_savedFps = current;
        m_fpsSpeed = current;
        m_fpsOwned = true;
    }

    if (memory.Write(scheduler + rbx::TaskScheduler::MaxFPS, wanted)) {
        m_writtenFps = wanted;
        applog::Line("[fps] MaxFPS %.0f -> %.0f", m_fpsSpeed, wanted);
    }
}

void CameraHack::Release(Memory& memory) {
    // devolve o jogo ao normal (panic / shutdown)
    if (m_camera && memory.CanWrite()) {
        if (m_typeOwned) {
            memory.Write(m_camera + rbx::Camera::CameraType, m_savedType);
            applog::Line("[camera] CameraType restaurado no release (%d)", m_savedType);
        }
        if (m_fovOwned)
            memory.Write(m_camera + rbx::Camera::FieldOfView, m_savedFov);
    }

    m_freecam = false;
    m_aim = false;
    m_toggled = false;
    m_prevDown = false;
    m_typeOwned = false;
    m_fovOwned = false;
    m_writtenFov = 0.f;
    m_writtenFps = 0.f;
    m_pos = Vector3{};
    m_posValid = false;
    m_lastTick = 0;
    m_camera = 0;
}
