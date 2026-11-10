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
static std::string JsonEscape(const std::string& in) {
    std::string out;
    out.reserve(in.size() + 8);
    for (char c : in) {
        if (c == '"' || c == '\\') {
            out.push_back('\\');
            out.push_back(c);
        } else if (c == '\n' || c == '\r') {
            out.push_back(' ');
        } else {
            out.push_back(c);
        }
    }
    return out;
}

static std::string ValueOf(const std::string& text, const char* key) {
    const std::string needle = std::string("\"") + key + "\":";
    size_t pos = text.find(needle);
    if (pos == std::string::npos)
        return {};

    pos += needle.size();
    while (pos < text.size() && (text[pos] == ' ' || text[pos] == '\t'))
        ++pos;

    // valor entre aspas pode conter virgula ("coin,cash"): le ate a aspe
    if (pos < text.size() && text[pos] == '"') {
        std::string value;
        ++pos;
        while (pos < text.size() && text[pos] != '"') {
            if (text[pos] == '\\' && pos + 1 < text.size())
                ++pos;
            value.push_back(text[pos]);
            ++pos;
        }
        return value;
    }

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

static std::string AsText(const std::string& value, const std::string& fallback) {
    return value.empty() ? fallback : value;
}

static const char* Bool(bool value) { return value ? "true" : "false"; }

// ------------------------------------------------------------
// config.json
// ------------------------------------------------------------
static bool SaveConfig(const Settings& s) {
    std::ofstream out(kConfigFile, std::ios::trunc);
    if (!out)
        return false;

    out << "{\n";
    out << "  \"espEnabled\": "  << Bool(s.espEnabled)  << ",\n";
    out << "  \"boxes\": "       << Bool(s.boxes)       << ",\n";
    out << "  \"names\": "       << Bool(s.names)       << ",\n";
    out << "  \"healthBar\": "   << Bool(s.healthBar)   << ",\n";
    out << "  \"distance\": "    << Bool(s.distance)    << ",\n";
    out << "  \"espSkeleton\": " << Bool(s.espSkeleton) << ",\n";
    out << "  \"espTracer\": "   << Bool(s.espTracer)   << ",\n";
    out << "  \"espHeadDot\": "  << Bool(s.espHeadDot)  << ",\n";
    out << "  \"teamCheck\": "   << Bool(s.teamCheck)   << ",\n";
    out << "  \"stealthOpen\": " << Bool(s.stealthOpen) << ",\n";
    out << "  \"handleWatch\": " << Bool(s.handleWatch) << ",\n";
    out << "  \"maxDistance\": " << s.maxDistance << ",\n";
    out << "  \"tickMs\": "      << s.tickMs << ",\n";
    out << "  \"espParts\": "       << Bool(s.espParts) << ",\n";
    out << "  \"partsFilter\": \"" << JsonEscape(s.partsFilter) << "\",\n";
    out << "  \"crosshair\": "      << Bool(s.crosshair) << ",\n";
    out << "  \"crosshairSize\": "  << s.crosshairSize << ",\n";

    const AimSettings& a = s.aim;
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
    out << "  \"aimLead\": "           << a.leadMs << ",\n";
    out << "  \"aimSnapPx\": "         << a.snapPx << ",\n";
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
    out << "  \"fireRequireForeground\": " << Bool(f.requireForeground) << ",\n";
    const FlySettings& v = s.fly;
    out << "  \"flyEnabled\": "        << Bool(v.enabled) << ",\n";
    out << "  \"flyKey\": "            << v.key << ",\n";
    out << "  \"flyToggle\": "         << Bool(v.toggleMode) << ",\n";
    out << "  \"flySpeed\": "          << v.speed << ",\n";
    out << "  \"flyMode\": "           << v.mode << ",\n";
    out << "  \"flyWriteHz\": "        << v.writeHz << ",\n";
    out << "  \"flyMaxStep\": "        << v.maxStepStuds << ",\n";
    out << "  \"flyZeroVelocity\": "   << Bool(v.zeroVelocity) << ",\n";
    out << "  \"flyHoverOnIdle\": "    << Bool(v.hoverOnIdle) << ",\n";
    out << "  \"flyRequireForeground\": " << Bool(v.requireForeground) << ",\n";
    out << "  \"flyAnchor\": "        << Bool(v.anchor) << ",\n";
    out << "  \"aimCamera\": "        << Bool(a.cameraMode) << ",\n";

    const CameraSettings& c = s.camera;
    out << "  \"camFreecam\": "      << Bool(c.freecam) << ",\n";
    out << "  \"camKey\": "          << c.freecamKey << ",\n";
    out << "  \"camSpeed\": "        << c.freecamSpeed << ",\n";
    out << "  \"camFovHack\": "      << Bool(c.fovHack) << ",\n";
    out << "  \"camFov\": "          << c.fov << ",\n";
    out << "  \"camUnlockFps\": "    << Bool(c.unlockFps) << ",\n";
    out << "  \"camMaxFps\": "       << c.maxFps << ",\n";

    const MagnetSettings& mag = s.magnet;
    out << "  \"magEnabled\": "      << Bool(mag.enabled) << ",\n";
    out << "  \"magRange\": "        << mag.range << ",\n";
    out << "  \"magPull\": "         << mag.pullDistance << ",\n";
    out << "  \"magPerSecond\": "    << mag.perSecond << "\n";
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
    s.espSkeleton = AsBool(ValueOf(text, "espSkeleton"), s.espSkeleton);
    s.espTracer   = AsBool(ValueOf(text, "espTracer"),   s.espTracer);
    s.espHeadDot  = AsBool(ValueOf(text, "espHeadDot"),  s.espHeadDot);
    s.teamCheck   = AsBool(ValueOf(text, "teamCheck"),   s.teamCheck);
    s.stealthOpen = AsBool(ValueOf(text, "stealthOpen"), s.stealthOpen);
    s.handleWatch = AsBool(ValueOf(text, "handleWatch"), s.handleWatch);

    s.maxDistance = AsFloat(ValueOf(text, "maxDistance"), s.maxDistance);
    s.tickMs      = AsInt(ValueOf(text, "tickMs"), s.tickMs);

    s.espParts      = AsBool(ValueOf(text, "espParts"), s.espParts);
    s.partsFilter   = AsText(ValueOf(text, "partsFilter"), s.partsFilter);
    s.crosshair     = AsBool(ValueOf(text, "crosshair"), s.crosshair);
    s.crosshairSize = AsFloat(ValueOf(text, "crosshairSize"), s.crosshairSize);

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
    a.leadMs      = AsFloat(ValueOf(text, "aimLead"), a.leadMs);
    a.snapPx      = AsFloat(ValueOf(text, "aimSnapPx"), a.snapPx);
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

    FlySettings& v = s.fly;
    v.enabled     = AsBool(ValueOf(text, "flyEnabled"), v.enabled);
    v.key         = AsInt(ValueOf(text, "flyKey"), v.key);
    v.toggleMode  = AsBool(ValueOf(text, "flyToggle"), v.toggleMode);
    v.speed       = AsFloat(ValueOf(text, "flySpeed"), v.speed);
    v.mode        = AsInt(ValueOf(text, "flyMode"), v.mode);
    v.writeHz     = AsInt(ValueOf(text, "flyWriteHz"), v.writeHz);
    v.maxStepStuds = AsFloat(ValueOf(text, "flyMaxStep"), v.maxStepStuds);
    v.zeroVelocity = AsBool(ValueOf(text, "flyZeroVelocity"), v.zeroVelocity);
    v.hoverOnIdle = AsBool(ValueOf(text, "flyHoverOnIdle"), v.hoverOnIdle);
    v.requireForeground = AsBool(ValueOf(text, "flyRequireForeground"), v.requireForeground);
    v.anchor      = AsBool(ValueOf(text, "flyAnchor"), v.anchor);
    a.cameraMode  = AsBool(ValueOf(text, "aimCamera"), a.cameraMode);

    CameraSettings& c = s.camera;
    c.freecam     = AsBool(ValueOf(text, "camFreecam"), c.freecam);
    c.freecamKey  = AsInt(ValueOf(text, "camKey"), c.freecamKey);
    c.freecamSpeed = AsFloat(ValueOf(text, "camSpeed"), c.freecamSpeed);
    c.fovHack     = AsBool(ValueOf(text, "camFovHack"), c.fovHack);
    c.fov         = AsFloat(ValueOf(text, "camFov"), c.fov);
    c.unlockFps   = AsBool(ValueOf(text, "camUnlockFps"), c.unlockFps);
    c.maxFps      = AsInt(ValueOf(text, "camMaxFps"), c.maxFps);

    MagnetSettings& mag = s.magnet;
    mag.enabled     = AsBool(ValueOf(text, "magEnabled"), mag.enabled);
    mag.range       = AsFloat(ValueOf(text, "magRange"), mag.range);
    mag.pullDistance = AsFloat(ValueOf(text, "magPull"), mag.pullDistance);
    mag.perSecond   = AsInt(ValueOf(text, "magPerSecond"), mag.perSecond);

    if (v.speed < 5.f)   v.speed = 5.f;
    if (v.speed > 500.f) v.speed = 500.f;

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

bool Same(const Settings& a, const Settings& b) {
    const bool scalars =
        a.espEnabled == b.espEnabled && a.boxes == b.boxes && a.names == b.names &&
        a.healthBar == b.healthBar && a.distance == b.distance &&
        a.espSkeleton == b.espSkeleton && a.espTracer == b.espTracer &&
        a.espHeadDot == b.espHeadDot && a.espParts == b.espParts &&
        a.partsFilter == b.partsFilter && a.crosshair == b.crosshair &&
        a.crosshairSize == b.crosshairSize && a.teamCheck == b.teamCheck &&
        a.stealthOpen == b.stealthOpen && a.handleWatch == b.handleWatch &&
        a.maxDistance == b.maxDistance && a.tickMs == b.tickMs;
    if (!scalars)
        return false;

    const AimSettings& x = a.aim;
    const AimSettings& y = b.aim;
    if (x.enabled != y.enabled || x.key != y.key || x.toggleMode != y.toggleMode ||
        x.bone != y.bone || x.fovPx != y.fovPx || x.smoothing != y.smoothing ||
        x.strength != y.strength || x.maxStepPx != y.maxStepPx || x.deadzonePx != y.deadzonePx ||
        x.jitterPx != y.jitterPx || x.leadMs != y.leadMs || x.snapPx != y.snapPx ||
        x.cameraMode != y.cameraMode ||
        x.drawFov != y.drawFov || x.requireForeground != y.requireForeground)
        return false;

    const TriggerSettings& f = a.fire;
    const TriggerSettings& g = b.fire;
    if (f.enabled != g.enabled || f.key != g.key || f.autoFire != g.autoFire ||
        f.maxErrorPx != g.maxErrorPx || f.minIntervalMs != g.minIntervalMs ||
        f.holdMs != g.holdMs || f.burst != g.burst || f.requireForeground != g.requireForeground)
        return false;

    const FlySettings& v = a.fly;
    const FlySettings& w = b.fly;
    if (v.enabled != w.enabled || v.toggleMode != w.toggleMode || v.key != w.key ||
        v.speed != w.speed || v.zeroVelocity != w.zeroVelocity ||
        v.mode != w.mode || v.writeHz != w.writeHz || v.maxStepStuds != w.maxStepStuds ||
        v.hoverOnIdle != w.hoverOnIdle || v.requireForeground != w.requireForeground ||
        v.anchor != w.anchor)
        return false;

    const CameraSettings& c = a.camera;
    const CameraSettings& d = b.camera;
    if (c.freecam != d.freecam || c.freecamKey != d.freecamKey || c.freecamSpeed != d.freecamSpeed ||
        c.fovHack != d.fovHack || c.fov != d.fov || c.unlockFps != d.unlockFps || c.maxFps != d.maxFps)
        return false;

    const MagnetSettings& mg = a.magnet;
    const MagnetSettings& mh = b.magnet;
    if (mg.enabled != mh.enabled || mg.range != mh.range || mg.pullDistance != mh.pullDistance ||
        mg.perSecond != mh.perSecond)
        return false;

    if (a.profiles.size() != b.profiles.size())
        return false;

    for (size_t i = 0; i < a.profiles.size(); ++i) {
        const Profile& p = a.profiles[i];
        const Profile& q = b.profiles[i];
        if (p.placeId != q.placeId || p.fovPx != q.fovPx || p.smoothing != q.smoothing ||
            p.strength != q.strength || p.bone != q.bone)
            return false;
    }

    return true;
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
