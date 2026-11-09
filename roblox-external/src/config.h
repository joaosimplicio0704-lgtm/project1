#pragma once
#include <cstdint>
#include <vector>

namespace cfg {

// ============================================================
// KNOBS — um lugar pra tunar
// ============================================================

inline constexpr const char* kProcessName = "RobloxPlayerBeta.exe";

// teclas (VK_*)
inline constexpr int kMenuKey = 0x2D;  // INSERT  — abre/fecha menu e libera o mouse
inline constexpr int kEspKey  = 0x70;  // F1      — liga/desliga ESP
inline constexpr int kBoxKey  = 0x71;  // F2      — liga/desliga caixa
inline constexpr int kExitKey = 0x23;  // END     — fecha

inline constexpr int   kTickMs       = 4;      // poll de memoria
inline constexpr float kMaxDistance  = 2000.f; // studs
inline constexpr float kBoxWidthCoef = 0.55f;  // largura da caixa = altura * coef

// ============================================================
// AIM — quanto a mira puxa
// ============================================================

enum AimBone : int {
    kHead = 0,
    kChest = 1,
    kRoot = 2
};

struct AimSettings {
    bool  enabled = false;             // nada dispara no launch
    int   key = 0x06;                  // VK_XBUTTON2 (botao lateral do mouse)
    bool  toggleMode = false;          // false = segurar a tecla
    int   bone = kHead;

    float fovPx = 160.f;               // raio do FOV em pixels
    float smoothing = 6.f;             // divisor: maior = mais lento
    float strength = 0.55f;            // 0..1 — fracao do erro aplicada por tick
    float maxStepPx = 45.f;            // limite de movimento por tick
    float deadzonePx = 2.f;            // nao mexe abaixo disso
    float jitterPx = 0.f;              // ruido no delta (humano)

    bool  drawFov = true;
    bool  requireForeground = true;    // so age com a janela do jogo na frente
};

// ============================================================
// TIRO — portao + cadencia
// ============================================================
struct TriggerSettings {
    bool  enabled = false;
    int   key = 0x05;              // VK_XBUTTON1 (botao lateral)
    bool  autoFire = false;        // atira sozinho quando o portao abre
    float maxErrorPx = 3.f;        // so atira com o crosshair em cima
    int   minIntervalMs = 120;     // cadencia maxima
    int   holdMs = 12;             // tempo pressionado
    int   burst = 1;               // tiros por aperto
    bool  requireForeground = true;
};

// perfil por jogo (PlaceId)
struct Profile {
    uint64_t placeId = 0;
    float    fovPx = 160.f;
    float    smoothing = 6.f;
    float    strength = 0.55f;
    int      bone = kHead;
};

// ============================================================
// Estado em runtime (menu mexe, config.json persiste)
// ============================================================
struct Settings {
    bool  espEnabled  = true;
    bool  boxes       = true;
    bool  names       = true;
    bool  healthBar   = true;
    bool  distance    = true;
    bool  teamCheck   = true;
    bool  stealthOpen = true;
    bool  handleWatch = true;

    float maxDistance = kMaxDistance;
    int   tickMs      = kTickMs;

    AimSettings aim;
    TriggerSettings fire;
    std::vector<Profile> profiles;
};

bool Save(const Settings& settings);  // config.json + profiles.json
bool Load(Settings& settings);

const Profile* FindProfile(const Settings& settings, uint64_t placeId);
void UpsertProfile(Settings& settings, const Profile& profile);
void ApplyProfile(Settings& settings, const Profile& profile);

} // namespace cfg
