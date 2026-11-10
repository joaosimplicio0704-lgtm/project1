#include "Game.h"

#include "Offsets.h"

#include <windows.h>
#include <tlhelp32.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

namespace {
    constexpr wchar_t kProcessName[] = L"FortniteClient-Win64-Shipping.exe";
    constexpr std::int32_t kMaxPlayers = 512;
    constexpr std::int32_t kMaxBones = 512;

    struct NamedBone {
        const char* Name;
        std::int32_t Index;
    };

    // Bone names and indices must match the skeleton used by the dumped build.
    // FILL: export USkeletalMesh::RefSkeleton.GetBoneName(index) if the mesh changed.
    constexpr NamedBone kBodyBones[] = {
        { "pelvis", 5 },
        { "spine_01", 6 },
        { "spine_02", 7 },
        { "spine_03", 8 },
        { "spine_04", 9 },
        { "spine_05", 10 },
        { "neck_01", 66 },
        { "neck_02", 67 },
        { "head", 110 },
        { "clavicle_l", 11 },
        { "upperarm_l", 12 },
        { "lowerarm_l", 13 },
        { "hand_l", 14 },
        { "clavicle_r", 38 },
        { "upperarm_r", 39 },
        { "lowerarm_r", 40 },
        { "hand_r", 41 },
        { "thigh_l", 69 },
        { "lowerleg_l", 70 },
        { "foot_l", 71 },
        { "thigh_r", 76 },
        { "lowerleg_r", 77 },
        { "foot_r", 78 }
    };

    DWORD FindFortniteProcess() {
        const HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snapshot == INVALID_HANDLE_VALUE) return 0;

        PROCESSENTRY32W entry{};
        entry.dwSize = sizeof(entry);
        DWORD result = 0;
        if (::Process32FirstW(snapshot, &entry)) {
            do {
                if (::lstrcmpiW(entry.szExeFile, kProcessName) == 0) {
                    result = entry.th32ProcessID;
                    break;
                }
            } while (::Process32NextW(snapshot, &entry));
        }
        ::CloseHandle(snapshot);
        return result;
    }

    std::uintptr_t FindModuleBase(DWORD pid) {
        const HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid);
        if (snapshot == INVALID_HANDLE_VALUE) return 0;

        MODULEENTRY32W entry{};
        entry.dwSize = sizeof(entry);
        std::uintptr_t result = 0;
        if (::Module32FirstW(snapshot, &entry)) {
            do {
                if (::lstrcmpiW(entry.szModule, kProcessName) == 0) {
                    result = reinterpret_cast<std::uintptr_t>(entry.modBaseAddr);
                    break;
                }
            } while (::Module32NextW(snapshot, &entry));
        }
        ::CloseHandle(snapshot);
        return result;
    }
}

bool Game::RefreshProcess() {
    if (handle_.valid()) {
        if (::WaitForSingleObject(handle_.get(), 0) != WAIT_OBJECT_0) return true;
        handle_.reset();
        pid_ = 0;
        moduleBase_ = 0;
    }

    pid_ = FindFortniteProcess();
    if (pid_ == 0) {
        status_ = "waiting for FortniteClient-Win64-Shipping.exe";
        return false;
    }

    handle_ = ss::OpenReadOnly(pid_);
    if (!handle_.valid()) {
        status_ = "OpenProcess failed (error " + std::to_string(handle_.lastError()) + "); run as administrator";
        return false;
    }

    moduleBase_ = FindModuleBase(pid_);
    if (!fn::IsValidAddress(moduleBase_)) {
        status_ = "failed to locate the Fortnite module base";
        handle_.reset();
        return false;
    }

    status_ = "attached read-only";
    return true;
}

bool Game::Ready() const noexcept {
    return handle_.valid() && fn::IsValidAddress(moduleBase_);
}

bool Game::ReadInto(std::uintptr_t address, void* output, std::size_t size) const {
    return fn::IsValidAddress(address) && handle_.read(address, output, size);
}

std::string Game::ReadPlayerName(std::uintptr_t playerState) const {
    using namespace FortniteOffsets;
    const fn::FString name = Read<fn::FString>(playerState + PlayerState::PlayerNamePrivate);
    if (name.Count <= 0 || name.Count > 256 || !fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(name.Data))) {
        return {};
    }

    std::vector<wchar_t> wide(static_cast<std::size_t>(name.Count));
    if (!ReadInto(reinterpret_cast<std::uintptr_t>(name.Data), wide.data(), wide.size() * sizeof(wchar_t))) {
        return {};
    }
    wide.back() = L'\0';

    const int length = ::WideCharToMultiByte(CP_UTF8, 0, wide.data(), -1, nullptr, 0, nullptr, nullptr);
    if (length <= 1) return {};
    std::string result(static_cast<std::size_t>(length), '\0');
    ::WideCharToMultiByte(CP_UTF8, 0, wide.data(), -1, result.data(), length, nullptr, nullptr);
    result.resize(static_cast<std::size_t>(length - 1));
    return result;
}

float Game::ReadAttribute(std::uintptr_t healthSet, std::uint64_t attribute) const {
    using namespace FortniteOffsets;
    const float value = Read<float>(healthSet + attribute + FortGameplayAttributeData::CurrentValue);
    return std::isfinite(value) && value >= 0.0f && value <= 100000.0f ? value : 0.0f;
}

WorldSnapshot Game::Capture(const Config& config, int screenWidth, int screenHeight) {
    using namespace FortniteOffsets;
    WorldSnapshot snapshot;
    if (!Ready()) return snapshot;

    const std::uintptr_t world = Read<std::uintptr_t>(moduleBase_ + UWorld);
    const std::uintptr_t gameInstance = Read<std::uintptr_t>(world + World::OwningGameInstance);
    const fn::TArray<std::uintptr_t> localPlayers = Read<fn::TArray<std::uintptr_t>>(
        gameInstance + GameInstance::LocalPlayers);
    if (localPlayers.Count <= 0 || !fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(localPlayers.Data))) {
        status_ = "attached; waiting for LocalPlayers";
        return snapshot;
    }

    const std::uintptr_t localPlayer = Read<std::uintptr_t>(reinterpret_cast<std::uintptr_t>(localPlayers.Data));
    const std::uintptr_t controller = Read<std::uintptr_t>(localPlayer + Player::Controller);
    const std::uintptr_t cameraManager = Read<std::uintptr_t>(controller + PlayerController::PlayerCameraManager);
    const fn::FCameraCachePrefix camera = Read<fn::FCameraCachePrefix>(
        cameraManager + PlayerCameraManager::CameraCachePrivate);
    if (!fn::IsValidAddress(controller) || !fn::IsValidAddress(cameraManager) ||
        !fn::IsFinite(camera.POV.Location) || !fn::IsFinite(camera.POV.Rotation) ||
        camera.POV.FOV <= 1.0f || camera.POV.FOV >= 179.0f) {
        status_ = "attached; waiting for a valid local camera";
        return snapshot;
    }

    snapshot.CameraLocation = camera.POV.Location;
    snapshot.CameraRotation = camera.POV.Rotation;
    snapshot.CameraFov = camera.POV.FOV;
    snapshot.LocalPawn = Read<std::uintptr_t>(controller + PlayerController::AcknowledgedPawn);

    const std::uintptr_t gameState = Read<std::uintptr_t>(world + World::GameState);
    const fn::TArray<std::uintptr_t> playerArray = Read<fn::TArray<std::uintptr_t>>(
        gameState + GameStateBase::PlayerArray);
    if (playerArray.Count <= 0 || playerArray.Count > kMaxPlayers ||
        !fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(playerArray.Data))) {
        status_ = "attached; waiting for PlayerArray";
        return snapshot;
    }

    std::vector<std::uintptr_t> playerStates(static_cast<std::size_t>(playerArray.Count));
    if (!ReadInto(reinterpret_cast<std::uintptr_t>(playerArray.Data), playerStates.data(),
                  playerStates.size() * sizeof(std::uintptr_t))) {
        status_ = "PlayerArray read failed; retrying";
        return snapshot;
    }

    if (fn::IsValidAddress(snapshot.LocalPawn)) {
        const std::uintptr_t localState = Read<std::uintptr_t>(snapshot.LocalPawn + Pawn::PlayerState);
        snapshot.LocalTeam = Read<std::uint8_t>(localState + FortPlayerStateAthena::TeamIndex);
    }

    for (const std::uintptr_t playerState : playerStates) {
        if (!fn::IsValidAddress(playerState)) continue;

        PlayerSnapshot player;
        player.Pawn = Read<std::uintptr_t>(playerState + PlayerState::PawnPrivate);
        if (!fn::IsValidAddress(player.Pawn) || player.Pawn == snapshot.LocalPawn) continue;

        const std::uint8_t stateFlags = Read<std::uint8_t>(playerState + PlayerState::Flags);
        player.IsBot = (stateFlags & PlayerState::BotMask) != 0;
        if (player.IsBot && !config.includeBots) continue;

        const std::uint8_t actorFlags = Read<std::uint8_t>(player.Pawn + Actor::Flags);
        const std::uint8_t lifeFlags = Read<std::uint8_t>(player.Pawn + FortPawn::LifeFlags);
        player.Dead = (lifeFlags & FortPawn::DyingMask) != 0;
        if (player.Dead || (actorFlags & Actor::HiddenMask) != 0) continue;

        const std::uintptr_t rootComponent = Read<std::uintptr_t>(player.Pawn + Actor::RootComponent);
        if (!fn::IsValidAddress(rootComponent)) continue;
        player.Root = Read<fn::FVector>(rootComponent + SceneComponent::RelativeLocation);
        if (!fn::IsFinite(player.Root)) continue;

        player.DistanceM = static_cast<float>(fn::Length(player.Root - snapshot.CameraLocation) / 100.0);
        if (player.DistanceM > config.maxDistanceM) continue;

        player.Team = Read<std::uint8_t>(playerState + FortPlayerStateAthena::TeamIndex);
        player.Name = ReadPlayerName(playerState);
        if (player.Name.empty()) player.Name = player.IsBot ? "Bot" : "Player";

        const std::uintptr_t healthSet = Read<std::uintptr_t>(player.Pawn + FortPawn::HealthSet);
        if (!fn::IsValidAddress(healthSet)) continue;
        player.Health = ReadAttribute(healthSet, FortHealthSet::Health);
        player.MaxHealth = ReadAttribute(healthSet, FortHealthSet::MaxHealth);
        player.Shield = ReadAttribute(healthSet, FortHealthSet::Shield);
        if (player.MaxHealth <= 0.0f) player.MaxHealth = 100.0f;

        const std::uintptr_t mesh = Read<std::uintptr_t>(player.Pawn + Character::Mesh);
        if (!fn::IsValidAddress(mesh)) continue;
        const std::uint8_t renderFlags = Read<std::uint8_t>(mesh + SkinnedMeshComponent::RecentlyRenderedFlags);
        player.RecentlyRendered = (renderFlags & SkinnedMeshComponent::RecentlyRenderedMask) != 0;

        const fn::FTransform cachedWorldToLocal = Read<fn::FTransform>(
            mesh + SkinnedMeshComponent::CachedWorldToLocalTransform);
        const fn::TArray<fn::FTransform> cachedBones = Read<fn::TArray<fn::FTransform>>(
            mesh + SkeletalMeshComponent::CachedComponentSpaceTransforms);
        if (cachedBones.Count <= 0 || cachedBones.Count > kMaxBones ||
            !fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(cachedBones.Data))) {
            continue;
        }

        fn::FMatrix localToWorld;
        if (!fn::InvertMatrix(fn::ToMatrix(cachedWorldToLocal), localToWorld)) continue;

        std::vector<fn::FTransform> bones(static_cast<std::size_t>(cachedBones.Count));
        if (!ReadInto(reinterpret_cast<std::uintptr_t>(cachedBones.Data), bones.data(),
                      bones.size() * sizeof(fn::FTransform))) {
            continue;
        }

        const int headBone = std::clamp(config.headBone, 0, cachedBones.Count - 1);
        player.Head = fn::TransformPoint(localToWorld, bones[static_cast<std::size_t>(headBone)].Translation);
        player.HeadProjected = fn::WorldToScreen(player.Head, snapshot.CameraLocation,
            snapshot.CameraRotation, snapshot.CameraFov, screenWidth, screenHeight, player.HeadScreen);
        player.FeetProjected = fn::WorldToScreen(player.Root, snapshot.CameraLocation,
            snapshot.CameraRotation, snapshot.CameraFov, screenWidth, screenHeight, player.FeetScreen);

        player.Bones.reserve(std::size(kBodyBones));
        for (const NamedBone& namedBone : kBodyBones) {
            if (namedBone.Index >= cachedBones.Count) continue;
            BonePoint point;
            point.Name = namedBone.Name;
            point.World = fn::TransformPoint(localToWorld,
                bones[static_cast<std::size_t>(namedBone.Index)].Translation);
            point.Projected = fn::WorldToScreen(point.World, snapshot.CameraLocation,
                snapshot.CameraRotation, snapshot.CameraFov, screenWidth, screenHeight, point.Screen);
            if (point.Projected) player.Bones.push_back(point);
        }

        snapshot.Players.push_back(std::move(player));
    }

    snapshot.Valid = true;
    status_ = "attached read-only | players: " + std::to_string(snapshot.Players.size());
    return snapshot;
}
