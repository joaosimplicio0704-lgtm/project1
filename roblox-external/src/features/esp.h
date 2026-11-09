#pragma once
#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

#include "../config.h"
#include "../sdk/memory.h"
#include "../sdk/sdk.h"

struct ImDrawList;

// estado do jogador local, resolvido automaticamente no Tick
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

struct Target {
    uintptr_t   player = 0;
    std::string name;
    Vector3     head{};
    Vector3     root{};
    float       health = 0.f;
    float       maxHealth = 100.f;
    float       distance = 0.f;
};

class Esp {
public:
    bool Initialize(cfg::Settings& settings);
    void Shutdown();

    // le a cena inteira (RPM only). devolve false se a cadeia nao resolveu.
    bool Tick();

    void Draw(ImDrawList* list, float width, float height) const;

    const char* Status() const { return m_status; }
    int  TargetCount() const { return static_cast<int>(m_targets.size()); }
    bool Attached() const { return m_memory.Ready(); }
    unsigned long Pid() const { return m_memory.Pid(); }
    unsigned long long Base() const { return m_memory.Base(); }
    uintptr_t DataModel() const { return m_dataModel; }
    const Memory& Mem() const { return m_memory; }
    const Matrix4x4& ViewMatrix() const { return m_view; }
    const std::vector<Target>& Targets() const { return m_targets; }
    const LocalState& Local() const { return m_local; }
    Memory& Mem() { return m_memory; }
    void RequestReattach() { m_forceReattach = true; }

private:
    const std::vector<uintptr_t>& Children(uintptr_t instance);
    bool Attach();

    cfg::Settings* m_settings = nullptr;
    Memory         m_memory;

    Matrix4x4          m_view{};
    std::vector<Target> m_targets;

    uintptr_t m_dataModel = 0;
    LocalState m_local{};
    Vector3   m_localRoot{};
    bool      m_forceReattach = false;
    uint64_t  m_lastAttachAttempt = 0;
    const char* m_status = "idle";

    struct CacheEntry {
        std::vector<uintptr_t> kids;
        uint64_t stamp = 0;
    };
    std::unordered_map<uintptr_t, CacheEntry> m_cache;
};
