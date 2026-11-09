#pragma once
#include <cstdint>

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
// Estado em runtime (menu mexe, config.json persiste)
// ============================================================
struct Settings {
    bool  espEnabled  = true;
    bool  boxes       = true;
    bool  names       = true;
    bool  healthBar   = true;
    bool  distance    = true;
    bool  teamCheck   = true;
    bool  stealthOpen = true;   // abre o handle via StealthyOpenProcess
    bool  handleWatch = true;   // thread que fecha handles de thread orfaos

    float maxDistance = kMaxDistance;
    int   tickMs      = kTickMs;
};

bool Save(const Settings& settings);  // config.json ao lado do .exe
bool Load(Settings& settings);

} // namespace cfg
