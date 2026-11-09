#include "memview.h"

#include <cstdio>
#include <cstring>

#include "../imgui/imgui.h"

namespace {

constexpr ImU32 kAddressColor = IM_COL32(150, 150, 160, 255);
constexpr ImU32 kByteColor = IM_COL32(220, 220, 220, 255);
constexpr ImU32 kZeroColor = IM_COL32(110, 110, 120, 255);
constexpr ImU32 kChangedColor = IM_COL32(120, 255, 140, 255);
constexpr ImU32 kAsciiColor = IM_COL32(170, 190, 170, 255);

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
    size_t begin = text.find_first_not_of(" \t");
    if (begin == std::string::npos)
        return {};
    size_t end = text.find_last_not_of(" \t");
    return text.substr(begin, end - begin + 1);
}

// resolve "base+off>off>off"
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

        // offset depois de '+'
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
                current = offset; // "+0x1234" = absoluto
            } else {
                if (!ParseNumber(basePart, current))
                    return 0;
                current += offset;
            }
            first = false;
        } else {
            if (!fromBase && !basePart.empty()) {
                // ">0x1F8" ou ">base+0x..." — base no meio nao faz sentido, mas aceita o offset
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

} // namespace

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

void MemView::Tick(const Memory& memory) {
    const uint64_t now = GetTickCount64();
    if (now - m_lastTick < 16)          // ~60Hz de leitura
        return;
    m_lastTick = now;

    for (Watch& watch : m_watches) {
        bool ok = false;
        watch.address = ResolveExpression(memory, watch.expr, ok);
        ReadWatch(memory, watch);
    }

    // dump
    std::memcpy(m_dumpPrev, m_dump, sizeof(m_dump));
    if (m_dumpAddress != m_dumpPrevAddress) {
        std::memset(m_dumpPrev, 0, sizeof(m_dumpPrev));
        m_dumpPrevAddress = m_dumpAddress;
    }
    std::memset(m_dump, 0, sizeof(m_dump));

    if (m_dumpAddress) {
        if (!memory.Read(m_dumpAddress, m_dump, sizeof(m_dump)))
            std::memset(m_dump, 0, sizeof(m_dump));
    }
}

void MemView::DrawDump(const Memory& memory) {
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
        std::snprintf(address, sizeof(address), "%016llX", static_cast<unsigned long long>(m_dumpAddress + row * 16));
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
    (void)memory;
}

void MemView::Draw(const Memory& memory) {
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

    ImGui::Separator();

    if (m_watches.empty())
        ImGui::TextDisabled("nenhum watch. cola um offset e clica em Adicionar.");

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

    ImGui::Separator();
    if (m_dumpAddress)
        DrawDump(memory);
}
