#pragma once
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

#include "../config.h"
#include "../sdk/memory.h"
#include "../sdk/sdk.h"

struct ImDrawList;

// estado do jogador local, resolvido automaticamente
struct LocalState {
    uintptr_t dataModel = 0;
    uintptr_t workspace = 0;
    uintptr_t camera = 0;
    uintptr_t localPlayer = 0;
    uintptr_t character = 0;
    uintptr_t humanoid = 0;
    uintptr_t rootPart = 0;
    uintptr_t primitive = 0;

    Vector3 position{};
    Vector3 velocity{};
    Vector3 cameraPosition{};
    float   cameraRotation[9]{};
    float   fov = 0.f;

    float health = 0.f;
    float maxHealth = 0.f;
    float walkSpeed = 0.f;
    float jumpPower = 0.f;

    bool Valid() const { return localPlayer != 0; }
};

// ordem dos ossos lidos por personagem (R15; R6 mapeia no subset)
enum BoneIndex : int {
    kBoneHead = 0,
    kBoneUpperTorso,
    kBoneLowerTorso,
    kBoneLeftUpperArm,
    kBoneLeftLowerArm,
    kBoneLeftHand,
    kBoneRightUpperArm,
    kBoneRightLowerArm,
    kBoneRightHand,
    kBoneLeftUpperLeg,
    kBoneLeftLowerLeg,
    kBoneLeftFoot,
    kBoneRightUpperLeg,
    kBoneRightLowerLeg,
    kBoneRightFoot,
    kBoneCount
};

struct Target {
    uintptr_t   player = 0;
    std::string name;
    Vector3     head{};
    Vector3     root{};
    Vector3     velocity{};
    float       health = 100.f;
    float       maxHealth = 100.f;
    float       distance = 0.f;

    Vector3     bones[kBoneCount]{};
    bool        boneValid[kBoneCount]{};
};

// objeto solto no mapa que bate com o filtro de nomes (loot, caixa, moeda...)
struct PartMark {
    Vector3     position{};
    std::string name;
    float       distance = 0.f;
};

// quadro imutavel publicado pelo leitor: render e aim so leem isto,
// nunca tocam em ReadProcessMemory
struct SceneSnapshot {
    Matrix4x4 view{};
    std::vector<Target> targets;
    std::vector<PartMark> parts;     // filtro por nome (opt-in)
    int        partsScanned = 0;     // instancias olhadas na ultima varredura
    LocalState local{};
    uintptr_t  dataModel = 0;
    std::string status = "iniciando";
    uint64_t   stamp = 0;
    bool       attached = false;
    int        frame = 0;
    int        playerCount = 0;   // todo mundo no Players, incluindo voce
    float      tickRate = 0.f;    // Hz real do leitor
};

class Esp {
public:
    Esp() = default;
    ~Esp();

    Esp(const Esp&) = delete;
    Esp& operator=(const Esp&) = delete;

    bool Initialize(const cfg::Settings& settings);
    void Shutdown();

    // copia os campos que o leitor precisa (thread-safe, barato)
    void UpdateSettings(const cfg::Settings& settings);

    std::shared_ptr<const SceneSnapshot> Snapshot() const;

    // highlightPlayer = player travado pelo aim (desenha a caixa destacada)
    void Draw(ImDrawList* list, const cfg::Settings& settings, float width, float height,
              uintptr_t highlightPlayer = 0) const;

    Memory& Mem() { return m_memory; }
    const Memory& Mem() const { return m_memory; }
    DWORD Pid() const { return m_memory.Pid(); }
    uintptr_t Base() const { return m_memory.Base(); }

    void RequestReattach() { m_reattach.store(true, std::memory_order_relaxed); }

private:
    struct ReaderSettings {
        bool  teamCheck = true;
        bool  skeleton = false;
        float maxDistance = 2000.f;
        bool  stealthOpen = true;
        bool  wantWrite = false;
        int   tickMs = 4;
        bool  parts = false;
        std::vector<std::string> partFilters;
    };

    struct CacheEntry {
        std::vector<uintptr_t> kids;
        uint64_t stamp = 0;
    };

    struct TextEntry {
        std::string text;
        uint64_t stamp = 0;
    };

    struct PartEntry {
        uintptr_t rootPart = 0;
        uintptr_t headPart = 0;
        uintptr_t humanoid = 0;
        uintptr_t bones[kBoneCount]{};
        uint64_t  stamp = 0;
    };

    void Loop();
    bool Attach(const ReaderSettings& reader);
    void ReadScene(SceneSnapshot& scene, const ReaderSettings& reader);
    void ReadParts(SceneSnapshot& scene, const ReaderSettings& reader, uint64_t now);
    void ResetCaches();

    const std::vector<uintptr_t>& Children(uintptr_t instance, uint64_t now);
    const std::string& NameOf(uintptr_t instance, uint64_t now);
    const std::string& ClassOf(uintptr_t instance, uint64_t now);
    const PartEntry& PartsOf(uintptr_t character, uint64_t now);

    Memory m_memory;

    std::thread        m_thread;
    std::atomic<bool>  m_stop{false};
    std::atomic<bool>  m_reattach{false};

    mutable std::mutex m_snapshotMutex;
    std::shared_ptr<const SceneSnapshot> m_snapshot;

    mutable std::mutex m_settingsMutex;
    ReaderSettings     m_reader;

    // --- estado do worker (so a thread de leitura toca) ---
    uintptr_t m_dataModel = 0;
    uint64_t  m_partsAt = 0;
    std::vector<PartMark> m_lastParts;
    uint64_t  m_lastAttachAttempt = 0;
    uint64_t  m_tick = 4;
    uint64_t  m_lastScene = 0;
    float     m_tickRate = 0.f;

    std::unordered_map<uintptr_t, CacheEntry> m_children;
    std::unordered_map<uintptr_t, TextEntry>  m_names;
    std::unordered_map<uintptr_t, TextEntry>  m_classes;
    std::unordered_map<uintptr_t, PartEntry>  m_parts;
};
