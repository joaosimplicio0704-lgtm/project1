#include "Config.h"

#include <fstream>
#include <regex>
#include <sstream>

namespace {
    template <typename T>
    void ReadNumber(const std::string& json, const char* key, T& output) {
        const std::regex pattern(std::string("\\\"") + key + "\\\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)");
        std::smatch match;
        if (!std::regex_search(json, match, pattern)) return;
        std::istringstream stream(match[1].str());
        double value = 0.0;
        if (stream >> value) output = static_cast<T>(value);
    }

    void ReadBool(const std::string& json, const char* key, bool& output) {
        const std::regex pattern(std::string("\\\"") + key + "\\\"\\s*:\\s*(true|false)");
        std::smatch match;
        if (std::regex_search(json, match, pattern)) output = match[1].str() == "true";
    }

    void WriteBool(std::ostringstream& output, const char* key, bool value, bool last = false) {
        output << "  \"" << key << "\": " << (value ? "true" : "false") << (last ? "" : ",") << '\n';
    }

    template <typename T>
    void WriteNumber(std::ostringstream& output, const char* key, T value, bool last = false) {
        output << "  \"" << key << "\": " << value << (last ? "" : ",") << '\n';
    }
}

std::string ConfigPath() {
    return "fortnite-config.json";
}

bool SaveConfig(const Config& config, std::string& message) {
    std::ofstream file(ConfigPath(), std::ios::trunc);
    if (!file) {
        message = "failed to open " + ConfigPath() + " for writing";
        return false;
    }

    std::ostringstream output;
    output << "{\n";
    WriteBool(output, "aimEnabled", config.aimEnabled);
    WriteBool(output, "espEnabled", config.espEnabled);
    WriteBool(output, "teamCheck", config.teamCheck);
    WriteBool(output, "visibleOnly", config.visibleOnly);
    WriteBool(output, "includeBots", config.includeBots);
    WriteBool(output, "drawBoxes", config.drawBoxes);
    WriteBool(output, "drawNames", config.drawNames);
    WriteBool(output, "drawHealth", config.drawHealth);
    WriteBool(output, "drawDistance", config.drawDistance);
    WriteBool(output, "snaplines", config.snaplines);
    WriteNumber(output, "fovPx", config.fovPx);
    WriteNumber(output, "smoothing", config.smoothing);
    WriteNumber(output, "pixelsPerDegree", config.pixelsPerDegree);
    WriteNumber(output, "maxDistanceM", config.maxDistanceM);
    WriteNumber(output, "headBone", config.headBone, true);
    output << "}\n";
    file << output.str();
    if (!file) {
        message = "failed while writing " + ConfigPath();
        return false;
    }
    message = "saved " + ConfigPath();
    return true;
}

bool LoadConfig(Config& config, std::string& message) {
    std::ifstream file(ConfigPath());
    if (!file) {
        message = "failed to open " + ConfigPath();
        return false;
    }
    const std::string json((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

    ReadBool(json, "aimEnabled", config.aimEnabled);
    ReadBool(json, "espEnabled", config.espEnabled);
    ReadBool(json, "teamCheck", config.teamCheck);
    ReadBool(json, "visibleOnly", config.visibleOnly);
    ReadBool(json, "includeBots", config.includeBots);
    ReadBool(json, "drawBoxes", config.drawBoxes);
    ReadBool(json, "drawNames", config.drawNames);
    ReadBool(json, "drawHealth", config.drawHealth);
    ReadBool(json, "drawDistance", config.drawDistance);
    ReadBool(json, "snaplines", config.snaplines);
    ReadNumber(json, "fovPx", config.fovPx);
    ReadNumber(json, "smoothing", config.smoothing);
    ReadNumber(json, "pixelsPerDegree", config.pixelsPerDegree);
    ReadNumber(json, "maxDistanceM", config.maxDistanceM);
    ReadNumber(json, "headBone", config.headBone);

    config.fovPx = config.fovPx < 10.0f ? 10.0f : (config.fovPx > 800.0f ? 800.0f : config.fovPx);
    config.smoothing = config.smoothing < 1.0f ? 1.0f : (config.smoothing > 50.0f ? 50.0f : config.smoothing);
    config.pixelsPerDegree = config.pixelsPerDegree < 0.01f ? 0.01f : config.pixelsPerDegree;
    config.maxDistanceM = config.maxDistanceM < 1.0f ? 1.0f : config.maxDistanceM;
    if (config.headBone < 0) config.headBone = 0;

    message = "loaded " + ConfigPath();
    return true;
}
