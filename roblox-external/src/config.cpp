#include "config.h"

#include <cctype>
#include <cstdlib>
#include <fstream>
#include <string>

namespace cfg {

static const char* kFile = "config.json";

// parser minimo de um objeto chato: {"key": value, ...}
// sem dependencia externa de proposito.
static std::string ValueOf(const std::string& text, const char* key) {
    const std::string needle = std::string("\"") + key + "\":";
    size_t pos = text.find(needle);
    if (pos == std::string::npos)
        return {};

    pos += needle.size();
    while (pos < text.size() && (text[pos] == ' ' || text[pos] == '\t'))
        ++pos;

    size_t end = pos;
    while (end < text.size() && text[end] != ',' && text[end] != '}' && text[end] != '\n')
        ++end;

    std::string value = text.substr(pos, end - pos);
    while (!value.empty() && (value.back() == ' ' || value.back() == '\r' || value.back() == '\t'))
        value.pop_back();
    return value;
}

static bool AsBool(const std::string& value, bool fallback) {
    if (value == "true")  return true;
    if (value == "false") return false;
    return fallback;
}

bool Save(const Settings& s) {
    std::ofstream out(kFile, std::ios::trunc);
    if (!out)
        return false;

    out << "{\n";
    out << "  \"espEnabled\": "  << (s.espEnabled  ? "true" : "false") << ",\n";
    out << "  \"boxes\": "       << (s.boxes       ? "true" : "false") << ",\n";
    out << "  \"names\": "       << (s.names       ? "true" : "false") << ",\n";
    out << "  \"healthBar\": "   << (s.healthBar   ? "true" : "false") << ",\n";
    out << "  \"distance\": "    << (s.distance    ? "true" : "false") << ",\n";
    out << "  \"teamCheck\": "   << (s.teamCheck   ? "true" : "false") << ",\n";
    out << "  \"stealthOpen\": " << (s.stealthOpen ? "true" : "false") << ",\n";
    out << "  \"handleWatch\": " << (s.handleWatch ? "true" : "false") << ",\n";
    out << "  \"maxDistance\": " << s.maxDistance << ",\n";
    out << "  \"tickMs\": "      << s.tickMs << "\n";
    out << "}\n";

    return out.good();
}

bool Load(Settings& s) {
    std::ifstream in(kFile);
    if (!in)
        return false;

    std::string text((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    if (text.empty())
        return false;

    s.espEnabled  = AsBool(ValueOf(text, "espEnabled"),  s.espEnabled);
    s.boxes       = AsBool(ValueOf(text, "boxes"),       s.boxes);
    s.names       = AsBool(ValueOf(text, "names"),       s.names);
    s.healthBar   = AsBool(ValueOf(text, "healthBar"),   s.healthBar);
    s.distance    = AsBool(ValueOf(text, "distance"),    s.distance);
    s.teamCheck   = AsBool(ValueOf(text, "teamCheck"),   s.teamCheck);
    s.stealthOpen = AsBool(ValueOf(text, "stealthOpen"), s.stealthOpen);
    s.handleWatch = AsBool(ValueOf(text, "handleWatch"), s.handleWatch);

    const std::string maxDistance = ValueOf(text, "maxDistance");
    if (!maxDistance.empty())
        s.maxDistance = static_cast<float>(std::atof(maxDistance.c_str()));

    const std::string tick = ValueOf(text, "tickMs");
    if (!tick.empty())
        s.tickMs = std::atoi(tick.c_str());

    if (s.tickMs < 1)   s.tickMs = 1;
    if (s.tickMs > 250) s.tickMs = 250;
    if (s.maxDistance < 50.f) s.maxDistance = 50.f;

    return true;
}

} // namespace cfg
