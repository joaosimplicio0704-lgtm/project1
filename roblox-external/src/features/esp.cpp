#include "esp.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>

#include "../imgui/imgui.h"
#include "../offsets.h"

namespace {

constexpr ImU32 kBoxColor     = IM_COL32(0, 255, 130, 210);
constexpr ImU32 kNameColor    = IM_COL32(235, 235, 235, 255);
constexpr ImU32 kDistanceColor= IM_COL32(180, 180, 180, 255);
constexpr ImU32 kBarBack      = IM_COL32(20, 20, 20, 180);
constexpr float kNameScale    = 1.0f;

bool Printable(const std::string& text) {
    if (text.empty() || text.size() > 64)
        return false;
    for (char c : text) {
        if (c < 32 || c >= 127)
            return false;
    }
    return true;
}

// Instance::NameContainer -> std::string (len em +0x10).
// fallback para o offset antigo (0x90) caso o dump venha de outro build.
std::string ReadName(const Memory& mem, uintptr_t instance) {
    if (!instance)
        return {};

    const uintptr_t container = mem.ReadPtr(instance + rbx::Instance::NameContainer);
    if (container) {
        std::string name = mem.ReadString(container + rbx::Instance::Name);
        if (Printable(name))
            return name;
    }

    std::string legacy = mem.ReadString(instance + 0x90);
    if (Printable(legacy))
        return legacy;

    return {};
}

std::string ReadClass(const Memory& mem, uintptr_t instance) {
    if (!instance)
        return {};

    const uintptr_t descriptor = mem.ReadPtr(instance + rbx::Instance::ClassDescriptor);
    if (!descriptor)
        return {};

    const uintptr_t text = mem.ReadPtr(descriptor + rbx::Instance::ClassName);
    if (!text)
        return {};

    char buffer[64]{};
    if (!mem.Read(text, buffer, sizeof(buffer) - 1))
        return {};

    std::string name(buffer);
    return Printable(name) ? name : std::string{};
}

uintptr_t FindByName(const Memory& mem, const std::vector<uintptr_t>& children, const char* wanted) {
    for (uintptr_t child : children) {
        if (ReadName(mem, child) == wanted)
            return child;
    }
    return 0;
}

uintptr_t FindByClass(const Memory& mem, const std::vector<uintptr_t>& children, const char* wanted) {
    for (uintptr_t child : children) {
        if (ReadClass(mem, child) == wanted)
            return child;
    }
    return 0;
}

bool ReadPartPosition(const Memory& mem, uintptr_t part, Vector3& out) {
    if (!part)
        return false;

    const uintptr_t primitive = mem.ReadPtr(part + rbx::BasePart::Primitive);
    if (!primitive)
        return false;

    Vector3 position{};
    if (!mem.Read(primitive + rbx::Primitive::Position, position))
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

bool Esp::Initialize(cfg::Settings& settings) {
    m_settings = &settings;
    return Attach();
}

bool Esp::Attach() {
    m_cache.clear();
    m_dataModel = 0;
    m_targets.clear();
    m_view = Matrix4x4{};

    if (m_memory.Attach(cfg::kProcessName, m_settings && m_settings->stealthOpen)) {
        m_status = "ok";
        return true;
    }

    m_status = "RobloxPlayerBeta.exe nao encontrado";
    return false;
}

void Esp::Shutdown() {
    m_memory.Detach();
    m_cache.clear();
    m_targets.clear();
    m_dataModel = 0;
}

const std::vector<uintptr_t>& Esp::Children(uintptr_t instance) {
    static const std::vector<uintptr_t> kEmpty;

    const uint64_t now = GetTickCount64();

    auto it = m_cache.find(instance);
    if (it != m_cache.end() && now - it->second.stamp < 500)
        return it->second.kids;

    // cache cresce sem limite entre rejoins -> limpa tudo quando estoura
    if (m_cache.size() > 1024)
        m_cache.clear();

    CacheEntry& entry = m_cache[instance];
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

bool Esp::Tick() {
    if (!m_settings)
        return false;

    // ---- processo ----
    if (m_forceReattach || !m_memory.Alive()) {
        const uint64_t now = GetTickCount64();
        if (!m_lastAttachAttempt || now - m_lastAttachAttempt > 1000 || m_forceReattach) {
            m_forceReattach = false;
            m_lastAttachAttempt = now;
            Attach();
        }
    }

    if (!m_memory.Ready()) {
        m_targets.clear();
        if (!m_status || std::string(m_status) == "ok")
            m_status = "aguardando processo";
        return false;
    }

    // ---- DataModel ----
    const uintptr_t fakeDataModel = m_memory.ReadPtr(m_memory.Base() + rbx::FakeDataModel::Pointer);
    const uintptr_t dataModel = fakeDataModel ? m_memory.ReadPtr(fakeDataModel + rbx::FakeDataModel::RealDataModel) : 0;

    if (!dataModel) {
        m_status = "DataModel nao resolveu (offset vencido?)";
        m_targets.clear();
        return false;
    }

    if (dataModel != m_dataModel) {
        m_cache.clear();
        m_dataModel = dataModel;
    }

    // ---- Players service ----
    const std::vector<uintptr_t> root = Children(dataModel);
    const uintptr_t playersService = FindByClass(m_memory, root, "Players");
    if (!playersService) {
        m_status = "Players nao encontrado";
        m_targets.clear();
        return false;
    }

    // ---- view matrix ----
    const uintptr_t visualEngine = m_memory.ReadPtr(m_memory.Base() + rbx::VisualEngine::Pointer);
    Matrix4x4 view{};
    if (visualEngine && m_memory.Read(visualEngine + rbx::VisualEngine::ViewMatrix, view) && MatrixSane(view))
        m_view = view;

    // ---- local player ----
    const uintptr_t localPlayer = m_memory.ReadPtr(playersService + rbx::Player::LocalPlayer);
    const uintptr_t localTeam = localPlayer ? m_memory.ReadPtr(localPlayer + rbx::Player::Team) : 0;

    m_localRoot = Vector3{};
    if (localPlayer) {
        const uintptr_t character = m_memory.ReadPtr(localPlayer + rbx::Player::ModelInstance);
        if (character) {
            const std::vector<uintptr_t> parts = Children(character);
            const uintptr_t rootPart = FindByName(m_memory, parts, "HumanoidRootPart");
            ReadPartPosition(m_memory, rootPart, m_localRoot);
        }
    }

    // ---- varredura de players ----
    std::vector<Target> found;
    const std::vector<uintptr_t> players = Children(playersService); // copia: Children() mexe no cache

    for (uintptr_t player : players) {
        if (!player || player == localPlayer)
            continue;
        if (ReadClass(m_memory, player) != "Player")
            continue;

        if (m_settings->teamCheck && localTeam) {
            const uintptr_t team = m_memory.ReadPtr(player + rbx::Player::Team);
            if (team && team == localTeam)
                continue;
        }

        const uintptr_t character = m_memory.ReadPtr(player + rbx::Player::ModelInstance);
        if (!character)
            continue;

        const std::vector<uintptr_t> parts = Children(character);

        const uintptr_t rootPart = FindByName(m_memory, parts, "HumanoidRootPart");
        const uintptr_t headPart = FindByName(m_memory, parts, "Head");
        if (!rootPart || !headPart)
            continue;

        Target target{};
        if (!ReadPartPosition(m_memory, rootPart, target.root))
            continue;
        if (!ReadPartPosition(m_memory, headPart, target.head))
            continue;

        if (m_localRoot.NonZero())
            target.distance = (target.root - m_localRoot).Length();

        if (target.distance > m_settings->maxDistance)
            continue;

        const uintptr_t humanoid = FindByClass(m_memory, parts, "Humanoid");
        if (humanoid) {
            target.health = m_memory.ReadOr<float>(humanoid + rbx::Humanoid::Health, 0.f);
            target.maxHealth = m_memory.ReadOr<float>(humanoid + rbx::Humanoid::MaxHealth, 100.f);
            if (target.maxHealth <= 0.f)
                target.maxHealth = 100.f;
            if (target.health <= 0.f)
                continue; // morto
        }

        target.player = player;
        target.name = ReadName(m_memory, player);
        if (target.name.empty())
            continue;

        found.push_back(std::move(target));
    }

    m_targets = std::move(found);
    m_status = "ok";
    return true;
}

void Esp::Draw(ImDrawList* list, float width, float height) const {
    if (!list || !m_settings)
        return;
    if (!m_settings->espEnabled || width <= 0.f || height <= 0.f)
        return;

    for (const Target& target : m_targets) {
        Vector2 head{}, root{};
        if (!WorldToScreen(target.head, head, m_view, width, height))
            continue;
        if (!WorldToScreen(target.root, root, m_view, width, height))
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

        if (m_settings->boxes) {
            list->AddRect(ImVec2(left, top), ImVec2(right, bottom), kBoxColor, 0.f, 0, 1.4f);
            if (m_settings->healthBar && target.maxHealth > 0.f) {
                const float ratio = std::clamp(target.health / target.maxHealth, 0.f, 1.f);
                const float barX = left - 5.f;
                const float barW = 3.f;
                list->AddRectFilled(ImVec2(barX, top), ImVec2(barX + barW, bottom), kBarBack);
                const float filledTop = bottom - boxHeight * ratio;
                list->AddRectFilled(ImVec2(barX, filledTop), ImVec2(barX + barW, bottom), HealthColor(ratio));
            }
        }

        if (m_settings->names) {
            const ImVec2 size = ImGui::CalcTextSize(target.name.c_str());
            const ImVec2 position(centerX - size.x * 0.5f * kNameScale, top - size.y - 3.f);
            list->AddText(ImGui::GetFont(), ImGui::GetFontSize() * kNameScale, position, kNameColor, target.name.c_str());
        }

        if (m_settings->distance) {
            char buffer[32]{};
            std::snprintf(buffer, sizeof(buffer), "%d studs", static_cast<int>(target.distance));
            const ImVec2 size = ImGui::CalcTextSize(buffer);
            list->AddText(ImVec2(centerX - size.x * 0.5f, bottom + 2.f), kDistanceColor, buffer);
        }
    }
}
