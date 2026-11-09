#include "config.h"

#include <cstdlib>
#include <fstream>
#include <string>

namespace cfg {

static const char* kConfigFile = "config.json";
static const char* kProfilesFile = "profiles.json";

// ------------------------------------------------------------
// parser minimo: um objeto chato por arquivo, chave: valor
// (sem dependencia externa de proposito)
// ------------------------------------------------------------
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

static float AsFloat(const std::string& value, float fallback) {
    if (value.empty())
        return fallback;
    return static_cast<float>(std::atof(value.c_str()));
}

static int AsInt(const std::string& value, int fallback) {
    if (value.empty())
        return fallback;
    return std::atoi(value.c_str());
}

static uint64_t AsU64(const std::string& value, uint64_t fallback) {
    if (value.empty())
        return fallback;
    return static_cast<uint64_t>(std::strtoull(value.c_str(), nullptr, 10));
}

static const char* Bool(bool value) { return value ? "true" : "false"; }

// ------------------------------------------------------------
// config.json
// ------------------------------------------------------------
static bool SaveConfig(const Settings& s) {
    std::ofstream out(kConfigFile, std::ios::trunc);
    if (!out)
        return false;

    const AimSettings& a = s.aim;

    out << "{\n";
    out << "  \"espEnabled\": "  << Bool(s.espEnabled)  << ",\n";
    out << "  \"boxes\": "       << Bool(s.boxes)       << ",\n";
    out << "  \"names\": "       << Bool(s.names)       << ",\n";
    out << "  \"healthBar\": "   << Bool(s.healthBar)   << ",\n";
    out << "  \"distance\": "    << Bool(s.distance)    << ",\n";
    out << "  \"teamCheck\": "   << Bool(s.teamCheck)   << ",\n";
    out << "  \"stealthOpen\": " << Bool(s.stealthOpen) << ",\n";
    out << "  \"handleWatch\": " << Bool(s.handleWatch) << ",\n";
    out << "  \"maxDistance\": " << s.maxDistance << ",\n";
    out << "  \"tickMs\": "      << s.tickMs << ",\n";
    out << "  \"aimEnabled\": "        << Bool(a.enabled) << ",\n";
    out << "  \"aimKey\": "            << a.key << ",\n";
    out << "  \"aimToggle\": "         << Bool(a.toggleMode) << ",\n";
    out << "  \"aimBone\": "           << a.bone << ",\n";
    out << "  \"aimFov\": "            << a.fovPx << ",\n";
    out << "  \"aimSmoothing\": "      << a.smoothing << ",\n";
    out << "  \"aimStrength\": "       << a.strength << ",\n";
    out << "  \"aimMaxStep\": "        << a.maxStepPx << ",\n";
    out << "  \"aimDeadzone\": "       << a.deadzonePx << ",\n";
    out << "  \"aimJitter\": "         << a.jitterPx << ",\n";
    out << "  \"aimDrawFov\": "        << Bool(a.drawFov) << ",\n";
    out << "  \"aimRequireForeground\": " << Bool(a.requireForeground) << ",\n";
    const TriggerSettings& f = s.fire;
    out << "  \"fireEnabled\": "        << Bool(f.enabled) << ",\n";
    out << "  \"fireKey\": "            << f.key << ",\n";
    out << "  \"fireAuto\": "           << Bool(f.autoFire) << ",\n";
    out << "  \"fireMaxError\": "       << f.maxErrorPx << ",\n";
    out << "  \"fireInterval\": "       << f.minIntervalMs << ",\n";
    out << "  \"fireHold\": "           << f.holdMs << ",\n";
    out << "  \"fireBurst\": "          << f.burst << ",\n";
    out << "  \"fireRequireForeground\": " << Bool(f.requireForeground) << "\n";
    out << "}\n";

    return out.good();
}

static bool LoadConfig(Settings& s) {
    std::ifstream in(kConfigFile);
    if (!in)
        return false;

    const std::string text((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
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

    s.maxDistance = AsFloat(ValueOf(text, "maxDistance"), s.maxDistance);
    s.tickMs      = AsInt(ValueOf(text, "tickMs"), s.tickMs);

    AimSettings& a = s.aim;
    a.enabled     = AsBool(ValueOf(text, "aimEnabled"), a.enabled);
    a.key         = AsInt(ValueOf(text, "aimKey"), a.key);
    a.toggleMode  = AsBool(ValueOf(text, "aimToggle"), a.toggleMode);
    a.bone        = AsInt(ValueOf(text, "aimBone"), a.bone);
    a.fovPx       = AsFloat(ValueOf(text, "aimFov"), a.fovPx);
    a.smoothing   = AsFloat(ValueOf(text, "aimSmoothing"), a.smoothing);
    a.strength    = AsFloat(ValueOf(text, "aimStrength"), a.strength);
    a.maxStepPx   = AsFloat(ValueOf(text, "aimMaxStep"), a.maxStepPx);
    a.deadzonePx  = AsFloat(ValueOf(text, "aimDeadzone"), a.deadzonePx);
    a.jitterPx    = AsFloat(ValueOf(text, "aimJitter"), a.jitterPx);
    a.drawFov     = AsBool(ValueOf(text, "aimDrawFov"), a.drawFov);
    a.requireForeground = AsBool(ValueOf(text, "aimRequireForeground"), a.requireForeground);

    TriggerSettings& f = s.fire;
    f.enabled     = AsBool(ValueOf(text, "fireEnabled"), f.enabled);
    f.key         = AsInt(ValueOf(text, "fireKey"), f.key);
    f.autoFire    = AsBool(ValueOf(text, "fireAuto"), f.autoFire);
    f.maxErrorPx  = AsFloat(ValueOf(text, "fireMaxError"), f.maxErrorPx);
    f.minIntervalMs = AsInt(ValueOf(text, "fireInterval"), f.minIntervalMs);
    f.holdMs      = AsInt(ValueOf(text, "fireHold"), f.holdMs);
    f.burst       = AsInt(ValueOf(text, "fireBurst"), f.burst);
    f.requireForeground = AsBool(ValueOf(text, "fireRequireForeground"), f.requireForeground);

    if (f.minIntervalMs < 16) f.minIntervalMs = 16;
    if (f.holdMs < 1)  f.holdMs = 1;
    if (f.burst < 1)   f.burst = 1;

    if (s.tickMs < 1)   s.tickMs = 1;
    if (s.tickMs > 250) s.tickMs = 250;
    if (s.maxDistance < 50.f) s.maxDistance = 50.f;
    if (a.smoothing < 1.f) a.smoothing = 1.f;
    if (a.strength <= 0.f || a.strength > 1.f) a.strength = 0.55f;
    if (a.bone < kHead || a.bone > kRoot) a.bone = kHead;

    return true;
}

// ------------------------------------------------------------
// profiles.json — um objeto por linha, chaveado por PlaceId
// ------------------------------------------------------------
static bool SaveProfiles(const std::vector<Profile>& profiles) {
    std::ofstream out(kProfilesFile, std::ios::trunc);
    if (!out)
        return false;

    out << "{\n  \"profiles\": [\n";
    for (size_t i = 0; i < profiles.size(); ++i) {
        const Profile& p = profiles[i];
        out << "    { \"placeId\": " << p.placeId
            << ", \"fov\": " << p.fovPx
            << ", \"smoothing\": " << p.smoothing
            << ", \"strength\": " << p.strength
            << ", \"bone\": " << p.bone << " }";
        out << (i + 1 < profiles.size() ? ",\n" : "\n");
    }
    out << "  ]\n}\n";
    return out.good();
}

static bool LoadProfiles(std::vector<Profile>& profiles) {
    std::ifstream in(kProfilesFile);
    if (!in)
        return false;

    const std::string text((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    profiles.clear();

    size_t pos = 0;
    while ((pos = text.find("\"placeId\"", pos)) != std::string::npos) {
        const size_t open = text.rfind('{', pos);
        const size_t close = text.find('}', pos);
        if (open == std::string::npos || close == std::string::npos)
            break;

        const std::string block = text.substr(open, close - open + 1);

        Profile p{};
        p.placeId   = AsU64(ValueOf(block, "placeId"), 0);
        p.fovPx     = AsFloat(ValueOf(block, "fov"), 160.f);
        p.smoothing = AsFloat(ValueOf(block, "smoothing"), 6.f);
        p.strength  = AsFloat(ValueOf(block, "strength"), 0.55f);
        p.bone      = AsInt(ValueOf(block, "bone"), kHead);

        if (p.placeId)
            profiles.push_back(p);

        pos = close + 1;
    }

    return !profiles.empty();
}

// ------------------------------------------------------------
bool Save(const Settings& settings) {
    const bool config = SaveConfig(settings);
    SaveProfiles(settings.profiles);
    return config;
}

bool Load(Settings& settings) {
    const bool config = LoadConfig(settings);
    LoadProfiles(settings.profiles);
    return config;
}

const Profile* FindProfile(const Settings& settings, uint64_t placeId) {
    if (!placeId)
        return nullptr;
    for (const Profile& p : settings.profiles) {
        if (p.placeId == placeId)
            return &p;
    }
    return nullptr;
}

void UpsertProfile(Settings& settings, const Profile& profile) {
    for (Profile& p : settings.profiles) {
        if (p.placeId == profile.placeId) {
            p = profile;
            return;
        }
    }
    settings.profiles.push_back(profile);
}

void ApplyProfile(Settings& settings, const Profile& profile) {
    settings.aim.fovPx = profile.fovPx;
    settings.aim.smoothing = profile.smoothing;
    settings.aim.strength = profile.strength;
    settings.aim.bone = profile.bone;
}

} // namespace cfg
