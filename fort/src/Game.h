#pragma once

#include "Config.h"
#include "ProcessHandle.h"
#include "Types.h"

#include <array>
#include <cstdint>
#include <string>
#include <vector>

struct BonePoint {
    std::string Name;
    fn::FVector World;
    fn::ScreenPoint Screen;
    bool Projected = false;
};

struct PlayerSnapshot {
    std::uintptr_t Pawn = 0;
    std::string Name;
    std::uint8_t Team = 0;
    bool IsBot = false;
    bool RecentlyRendered = false;
    bool HasBoneData = false;
    bool Dead = false;
    float Health = 0.0f;
    float MaxHealth = 100.0f;
    float Shield = 0.0f;
    float DistanceM = 0.0f;
    fn::FVector Root;
    fn::FVector Head;
    fn::FVector AimPoint;
    fn::ScreenPoint HeadScreen;
    fn::ScreenPoint AimScreen;
    fn::ScreenPoint FeetScreen;
    bool HeadProjected = false;
    bool AimProjected = false;
    bool FeetProjected = false;
    std::vector<BonePoint> Bones;
};

struct WorldSnapshot {
    bool Valid = false;
    bool CameraFallback = false;
    std::uintptr_t LocalPawn = 0;
    std::uintptr_t LocalPlayerState = 0;
    std::uint8_t LocalTeam = 0;
    std::int32_t PlayerStateCount = 0;
    std::int32_t CandidateCount = 0;
    std::int32_t BoneFallbackCount = 0;
    fn::FVector CameraLocation;
    fn::FRotator CameraRotation;
    float CameraFov = 90.0f;
    std::vector<PlayerSnapshot> Players;
};

class Game {
public:
    Game() = default;

    [[nodiscard]] bool RefreshProcess();
    [[nodiscard]] bool Ready() const noexcept;
    [[nodiscard]] DWORD Pid() const noexcept { return pid_; }
    [[nodiscard]] const std::string& Status() const noexcept { return status_; }
    [[nodiscard]] WorldSnapshot Capture(const Config& config, int screenWidth, int screenHeight);

private:
    template <typename T>
    [[nodiscard]] T Read(std::uintptr_t address) const {
        T value{};
        if (!handle_.read(address, &value, sizeof(value))) return T{};
        return value;
    }

    [[nodiscard]] bool ReadInto(std::uintptr_t address, void* output, std::size_t size) const;
    [[nodiscard]] std::string ReadPlayerName(std::uintptr_t playerState) const;
    [[nodiscard]] float ReadAttribute(std::uintptr_t healthSet, std::uint64_t attribute) const;

    DWORD pid_ = 0;
    std::uintptr_t moduleBase_ = 0;
    ss::ProcessHandle handle_;
    std::string status_ = "waiting for FortniteClient-Win64-Shipping.exe";
};
