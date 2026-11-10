#pragma once
#include <cstdint>
#include <string>
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
inline constexpr int kPanicKey = 0x79; // F10     — desliga aim/tiro/voo e solta o mouse

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
    float smoothing = 4.f;             // divisor: maior = mais lento
    float strength = 0.55f;            // 0..1 — fracao do erro aplicada por tick
    float maxStepPx = 45.f;            // limite de movimento por tick
    float deadzonePx = 2.f;            // nao mexe abaixo disso
    float jitterPx = 0.f;              // ruido no delta (humano)
    float leadMs = 0.f;                // antecipa alvo em movimento (0..200)
    float snapPx = 18.f;               // abaixo disso a correcao e exata (0 = desliga)

    bool  drawFov = true;
    bool  requireForeground = true;    // so age com a janela do jogo na frente

    // mira por camera: escreve Camera::Rotation no frame do disparo (exata,
    // sem SendInput). Opt-in: mexe no estado da camera do jogo.
    bool  cameraMode = false;
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

// ============================================================
// VOO — escreve em memoria (unico modulo que faz isso)
// ============================================================
struct FlySettings {
    bool  enabled = false;
    bool  toggleMode = false;
    int   key = 0x46;              // VK_F
    float speed = 60.f;            // studs por segundo
    bool  zeroVelocity = true;     // zera AssemblyLinearVelocity pra gravidade nao brigar
    bool  hoverOnIdle = true;      // sem WASD: segura a altura em vez de cair
    bool  requireForeground = true;
    bool  anchor = false;          // jogos que revertem a posicao: trava o HRP (Anchored)
};

// ============================================================
// CAMERA — freecam, FOV e destravamento de FPS
// Tudo local: o servidor nunca ve a camera.
// ============================================================
struct CameraSettings {
    bool  freecam = false;
    int   freecamKey = 0x43;      // VK_C
    float freecamSpeed = 80.f;    // studs/s
    bool  fovHack = false;
    float fov = 110.f;            // graus (jogo normal: 70)
    bool  unlockFps = false;
    int   maxFps = 240;
};

// ============================================================
// ITENS — puxar objeto filtrado pra perto do personagem
// ============================================================
struct MagnetSettings {
    bool  enabled = false;
    float range = 250.f;          // so considera itens ate essa distancia
    float pullDistance = 4.f;     // onde o item para, em studs de voce
    int   perSecond = 10;         // writes por segundo (cada um puxa 1 item)
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
    bool  espSkeleton = false;   // custa 15 leituras por alvo
    bool  espTracer   = false;
    bool  espHeadDot  = false;

    // objetos por nome (loot/caixa/moeda): sem offset de jogo, filtra o Workspace
    bool        espParts    = false;
    std::string partsFilter = "coin,cash,crate,ammo,key,loot,drop,gem,ore,chest,box";

    // mira desenhada no centro (o cursor do sistema fica escondido no jogo)
    bool  crosshair = false;
    float crosshairSize = 9.f;
    bool  teamCheck   = true;
    bool  stealthOpen = true;
    bool  handleWatch = true;

    float maxDistance = kMaxDistance;
    int   tickMs      = kTickMs;

    AimSettings aim;
    TriggerSettings fire;
    FlySettings fly;
    CameraSettings camera;
    MagnetSettings magnet;
    std::vector<Profile> profiles;
};

bool Save(const Settings& settings);  // config.json + profiles.json

// comparacao campo a campo: o main usa isso pra auto-salvar quando algo muda
bool Same(const Settings& a, const Settings& b);
bool Load(Settings& settings);

const Profile* FindProfile(const Settings& settings, uint64_t placeId);
void UpsertProfile(Settings& settings, const Profile& profile);
void ApplyProfile(Settings& settings, const Profile& profile);

} // namespace cfg
