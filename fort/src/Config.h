#pragma once

#include <string>

struct Config {
    int version = 2;
    bool aimEnabled = false;
    bool espEnabled = false;
    bool teamCheck = true;
    bool visibleOnly = false;
    bool includeBots = true;
    bool drawBoxes = true;
    bool cornerBoxes = true;
    bool drawSkeleton = true;
    bool drawNames = true;
    bool drawHealth = true;
    bool drawDistance = true;
    bool snaplines = false;
    float fovPx = 180.0f;
    float smoothing = 4.0f;
    float pixelsPerDegree = 1.25f;
    float maxDistanceM = 500.0f;
    int headBone = 110;
    int aimPart = 0; // 0 head, 1 neck, 2 chest, 3 pelvis
};

[[nodiscard]] bool SaveConfig(const Config& config, std::string& message);
[[nodiscard]] bool LoadConfig(Config& config, std::string& message);
[[nodiscard]] std::string ConfigPath();
