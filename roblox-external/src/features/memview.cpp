#include "memview.h"

#include <windows.h>

#include <cstdarg>
#include <cstdio>
#include <cstring>

#include "../features/esp.h"
#include "../imgui/imgui.h"

namespace {

constexpr ImU32 kAddressColor = IM_COL32(150, 150, 160, 255);
constexpr ImU32 kByteColor = IM_COL32(220, 220, 220, 255);
constexpr ImU32 kZeroColor = IM_COL32(110, 110, 120, 255);
constexpr ImU32 kChangedColor = IM_COL32(120, 255, 140, 255);
constexpr ImU32 kAsciiColor = IM_COL32(170, 190, 170, 255);

constexpr size_t kScanChunk = 1u << 20;   // 1MB por leitura
constexpr size_t kScanLimit = 1000;       // teto de resultados

const char* TypeName(int type) {
    switch (type) {
    case kByte: return "u8";
    case kInt32: return "i32";
    case kUInt32: return "u32";
    case kInt64: return "i64";
    case kFloat: return "float";
    case kDouble: return "double";
    case kPointer: return "ptr";
    case kString: return "string";
    default: return "?";
    }
}

const char* ScanTypeName(int type) {
    switch (type) {
    case kScanInt32: return "i32";
    case kScanFloat: return "float";
    case kScanInt64: return "i64";
    default: return "?";
    }
}

size_t ScanTypeSize(int type) {
    switch (type) {
    case kScanInt32: return 4;
    case kScanFloat: return 4;
    case kScanInt64: return 8;
    default: return 4;
    }
}

bool ParseNumber(const std::string& text, uintptr_t& out) {
    if (text.empty())
        return false;

    char* end = nullptr;
    const uintptr_t value = static_cast<uintptr_t>(std::strtoull(text.c_str(), &end, 0));
    if (end == text.c_str())
        return false;

    out = value;
    return true;
}

std::string Trim(const std::string& text) {
    const size_t begin = text.find_first_not_of(" \t");
    if (begin == std::string::npos)
        return {};
    const size_t end = text.find_last_not_of(" \t");
    return text.substr(begin, end - begin + 1);
}

uintptr_t ResolveExpression(const Memory& memory, const std::string& expression, bool& ok) {
    ok = false;
    if (expression.empty())
        return 0;

    uintptr_t current = 0;
    bool first = true;

    size_t pos = 0;
    while (pos <= expression.size()) {
        const size_t next = expression.find('>', pos);
        const std::string token = Trim(expression.substr(pos, next == std::string::npos ? std::string::npos : next - pos));
        if (token.empty())
            return 0;

        uintptr_t offset = 0;
        std::string basePart = token;
        const size_t plus = token.find('+');
        if (plus != std::string::npos) {
            basePart = Trim(token.substr(0, plus));
            if (!ParseNumber(Trim(token.substr(plus + 1)), offset))
                return 0;
        }

        const bool fromBase = (basePart == "base" || basePart == "module" || basePart == "roblox");
        if (first) {
            if (fromBase) {
                if (!memory.Base())
                    return 0;
                current = memory.Base() + offset;
            } else if (basePart.empty()) {
                current = offset;
            } else {
                if (!ParseNumber(basePart, current))
                    return 0;
                current += offset;
            }
            first = false;
        } else {
            if (!fromBase && !basePart.empty()) {
                uintptr_t absolute = 0;
                if (!ParseNumber(basePart, absolute))
                    return 0;
                offset = absolute + offset;
            }
            current = memory.ReadPtr(current);
            if (!current)
                return 0;
            current += offset;
        }

        if (next == std::string::npos)
            break;
        pos = next + 1;
    }

    ok = current != 0;
    return current;
}

bool Matches(const uint8_t* data, int type, double value) {
    switch (type) {
    case kScanInt32: {
        const int32_t expected = static_cast<int32_t>(value);
        int32_t found{};
        std::memcpy(&found, data, sizeof(found));
        return found == expected;
    }
    case kScanFloat: {
        const float expected = static_cast<float>(value);
        float found{};
        std::memcpy(&found, data, sizeof(found));
        return std::memcmp(&found, &expected, sizeof(float)) == 0;
    }
    case kScanInt64: {
        const int64_t expected = static_cast<int64_t>(value);
        int64_t found{};
        std::memcpy(&found, data, sizeof(found));
        return found == expected;
    }
    default:
        return false;
    }
}

std::string FormatScanValue(const Memory& memory, uintptr_t address, int type) {
    char buffer[48]{};
    switch (type) {
    case kScanInt32:
        std::snprintf(buffer, sizeof(buffer), "%d", memory.ReadOr<int32_t>(address, 0));
        break;
    case kScanFloat:
        std::snprintf(buffer, sizeof(buffer), "%.4f", memory.ReadOr<float>(address, 0.f));
        break;
    case kScanInt64:
        std::snprintf(buffer, sizeof(buffer), "%lld",
                      static_cast<long long>(memory.ReadOr<int64_t>(address, 0)));
        break;
    default:
        break;
    }
    return buffer;
}

} // namespace

// ============================================================
// automatico
// ============================================================
static void Row(const char* label, const char* format, ...) {
    va_list args;
    va_start(args, format);
    ImGui::TextColored(ImVec4(0.62f, 0.62f, 0.68f, 1.f), "%s", label);
    ImGui::SameLine(150.f);
    ImGui::TextV(format, args);
    va_end(args);
}

static void RowAddress(const char* label, uintptr_t address) {
    Row(label, "0x%llX", static_cast<unsigned long long>(address));
}

void MemView::DrawAuto(const Esp& esp) {
    const LocalState& local = esp.Local();

    if (!esp.Attached()) {
        ImGui::TextDisabled("sem processo — procurando RobloxPlayerBeta.exe");
        return;
    }
    if (!local.Valid()) {
        ImGui::TextDisabled("processo ok, personagem ainda nao carregou");
        return;
    }

    RowAddress("DataModel", local.dataModel);
    RowAddress("Workspace", local.workspace);
    RowAddress("Camera", local.camera);
    RowAddress("LocalPlayer", local.localPlayer);
    RowAddress("Character", local.character);
    RowAddress("Humanoid", local.humanoid);
    RowAddress("RootPart", local.rootPart);
    RowAddress("Primitive", local.primitive);

    ImGui::Separator();
    Row("Health", "%.1f / %.1f", local.health, local.maxHealth);
    Row("WalkSpeed", "%.2f", local.walkSpeed);
    Row("JumpPower", "%.2f", local.jumpPower);

    Row("Position", "%.2f, %.2f, %.2f", local.position.x, local.position.y, local.position.z);
    Row("Velocity", "%.2f, %.2f, %.2f", local.velocity.x, local.velocity.y, local.velocity.z);
    Row("Camera pos", "%.2f, %.2f, %.2f", local.cameraPosition.x, local.cameraPosition.y, local.cameraPosition.z);
    Row("Camera fwd", "%.3f, %.3f, %.3f",
        -local.cameraRotation[2], -local.cameraRotation[5], -local.cameraRotation[8]);
    Row("FOV", "%.1f", local.fov);
}

// ============================================================
// varredura
// ============================================================
void MemView::ScanReset() {
    m_scan.clear();
    m_scanTruncated = false;
    m_scanStatus[0] = '\0';
}

void MemView::ScanStart(const Memory& memory) {
    m_scan.clear();
    m_scanTruncated = false;

    const HANDLE handle = memory.Handle();
    const uintptr_t base = memory.Base();
    const size_t size = memory.BaseSize();

    if (!handle || !base || !size) {
        std::snprintf(m_scanStatus, sizeof(m_scanStatus), "sem modulo para varrer");
        return;
    }

    const size_t typeSize = ScanTypeSize(m_scanType);
    const double value = std::atof(m_scanValue);

    std::vector<uint8_t> buffer(kScanChunk);
    uintptr_t address = base;
    const uintptr_t limit = base + size;

    while (address < limit && m_scan.size() < kScanLimit) {
        MEMORY_BASIC_INFORMATION region{};
        if (!VirtualQueryEx(handle, reinterpret_cast<LPCVOID>(address), &region, sizeof(region)))
            break;

        const uintptr_t regionBase = reinterpret_cast<uintptr_t>(region.BaseAddress);
        const uintptr_t regionEnd = regionBase + region.RegionSize;
        const uintptr_t nextRegion = regionEnd > address ? regionEnd : address + 0x1000;

        const bool readable = region.State == MEM_COMMIT &&
                              !(region.Protect & PAGE_GUARD) &&
                              !(region.Protect & PAGE_NOACCESS) &&
                              (region.Protect & (PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY |
                                                 PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE));

        if (!readable) {
            address = nextRegion;
            continue;
        }

        for (uintptr_t cursor = address; cursor < regionEnd && m_scan.size() < kScanLimit; cursor += kScanChunk) {
            const size_t remaining = static_cast<size_t>(regionEnd - cursor);
            const size_t toRead = remaining < kScanChunk ? remaining : kScanChunk;

            SIZE_T got = 0;
            if (!ReadProcessMemory(handle, reinterpret_cast<LPCVOID>(cursor), buffer.data(), toRead, &got) || got < typeSize) {
                continue;
            }

            for (size_t offset = 0; offset + typeSize <= got; offset += typeSize) {
                if (!Matches(buffer.data() + offset, m_scanType, value))
                    continue;

                m_scan.push_back(cursor + offset);
                if (m_scan.size() >= kScanLimit) {
                    m_scanTruncated = true;
                    break;
                }
            }
        }

        address = nextRegion;
    }

    std::snprintf(m_scanStatus, sizeof(m_scanStatus), "%d resultado(s)%s",
                  static_cast<int>(m_scan.size()), m_scanTruncated ? " (teto atingido)" : "");
}

void MemView::ScanFilter(const Memory& memory) {
    if (m_scan.empty())
        return;

    const double value = std::atof(m_scanValue);
    const size_t typeSize = ScanTypeSize(m_scanType);

    std::vector<uintptr_t> kept;
    kept.reserve(m_scan.size());

    uint8_t data[8]{};
    for (uintptr_t address : m_scan) {
        if (!memory.Read(address, data, typeSize))
            continue;
        if (Matches(data, m_scanType, value))
            kept.push_back(address);
    }

    m_scan = std::move(kept);
    std::snprintf(m_scanStatus, sizeof(m_scanStatus), "%d resultado(s) apos filtro",
                  static_cast<int>(m_scan.size()));
}

void MemView::DrawScanner(const Memory& memory) {
    ImGui::TextDisabled("acha o endereco de um valor que voce ve no jogo");

    ImGui::SetNextItemWidth(110.f);
    if (ImGui::BeginCombo("##scantype", ScanTypeName(m_scanType))) {
        for (int type = kScanInt32; type <= kScanInt64; ++type) {
            if (ImGui::Selectable(ScanTypeName(type), type == m_scanType))
                m_scanType = type;
        }
        ImGui::EndCombo();
    }

    ImGui::SameLine();
    ImGui::SetNextItemWidth(140.f);
    ImGui::InputText("##scanvalue", m_scanValue, sizeof(m_scanValue));

    ImGui::SameLine();
    if (ImGui::Button("Novo scan"))
        ScanStart(memory);

    ImGui::SameLine();
    ImGui::BeginDisabled(m_scan.empty());
    if (ImGui::Button("Filtrar"))
        ScanFilter(memory);
    ImGui::SameLine();
    if (ImGui::Button("Limpar"))
        ScanReset();
    ImGui::EndDisabled();

    if (m_scanStatus[0])
        ImGui::TextDisabled("%s", m_scanStatus);

    if (!m_scan.empty()) {
        ImGui::BeginChild("##scan", ImVec2(0.f, 180.f), true);
        ImGuiListClipper clipper;
        clipper.Begin(static_cast<int>(m_scan.size()));
        while (clipper.Step()) {
            for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; ++i) {
                const uintptr_t address = m_scan[static_cast<size_t>(i)];
                ImGui::PushID(i);

                ImGui::TextColored(ImVec4(0.62f, 0.62f, 0.68f, 1.f), "0x%llX",
                                   static_cast<unsigned long long>(address));
                ImGui::SameLine(200.f);
                ImGui::TextUnformatted(FormatScanValue(memory, address, m_scanType).c_str());
                ImGui::SameLine(340.f);
                if (ImGui::SmallButton("watch")) {
                    Watch watch{};
                    char expr[32]{};
                    std::snprintf(expr, sizeof(expr), "0x%llX", static_cast<unsigned long long>(address));
                    watch.expr = expr;
                    watch.type = m_scanType == kScanFloat ? kFloat : (m_scanType == kScanInt64 ? kInt64 : kInt32);
                    m_watches.push_back(std::move(watch));
                }
                ImGui::SameLine();
                if (ImGui::SmallButton("dump")) {
                    m_dumpAddress = address;
                    m_dumpPrevAddress = 0;
                }

                ImGui::PopID();
            }
        }
        ImGui::EndChild();
    }
}

// ============================================================
// watches / dump
// ============================================================
void MemView::ReadWatch(const Memory& memory, Watch& watch) {
    watch.changed = false;
    watch.value[0] = '\0';

    if (!watch.address)
        return;

    char buffer[96]{};

    switch (watch.type) {
    case kByte: {
        const uint8_t v = memory.ReadOr<uint8_t>(watch.address, 0);
        std::snprintf(buffer, sizeof(buffer), "%u (0x%02X)", v, v);
        break;
    }
    case kInt32: {
        const int32_t v = memory.ReadOr<int32_t>(watch.address, 0);
        std::snprintf(buffer, sizeof(buffer), "%d", v);
        break;
    }
    case kUInt32: {
        const uint32_t v = memory.ReadOr<uint32_t>(watch.address, 0);
        std::snprintf(buffer, sizeof(buffer), "%u (0x%X)", v, v);
        break;
    }
    case kInt64: {
        const int64_t v = memory.ReadOr<int64_t>(watch.address, 0);
        std::snprintf(buffer, sizeof(buffer), "%lld", static_cast<long long>(v));
        break;
    }
    case kFloat: {
        const float v = memory.ReadOr<float>(watch.address, 0.f);
        std::snprintf(buffer, sizeof(buffer), "%.4f", v);
        break;
    }
    case kDouble: {
        const double v = memory.ReadOr<double>(watch.address, 0.0);
        std::snprintf(buffer, sizeof(buffer), "%.4f", v);
        break;
    }
    case kPointer: {
        const uintptr_t v = memory.ReadPtr(watch.address);
        std::snprintf(buffer, sizeof(buffer), "0x%llX", static_cast<unsigned long long>(v));
        break;
    }
    case kString:
    default: {
        const std::string v = memory.ReadString(watch.address, 48);
        std::snprintf(buffer, sizeof(buffer), "\"%s\"", v.c_str());
        break;
    }
    }

    watch.changed = std::strcmp(buffer, watch.value) != 0;
    std::snprintf(watch.value, sizeof(watch.value), "%s", buffer);
}

void MemView::DrawWatches(const Memory& memory) {
    ImGui::TextDisabled("expressao: base+0x8EB6960  |  base+0x8EB6960>0x1F8  |  0x7FF6...");

    ImGui::SetNextItemWidth(260.f);
    ImGui::InputText("##expr", m_input, sizeof(m_input));
    ImGui::SameLine();

    ImGui::SetNextItemWidth(90.f);
    if (ImGui::BeginCombo("##type", TypeName(m_inputType))) {
        for (int type = kByte; type <= kString; ++type) {
            if (ImGui::Selectable(TypeName(type), type == m_inputType))
                m_inputType = type;
        }
        ImGui::EndCombo();
    }

    ImGui::SameLine();
    if (ImGui::Button("Adicionar")) {
        Watch watch{};
        watch.expr = Trim(m_input);
        watch.type = m_inputType;
        bool ok = false;
        watch.address = ResolveExpression(memory, watch.expr, ok);
        m_watches.push_back(std::move(watch));
        if (!m_dumpAddress)
            m_dumpAddress = m_watches.back().address;
    }

    if (m_watches.empty()) {
        ImGui::TextDisabled("nenhum watch manual — o painel automatico acima ja cobre o basico");
        return;
    }

    for (size_t i = 0; i < m_watches.size(); ++i) {
        Watch& watch = m_watches[i];
        ImGui::PushID(static_cast<int>(i));

        if (ImGui::SmallButton("x")) {
            m_watches.erase(m_watches.begin() + static_cast<long>(i));
            ImGui::PopID();
            break;
        }
        ImGui::SameLine();
        if (ImGui::SmallButton("dump")) {
            m_dumpAddress = watch.address;
            m_dumpPrevAddress = 0;
        }
        ImGui::SameLine();

        ImGui::TextColored(ImVec4(0.65f, 0.65f, 0.70f, 1.f), "0x%llX",
                           static_cast<unsigned long long>(watch.address));
        ImGui::SameLine(180.f);
        ImGui::TextDisabled("%-6s", TypeName(watch.type));
        ImGui::SameLine(240.f);
        ImGui::TextColored(watch.changed ? ImVec4(0.47f, 1.f, 0.55f, 1.f) : ImVec4(0.90f, 0.90f, 0.90f, 1.f),
                           "%s", watch.value);

        ImGui::PopID();
    }
}

void MemView::DrawDump() {
    ImGui::TextDisabled("dump 0x%llX", static_cast<unsigned long long>(m_dumpAddress));
    ImGui::SameLine();
    if (ImGui::SmallButton("16"))
        m_dumpRows = 16;
    ImGui::SameLine();
    if (ImGui::SmallButton("32"))
        m_dumpRows = 32;
    ImGui::SameLine();
    ImGui::TextDisabled("linhas");

    ImDrawList* draw = ImGui::GetWindowDrawList();
    const ImVec2 charSize = ImGui::CalcTextSize("0");
    const float advance = charSize.x;
    const float lineHeight = ImGui::GetTextLineHeight();

    ImGui::BeginChild("##dump", ImVec2(0.f, static_cast<float>(m_dumpRows) * lineHeight + 8.f), true,
                      ImGuiWindowFlags_HorizontalScrollbar);

    const ImVec2 origin = ImGui::GetCursorScreenPos();
    float y = origin.y;

    for (int row = 0; row < m_dumpRows; ++row) {
        char address[24]{};
        std::snprintf(address, sizeof(address), "%016llX",
                      static_cast<unsigned long long>(m_dumpAddress + static_cast<uintptr_t>(row) * 16));
        draw->AddText(ImVec2(origin.x, y), kAddressColor, address);

        float x = origin.x + advance * 18.f;
        for (int column = 0; column < 16; ++column) {
            const int index = row * 16 + column;
            const uint8_t value = m_dump[index];
            const bool changed = value != m_dumpPrev[index];

            char cell[4]{};
            std::snprintf(cell, sizeof(cell), "%02X", value);
            draw->AddText(ImVec2(x, y), changed ? kChangedColor : (value ? kByteColor : kZeroColor), cell);
            x += advance * 3.f;
        }

        float asciiX = x + advance * 2.f;
        for (int column = 0; column < 16; ++column) {
            const uint8_t value = m_dump[row * 16 + column];
            char cell[2]{};
            cell[0] = (value >= 32 && value < 127) ? static_cast<char>(value) : '.';
            draw->AddText(ImVec2(asciiX, y), kAsciiColor, cell);
            asciiX += advance;
        }

        y += lineHeight;
    }

    ImGui::Dummy(ImVec2(advance * 78.f, static_cast<float>(m_dumpRows) * lineHeight));
    ImGui::EndChild();
}

// ============================================================
void MemView::Tick(const Memory& memory) {
    const uint64_t now = GetTickCount64();
    if (now - m_lastTick < 16)   // ~60Hz
        return;
    m_lastTick = now;

    for (Watch& watch : m_watches) {
        bool ok = false;
        watch.address = ResolveExpression(memory, watch.expr, ok);
        ReadWatch(memory, watch);
    }

    std::memcpy(m_dumpPrev, m_dump, sizeof(m_dump));
    if (m_dumpAddress != m_dumpPrevAddress) {
        std::memset(m_dumpPrev, 0, sizeof(m_dumpPrev));
        m_dumpPrevAddress = m_dumpAddress;
    }
    std::memset(m_dump, 0, sizeof(m_dump));

    if (m_dumpAddress)
        memory.Read(m_dumpAddress, m_dump, 16u * static_cast<size_t>(m_dumpRows));
}

void MemView::Draw(const Memory& memory, const Esp& esp) {
    if (ImGui::BeginChild("##memscroll", ImVec2(0.f, 0.f), false)) {
        if (ImGui::CollapsingHeader("Ao vivo (automatico)", ImGuiTreeNodeFlags_DefaultOpen)) {
            DrawAuto(esp);
        }
        if (ImGui::CollapsingHeader("Varredura de valor")) {
            DrawScanner(memory);
        }
        if (ImGui::CollapsingHeader("Watches manuais")) {
            DrawWatches(memory);
        }
        if (m_dumpAddress && ImGui::CollapsingHeader("Hexdump", ImGuiTreeNodeFlags_DefaultOpen)) {
            DrawDump();
        }
    }
    ImGui::EndChild();
}
