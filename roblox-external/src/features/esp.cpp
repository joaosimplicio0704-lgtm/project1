#include "esp.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>

#include "../imgui/imgui.h"
#include "../applog.h"
#include "../offsets.h"

namespace {

constexpr ImU32 kBoxColor      = IM_COL32(0, 255, 130, 210);
constexpr ImU32 kNameColor     = IM_COL32(235, 235, 235, 255);
constexpr ImU32 kDistanceColor = IM_COL32(180, 180, 180, 255);
constexpr ImU32 kBarBack       = IM_COL32(20, 20, 20, 180);
constexpr ImU32 kSkeletonColor = IM_COL32(255, 255, 255, 170);
constexpr ImU32 kTracerColor   = IM_COL32(0, 255, 130, 70);

constexpr const char* kBoneNames[kBoneCount] = {
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot"
};

// R6: um part cobre o membro inteiro
struct BoneAlias { const char* name; int bone; };
constexpr BoneAlias kR6Aliases[] = {
    { "Torso", kBoneUpperTorso },
    { "Torso", kBoneLowerTorso },
    { "Left Arm", kBoneLeftUpperArm },
    { "Right Arm", kBoneRightUpperArm },
    { "Left Leg", kBoneLeftUpperLeg },
    { "Right Leg", kBoneRightUpperLeg },
};

struct BoneLink { int a; int b; };
constexpr BoneLink kBoneLinks[] = {
    { kBoneHead, kBoneUpperTorso },
    { kBoneUpperTorso, kBoneLowerTorso },
    { kBoneUpperTorso, kBoneLeftUpperArm },
    { kBoneLeftUpperArm, kBoneLeftLowerArm },
    { kBoneLeftLowerArm, kBoneLeftHand },
    { kBoneUpperTorso, kBoneRightUpperArm },
    { kBoneRightUpperArm, kBoneRightLowerArm },
    { kBoneRightLowerArm, kBoneRightHand },
    { kBoneLowerTorso, kBoneLeftUpperLeg },
    { kBoneLeftUpperLeg, kBoneLeftLowerLeg },
    { kBoneLeftLowerLeg, kBoneLeftFoot },
    { kBoneLowerTorso, kBoneRightUpperLeg },
    { kBoneRightUpperLeg, kBoneRightLowerLeg },
    { kBoneRightLowerLeg, kBoneRightFoot },
};

constexpr uint64_t kChildrenTtl = 500;
constexpr uint64_t kTextTtl     = 3000;
constexpr uint64_t kPartsTtl    = 2000;

// varredura de objetos por nome: cara (percorre o Workspace), entao roda
// no maximo 4x por segundo e reusa o ultimo resultado nos ticks do meio
constexpr uint64_t kPartsScanMs = 250;
constexpr int      kPartScanCap = 1500;   // instancias olhadas por varredura
constexpr int      kPartMax     = 48;     // marcadores publicados
constexpr ImU32    kPartColor   = IM_COL32(255, 205, 60, 235);
constexpr ImU32    kHighlightColor = IM_COL32(255, 90, 60, 255);

bool Printable(const std::string& text) {
    if (text.empty() || text.size() > 64)
        return false;
    for (char c : text) {
        if (c < 32 || c >= 127)
            return false;
    }
    return true;
}

std::string ReadName(const Memory& memory, uintptr_t instance) {
    if (!instance)
        return {};

    const uintptr_t container = memory.ReadPtr(instance + rbx::Instance::NameContainer);
    if (container) {
        std::string name = memory.ReadString(container + rbx::Instance::Name);
        if (Printable(name))
            return name;
    }

    std::string legacy = memory.ReadString(instance + 0x90);
    if (Printable(legacy))
        return legacy;

    return {};
}

std::string ReadClass(const Memory& memory, uintptr_t instance) {
    if (!instance)
        return {};

    const uintptr_t descriptor = memory.ReadPtr(instance + rbx::Instance::ClassDescriptor);
    if (!descriptor)
        return {};

    const uintptr_t text = memory.ReadPtr(descriptor + rbx::Instance::ClassName);
    if (!text)
        return {};

    char buffer[64]{};
    if (!memory.Read(text, buffer, sizeof(buffer) - 1))
        return {};

    std::string name(buffer);
    return Printable(name) ? name : std::string{};
}

bool ReadPartPosition(const Memory& memory, uintptr_t part, Vector3& out) {
    if (!part)
        return false;

    const uintptr_t primitive = memory.ReadPtr(part + rbx::BasePart::Primitive);
    if (!primitive)
        return false;

    Vector3 position{};
    if (!memory.Read(primitive + rbx::Primitive::Position, position))
        return false;

    if (!position.Finite() || !position.NonZero())
        return false;

    out = position;
    return true;
}

bool MatrixSane(const Matrix4x4& matrix) {
    for (int row = 0; row < 4; ++row) {
        for (int col = 0; col < 4; ++col) {
            if (!std::isfinite(matrix.m[row][col]))
                return false;
        }
    }
    return matrix.m[3][3] != 0.f || matrix.m[3][2] != 0.f;
}

ImU32 HealthColor(float ratio) {
    const int red = static_cast<int>(255.f * (1.f - ratio));
    const int green = static_cast<int>(255.f * ratio);
    return IM_COL32(red, green, 40, 220);
}

} // namespace

Esp::~Esp() {
    Shutdown();
}

bool Esp::Initialize(const cfg::Settings& settings) {
    UpdateSettings(settings);

    ReaderSettings reader;
    {
        std::lock_guard<std::mutex> lock(m_settingsMutex);
        reader = m_reader;
    }

    Attach(reader);

    m_stop.store(false);
    m_thread = std::thread(&Esp::Loop, this);
    return true;
}

void Esp::Shutdown() {
    m_stop.store(true);
    if (m_thread.joinable())
        m_thread.join();

    m_memory.Detach();

    std::lock_guard<std::mutex> lock(m_snapshotMutex);
    m_snapshot.reset();
}

void Esp::UpdateSettings(const cfg::Settings& settings) {
    std::lock_guard<std::mutex> lock(m_settingsMutex);
    m_reader.teamCheck = settings.teamCheck;
    m_reader.skeleton = settings.espSkeleton;
    m_reader.maxDistance = settings.maxDistance;
    m_reader.stealthOpen = settings.stealthOpen;
    m_reader.wantWrite = settings.fly.enabled;
    m_reader.tickMs = settings.tickMs;
    m_reader.parts = settings.espParts;

    if (m_reader.parts) {
        // "coin, cash ,crate" -> {"coin","cash","crate"}
        std::vector<std::string> parsed;
        std::string current;
        for (char c : settings.partsFilter) {
            if (c == ',' || c == ';') {
                while (!current.empty() && current.back() == ' ')
                    current.pop_back();
                if (!current.empty())
                    parsed.push_back(current);
                current.clear();
            } else if (c != ' ' || !current.empty()) {
                current.push_back(c);
            }
        }
        while (!current.empty() && current.back() == ' ')
            current.pop_back();
        if (!current.empty())
            parsed.push_back(current);

        if (parsed != m_reader.partFilters)
            m_reader.partFilters = std::move(parsed);
    } else if (!m_reader.partFilters.empty()) {
        m_reader.partFilters.clear();
    }
}

std::shared_ptr<const SceneSnapshot> Esp::Snapshot() const {
    std::lock_guard<std::mutex> lock(m_snapshotMutex);
    return m_snapshot;
}

bool Esp::Attach(const ReaderSettings& reader) {
    ResetCaches();
    m_dataModel = 0;

    const bool ok = m_memory.Attach(cfg::kProcessName, reader.stealthOpen, reader.wantWrite);
    if (!ok) {
        applog::Line("[mem] attach falhou (processo ausente ou handle negado)");
        return false;
    }

    applog::Line("[mem] attach ok: pid %lu, base 0x%llX, %llu KB, %s",
              static_cast<unsigned long>(m_memory.Pid()),
              static_cast<unsigned long long>(m_memory.Base()),
              static_cast<unsigned long long>(m_memory.BaseSize() / 1024),
              m_memory.CanWrite() ? "VM_WRITE" : "read-only");
    return true;
}

// classes que carregam Primitive (BasePart). Model/Folder nao tem posicao direta.
bool IsPartClass(const std::string& cls) {
    static const char* kClasses[] = {
        "Part", "MeshPart", "UnionOperation", "NegateOperation", "WedgePart",
        "CornerWedgePart", "TrussPart", "Seat", "SpawnLocation", "VehicleSeat",
        "SkateboardPlatform", "FlagStand", "Platform"
    };

    for (const char* candidate : kClasses) {
        if (cls == candidate)
            return true;
    }
    return false;
}

bool NameMatches(const std::string& name, const std::vector<std::string>& filters) {
    if (name.empty() || name == "?")
        return false;

    for (const std::string& filter : filters) {
        if (filter.empty())
            continue;
        if (name.size() < filter.size())
            continue;

        // comparacao case-insensitive por substring
        for (size_t i = 0; i + filter.size() <= name.size(); ++i) {
            bool hit = true;
            for (size_t k = 0; k < filter.size(); ++k) {
                const char a = static_cast<char>(std::tolower(static_cast<unsigned char>(name[i + k])));
                const char b = static_cast<char>(std::tolower(static_cast<unsigned char>(filter[k])));
                if (a != b) {
                    hit = false;
                    break;
                }
            }
            if (hit)
                return true;
        }
    }
    return false;
}

void Esp::ResetCaches() {
    m_children.clear();
    m_names.clear();
    m_classes.clear();
    m_parts.clear();
}

// ------------------------------------------------------------
// thread de leitura: nada aqui toca no render
// ------------------------------------------------------------
void Esp::Loop() {
    while (!m_stop.load(std::memory_order_relaxed)) {
        ReaderSettings reader;
        {
            std::lock_guard<std::mutex> lock(m_settingsMutex);
            reader = m_reader;
        }

        const uint64_t now = GetTickCount64();

        const bool wantReattach = m_reattach.exchange(false, std::memory_order_relaxed);
        const bool writeChanged = m_memory.Ready() && reader.wantWrite && !m_memory.CanWrite();
        // voo desligado: devolve o handle com VM_WRITE e volta pro read-only
        const bool writeDropped = m_memory.Ready() && !reader.wantWrite && m_memory.CanWrite();

        if (writeDropped)
            applog::Line("[mem] voo desligado: fechando handle de escrita (read-only)");

        if (wantReattach || writeChanged || writeDropped || !m_memory.Alive()) {
            if (!m_lastAttachAttempt || now - m_lastAttachAttempt > 1000 || wantReattach) {
                m_lastAttachAttempt = now;
                Attach(reader);
            }
        }

        auto scene = std::make_shared<SceneSnapshot>();
        ReadScene(*scene, reader);

        {
            std::lock_guard<std::mutex> lock(m_snapshotMutex);
            m_snapshot = std::move(scene);
        }

        m_tick = static_cast<uint64_t>(reader.tickMs < 1 ? 1 : reader.tickMs);
        Sleep(static_cast<DWORD>(m_tick));
    }
}

const std::vector<uintptr_t>& Esp::Children(uintptr_t instance, uint64_t now) {
    static const std::vector<uintptr_t> kEmpty;

    if (!instance)
        return kEmpty;

    auto it = m_children.find(instance);
    if (it != m_children.end() && now - it->second.stamp < kChildrenTtl)
        return it->second.kids;

    if (m_children.size() > 4096)
        m_children.clear();

    CacheEntry& entry = m_children[instance];
    entry.kids.clear();
    entry.stamp = now;

    const uintptr_t container = m_memory.ReadPtr(instance + rbx::Instance::ChildrenStart);
    if (!container)
        return entry.kids;

    const uintptr_t array = m_memory.ReadPtr(container);
    const uintptr_t end = m_memory.ReadPtr(container + rbx::Instance::ChildrenEnd);

    // std::vector<shared_ptr<Instance>> — stride 16
    if (!array || end <= array || (end - array) > 0x2000 * 0x10)
        return entry.kids;

    entry.kids.reserve((end - array) / 0x10);

    for (uintptr_t current = array; current < end; current += 0x10) {
        const uintptr_t child = m_memory.ReadPtr(current);
        if (child)
            entry.kids.push_back(child);
    }

    return entry.kids;
}

const std::string& Esp::NameOf(uintptr_t instance, uint64_t now) {
    static const std::string kUnknown = "?";

    if (!instance)
        return kUnknown;

    auto it = m_names.find(instance);
    if (it != m_names.end() && now - it->second.stamp < kTextTtl)
        return it->second.text;

    if (m_names.size() > 4096)
        m_names.clear();

    TextEntry& entry = m_names[instance];
    entry.stamp = now;
    entry.text = ReadName(m_memory, instance);
    if (entry.text.empty())
        entry.text = kUnknown;

    return entry.text;
}

const std::string& Esp::ClassOf(uintptr_t instance, uint64_t now) {
    static const std::string kUnknown = "?";

    if (!instance)
        return kUnknown;

    auto it = m_classes.find(instance);
    if (it != m_classes.end() && now - it->second.stamp < kTextTtl)
        return it->second.text;

    if (m_classes.size() > 4096)
        m_classes.clear();

    TextEntry& entry = m_classes[instance];
    entry.stamp = now;
    entry.text = ReadClass(m_memory, instance);
    if (entry.text.empty())
        entry.text = kUnknown;

    return entry.text;
}

const Esp::PartEntry& Esp::PartsOf(uintptr_t character, uint64_t now) {
    static const PartEntry kEmpty{};

    if (!character)
        return kEmpty;

    auto it = m_parts.find(character);
    if (it != m_parts.end() && now - it->second.stamp < kPartsTtl)
        return it->second;

    if (m_parts.size() > 512)
        m_parts.clear();

    PartEntry& entry = m_parts[character];
    entry.stamp = now;
    entry.rootPart = 0;
    entry.headPart = 0;
    entry.humanoid = 0;
    for (int bone = 0; bone < kBoneCount; ++bone)
        entry.bones[bone] = 0;

    const std::vector<uintptr_t> kids = Children(character, now); // copia: cache pode ser limpo

    for (uintptr_t child : kids) {
        const std::string& name = NameOf(child, now);

        if (!entry.rootPart && name == "HumanoidRootPart")
            entry.rootPart = child;
        else if (!entry.headPart && name == "Head")
            entry.headPart = child;

        if (!entry.humanoid && ClassOf(child, now) == "Humanoid")
            entry.humanoid = child;

        for (int bone = 0; bone < kBoneCount; ++bone) {
            if (!entry.bones[bone] && name == kBoneNames[bone])
                entry.bones[bone] = child;
        }

        for (const BoneAlias& alias : kR6Aliases) {
            if (!entry.bones[alias.bone] && name == alias.name)
                entry.bones[alias.bone] = child;
        }
    }

    return entry;
}

void Esp::ReadScene(SceneSnapshot& scene, const ReaderSettings& reader) {
    scene.stamp = GetTickCount64();
    scene.attached = m_memory.Ready();

    if (!scene.attached) {
        scene.status = "aguardando processo";
        return;
    }

    const uint64_t now = scene.stamp;

    const uintptr_t fakeDataModel = m_memory.ReadPtr(m_memory.Base() + rbx::FakeDataModel::Pointer);
    const uintptr_t dataModel = fakeDataModel ? m_memory.ReadPtr(fakeDataModel + rbx::FakeDataModel::RealDataModel) : 0;

    if (!dataModel) {
        scene.status = "DataModel nao resolveu (offset vencido?)";
        return;
    }

    if (dataModel != m_dataModel) {
        ResetCaches();
        m_dataModel = dataModel;
    }
    scene.dataModel = dataModel;

    const uintptr_t playersService = [&]() -> uintptr_t {
        for (uintptr_t child : Children(dataModel, now)) {
            if (ClassOf(child, now) == "Players")
                return child;
        }
        return 0;
    }();

    if (!playersService) {
        scene.status = "Players nao encontrado";
        return;
    }

    // view matrix
    const uintptr_t visualEngine = m_memory.ReadPtr(m_memory.Base() + rbx::VisualEngine::Pointer);
    if (visualEngine) {
        Matrix4x4 view{};
        if (m_memory.Read(visualEngine + rbx::VisualEngine::ViewMatrix, view) && MatrixSane(view))
            scene.view = view;
    }

    // jogador local
    LocalState& local = scene.local;
    local.dataModel = dataModel;
    local.localPlayer = m_memory.ReadPtr(playersService + rbx::Player::LocalPlayer);

    if (local.localPlayer) {
        const uintptr_t character = m_memory.ReadPtr(local.localPlayer + rbx::Player::ModelInstance);
        local.character = character;

        if (character) {
            const PartEntry& parts = PartsOf(character, now);
            local.rootPart = parts.rootPart;
            local.humanoid = parts.humanoid;

            if (parts.rootPart) {
                local.primitive = m_memory.ReadPtr(parts.rootPart + rbx::BasePart::Primitive);
                if (local.primitive) {
                    m_memory.Read(local.primitive + rbx::Primitive::Position, local.position);
                    m_memory.Read(local.primitive + rbx::Primitive::AssemblyLinearVelocity, local.velocity);
                }
            }

            if (parts.humanoid) {
                local.health = m_memory.ReadOr<float>(parts.humanoid + rbx::Humanoid::Health, 0.f);
                local.maxHealth = m_memory.ReadOr<float>(parts.humanoid + rbx::Humanoid::MaxHealth, 0.f);
                local.walkSpeed = m_memory.ReadOr<float>(parts.humanoid + rbx::Humanoid::Walkspeed, 0.f);
                local.jumpPower = m_memory.ReadOr<float>(parts.humanoid + rbx::Humanoid::JumpPower, 0.f);
            }
        }
    }

    local.workspace = m_memory.ReadPtr(dataModel + rbx::DataModel::Workspace);
    if (local.workspace) {
        local.camera = m_memory.ReadPtr(local.workspace + rbx::Workspace::CurrentCamera);
        if (local.camera) {
            m_memory.Read(local.camera + rbx::Camera::Position, local.cameraPosition);
            m_memory.Read(local.camera + rbx::Camera::Rotation, local.cameraRotation);
            local.fov = m_memory.ReadOr<float>(local.camera + rbx::Camera::FieldOfView, 0.f);
        }
    }

    const uintptr_t localTeam = local.localPlayer
        ? m_memory.ReadPtr(local.localPlayer + rbx::Player::Team)
        : 0;

    // varredura de players
    std::vector<Target> found;
    const std::vector<uintptr_t> players = Children(playersService, now);
    int playerCount = 0;

    for (uintptr_t player : players) {
        if (!player)
            continue;
        if (ClassOf(player, now) != "Player")
            continue;

        ++playerCount;

        if (player == local.localPlayer)
            continue;

        if (reader.teamCheck && localTeam) {
            const uintptr_t team = m_memory.ReadPtr(player + rbx::Player::Team);
            if (team && team == localTeam)
                continue;
        }

        const uintptr_t character = m_memory.ReadPtr(player + rbx::Player::ModelInstance);
        if (!character)
            continue;

        const PartEntry& parts = PartsOf(character, now);
        if (!parts.rootPart || !parts.headPart)
            continue;

        Target target{};
        if (!ReadPartPosition(m_memory, parts.rootPart, target.root))
            continue;
        if (!ReadPartPosition(m_memory, parts.headPart, target.head))
            continue;

        if (local.position.NonZero())
            target.distance = (target.root - local.position).Length();

        if (target.distance > reader.maxDistance)
            continue;

        if (parts.humanoid) {
            target.health = m_memory.ReadOr<float>(parts.humanoid + rbx::Humanoid::Health, 0.f);
            target.maxHealth = m_memory.ReadOr<float>(parts.humanoid + rbx::Humanoid::MaxHealth, 100.f);
            if (target.maxHealth <= 0.f)
                target.maxHealth = 100.f;
            if (target.health <= 0.f)
                continue;
        }

        const uintptr_t primitive = m_memory.ReadPtr(parts.rootPart + rbx::BasePart::Primitive);
        if (primitive)
            m_memory.Read(primitive + rbx::Primitive::AssemblyLinearVelocity, target.velocity);

        if (reader.skeleton) {
            for (int bone = 0; bone < kBoneCount; ++bone) {
                if (!parts.bones[bone])
                    continue;
                Vector3 point{};
                if (ReadPartPosition(m_memory, parts.bones[bone], point)) {
                    target.bones[bone] = point;
                    target.boneValid[bone] = true;
                }
            }
        }

        target.player = player;
        target.name = NameOf(player, now);
        if (target.name == "?")
            continue;

        found.push_back(std::move(target));
    }

    scene.targets = std::move(found);
    scene.playerCount = playerCount;

    ReadParts(scene, reader, now);

    scene.status = "ok";
    ++scene.frame;

    if (m_lastScene && now > m_lastScene) {
        const float instant = 1000.f / static_cast<float>(now - m_lastScene);
        m_tickRate = m_tickRate > 0.f ? m_tickRate * 0.9f + instant * 0.1f : instant;
    }
    m_lastScene = now;
    scene.tickRate = m_tickRate;
}

// ------------------------------------------------------------
// objetos soltos no mapa (loot, caixas, moedas): filtro por nome, sem
// offset de jogo — funciona em qualquer place que use Part com nome.
// ------------------------------------------------------------
void Esp::ReadParts(SceneSnapshot& scene, const ReaderSettings& reader, uint64_t now) {
    if (!reader.parts || reader.partFilters.empty() || !scene.local.workspace) {
        m_lastParts.clear();
        m_partsAt = 0;
        return;
    }

    // reusa a varredura anterior nos ticks do meio (250 ms de intervalo)
    if (m_partsAt && now - m_partsAt < kPartsScanMs) {
        scene.parts = m_lastParts;
        scene.partsScanned = static_cast<int>(m_lastParts.size());
        return;
    }
    m_partsAt = now;

    std::vector<PartMark> found;
    const std::vector<uintptr_t>& kids = Children(scene.local.workspace, now);

    const int limit = static_cast<int>(kids.size()) > kPartScanCap ? kPartScanCap
                                                                  : static_cast<int>(kids.size());
    int scanned = 0;

    for (int i = 0; i < limit && static_cast<int>(found.size()) < kPartMax; ++i) {
        const uintptr_t child = kids[static_cast<size_t>(i)];
        if (!child)
            continue;
        if (!IsPartClass(ClassOf(child, now)))
            continue;

        ++scanned;

        const std::string& name = NameOf(child, now);
        if (!NameMatches(name, reader.partFilters))
            continue;

        Vector3 position{};
        if (!ReadPartPosition(m_memory, child, position) || !position.Finite())
            continue;

        float distance = 0.f;
        if (scene.local.position.NonZero())
            distance = (position - scene.local.position).Length();
        if (distance > reader.maxDistance)
            continue;

        PartMark mark{};
        mark.position = position;
        mark.name = name;
        mark.distance = distance;
        found.push_back(std::move(mark));
    }

    scene.partsScanned = scanned;
    scene.parts = found;
    m_lastParts = std::move(found);
}

// ------------------------------------------------------------
// render: so consome o snapshot
// ------------------------------------------------------------
void Esp::Draw(ImDrawList* list, const cfg::Settings& settings, float width, float height,
               uintptr_t highlightPlayer) const {
    if (!list || width <= 0.f || height <= 0.f)
        return;

    const auto scene = Snapshot();
    if (!scene)
        return;

    const Matrix4x4& view = scene->view;

    // loot primeiro: fica por baixo dos jogadores
    if (settings.espParts) {
        for (const PartMark& part : scene->parts) {
            Vector2 point{};
            if (!WorldToScreen(part.position, point, view, width, height))
                continue;

            char label[96]{};
            std::snprintf(label, sizeof(label), "%s  %dm", part.name.c_str(),
                          static_cast<int>(part.distance));
            const ImVec2 size = ImGui::CalcTextSize(label);

            list->AddCircleFilled(ImVec2(point.x, point.y), 3.f, kPartColor, 8);
            list->AddText(ImVec2(point.x - size.x * 0.5f, point.y + 4.f), kPartColor, label);
        }
    }

    if (!settings.espEnabled)
        return;

    for (const Target& target : scene->targets) {
        Vector2 head{}, root{};
        if (!WorldToScreen(target.head, head, view, width, height))
            continue;
        if (!WorldToScreen(target.root, root, view, width, height))
            continue;

        const float bodyHeight = root.y - head.y;
        if (bodyHeight < 6.f || bodyHeight > height * 1.5f)
            continue;

        const float top = head.y - bodyHeight * 0.12f;
        const float bottom = root.y + bodyHeight * 0.08f;
        const float boxHeight = bottom - top;
        if (boxHeight < 6.f)
            continue;

        const float boxWidth = boxHeight * cfg::kBoxWidthCoef;
        const float centerX = (head.x + root.x) * 0.5f;
        const float left = centerX - boxWidth * 0.5f;
        const float right = centerX + boxWidth * 0.5f;

        const bool highlighted = highlightPlayer && target.player == highlightPlayer;

        if (settings.boxes) {
            list->AddRect(ImVec2(left, top), ImVec2(right, bottom),
                          highlighted ? kHighlightColor : kBoxColor, 0.f, 0,
                          highlighted ? 2.2f : 1.4f);

            if (highlighted) {
                // cantos: deixa obvio qual e o alvo que a mira esta puxando
                const float tick = boxWidth * 0.28f;
                const ImU32 color = kHighlightColor;
                list->AddLine(ImVec2(left, top), ImVec2(left + tick, top), color, 2.2f);
                list->AddLine(ImVec2(left, top), ImVec2(left, top + tick), color, 2.2f);
                list->AddLine(ImVec2(right, top), ImVec2(right - tick, top), color, 2.2f);
                list->AddLine(ImVec2(right, top), ImVec2(right, top + tick), color, 2.2f);
                list->AddLine(ImVec2(left, bottom), ImVec2(left + tick, bottom), color, 2.2f);
                list->AddLine(ImVec2(left, bottom), ImVec2(left, bottom - tick), color, 2.2f);
                list->AddLine(ImVec2(right, bottom), ImVec2(right - tick, bottom), color, 2.2f);
                list->AddLine(ImVec2(right, bottom), ImVec2(right, bottom - tick), color, 2.2f);
            }

            if (settings.healthBar && target.maxHealth > 0.f) {
                const float ratio = std::clamp(target.health / target.maxHealth, 0.f, 1.f);
                const float barX = left - 5.f;
                const float barW = 3.f;
                list->AddRectFilled(ImVec2(barX, top), ImVec2(barX + barW, bottom), kBarBack);
                const float filledTop = bottom - boxHeight * ratio;
                list->AddRectFilled(ImVec2(barX, filledTop), ImVec2(barX + barW, bottom), HealthColor(ratio));
            }
        }

        if (settings.names) {
            const ImVec2 size = ImGui::CalcTextSize(target.name.c_str());
            list->AddText(ImVec2(centerX - size.x * 0.5f, top - size.y - 3.f), kNameColor, target.name.c_str());
        }

        if (settings.distance) {
            char buffer[32]{};
            std::snprintf(buffer, sizeof(buffer), "%d studs", static_cast<int>(target.distance));
            const ImVec2 size = ImGui::CalcTextSize(buffer);
            list->AddText(ImVec2(centerX - size.x * 0.5f, bottom + 2.f), kDistanceColor, buffer);
        }

        if (settings.espHeadDot)
            list->AddCircleFilled(ImVec2(head.x, head.y), 3.f, kBoxColor, 8);

        if (settings.espTracer) {
            list->AddLine(ImVec2(width * 0.5f, height), ImVec2(root.x, bottom), kTracerColor, 1.0f);
        }

        if (settings.espSkeleton) {
            for (const BoneLink& link : kBoneLinks) {
                if (!target.boneValid[link.a] || !target.boneValid[link.b])
                    continue;

                Vector2 a{}, b{};
                if (!WorldToScreen(target.bones[link.a], a, view, width, height))
                    continue;
                if (!WorldToScreen(target.bones[link.b], b, view, width, height))
                    continue;

                list->AddLine(ImVec2(a.x, a.y), ImVec2(b.x, b.y), kSkeletonColor, 1.2f);
            }
        }
    }
}
