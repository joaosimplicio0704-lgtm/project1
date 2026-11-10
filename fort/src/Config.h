#pragma once

#include <string>

struct Config {
    bool aimEnabled = false;
    bool espEnabled = false;
    bool teamCheck = true;
    bool visibleOnly = true;
    bool includeBots = true;
    bool drawBoxes = true;
    bool drawNames = true;
    bool drawHealth = true;
    bool drawDistance = true;
    bool snaplines = false;
    float fovPx = 180.0f;
    float smoothing = 4.0f;
    float pixelsPerDegree = 1.25f;
    float maxDistanceM = 250.0f;
    int headBone = 110;
};

[[nodiscard]] bool SaveConfig(const Config& config, std::string& message);
[[nodiscard]] bool LoadConfig(Config& config, std::string& message);
[[nodiscard]] std::string ConfigPath();
