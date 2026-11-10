#include "Game.h"

#include "Offsets.h"

#include <windows.h>
#include <tlhelp32.h>

#include <algorithm>
#include <array>
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
        { "pelvis", 5 }, { "spine_01", 6 }, { "spine_02", 7 },
        { "spine_03", 8 }, { "spine_04", 9 }, { "spine_05", 10 },
        { "neck_01", 66 }, { "neck_02", 67 }, { "head", 110 },
        { "clavicle_l", 11 }, { "upperarm_l", 12 }, { "lowerarm_l", 13 },
        { "hand_l", 14 }, { "clavicle_r", 38 }, { "upperarm_r", 39 },
        { "lowerarm_r", 40 }, { "hand_r", 41 }, { "thigh_l", 69 },
        { "lowerleg_l", 70 }, { "foot_l", 71 }, { "thigh_r", 76 },
        { "lowerleg_r", 77 }, { "foot_r", 78 }
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

    bool ValidCamera(const fn::FCameraCachePrefix& camera) {
        return fn::IsFinite(camera.POV.Location) && fn::IsFinite(camera.POV.Rotation) &&
            camera.POV.FOV > 1.0f && camera.POV.FOV < 179.0f;
    }

    bool ReasonableBone(const fn::FVector& point, const fn::FVector& root) {
        return fn::IsFinite(point) && fn::Length(point - root) < 1000.0;
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
    if (name.Count <= 0 || name.Count > 256 ||
        !fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(name.Data))) {
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
    if (!fn::IsValidAddress(world)) {
        status_ = "UWorld is invalid; the supplied offset needs a redump";
        return snapshot;
    }

    std::uintptr_t gameInstance = Read<std::uintptr_t>(world + World::OwningGameInstance);
    if (!fn::IsValidAddress(gameInstance)) {
        const std::uintptr_t engine = Read<std::uintptr_t>(moduleBase_ + GEngine);
        gameInstance = Read<std::uintptr_t>(engine + Engine::GameInstance);
    }
    if (!fn::IsValidAddress(gameInstance)) {
        status_ = "GameInstance is invalid in both World and GEngine chains";
        return snapshot;
    }

    const fn::TArray<std::uintptr_t> localPlayers = Read<fn::TArray<std::uintptr_t>>(
        gameInstance + GameInstance::LocalPlayers);
    if (localPlayers.Count <= 0 ||
        !fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(localPlayers.Data))) {
        status_ = "attached; waiting for LocalPlayers";
        return snapshot;
    }

    const std::uintptr_t localPlayer = Read<std::uintptr_t>(
        reinterpret_cast<std::uintptr_t>(localPlayers.Data));
    if (!fn::IsValidAddress(localPlayer)) {
        status_ = "LocalPlayers[0] is invalid";
        return snapshot;
    }

    // Validate candidates through PlayerCameraManager and POV instead of
    // trusting UPlayer::Controller blindly across nearby SDK revisions.
    constexpr std::array<std::uint64_t, 4> controllerOffsets{
        Player::Controller, 0x38, 0x40, 0x28
    };
    std::uintptr_t controller = 0;
    fn::FCameraCachePrefix camera{};
    for (const std::uint64_t offset : controllerOffsets) {
        const std::uintptr_t candidateController = Read<std::uintptr_t>(localPlayer + offset);
        if (!fn::IsValidAddress(candidateController)) continue;
        const std::uintptr_t candidateManager = Read<std::uintptr_t>(
            candidateController + PlayerController::PlayerCameraManager);
        if (!fn::IsValidAddress(candidateManager)) continue;
        const fn::FCameraCachePrefix candidateCamera = Read<fn::FCameraCachePrefix>(
            candidateManager + PlayerCameraManager::CameraCachePrivate);
        if (!ValidCamera(candidateCamera)) continue;
        controller = candidateController;
        camera = candidateCamera;
        break;
    }
    bool cameraFallback = false;
    if (!fn::IsValidAddress(controller)) {
        // CameraManager is preferable, but a valid possessed pawn and control
        // rotation still provide an approximate first-person camera fallback.
        for (const std::uint64_t offset : controllerOffsets) {
            const std::uintptr_t candidateController = Read<std::uintptr_t>(localPlayer + offset);
            if (!fn::IsValidAddress(candidateController)) continue;
            std::uintptr_t candidatePawn = Read<std::uintptr_t>(
                candidateController + PlayerController::AcknowledgedPawn);
            if (!fn::IsValidAddress(candidatePawn)) {
                candidatePawn = Read<std::uintptr_t>(candidateController + Controller::Pawn);
            }
            const std::uintptr_t candidateRoot = Read<std::uintptr_t>(candidatePawn + Actor::RootComponent);
            const fn::FVector root = Read<fn::FVector>(candidateRoot + SceneComponent::RelativeLocation);
            const fn::FRotator rotation = Read<fn::FRotator>(candidateController + Controller::ControlRotation);
            if (!fn::IsValidAddress(candidatePawn) || !fn::IsValidAddress(candidateRoot) ||
                !fn::IsFinite(root) || !fn::IsFinite(rotation)) {
                continue;
            }
            controller = candidateController;
            camera.POV.Location = root + fn::FVector{ 0.0, 0.0, 160.0 };
            camera.POV.Rotation = rotation;
            camera.POV.FOV = 90.0f;
            cameraFallback = true;
            break;
        }
    }
    if (!fn::IsValidAddress(controller)) {
        status_ = "local camera and controller fallback both failed; redump required";
        return snapshot;
    }

    snapshot.CameraFallback = cameraFallback;
    snapshot.CameraLocation = camera.POV.Location;
    snapshot.CameraRotation = camera.POV.Rotation;
    snapshot.CameraFov = camera.POV.FOV;
    snapshot.LocalPawn = Read<std::uintptr_t>(controller + PlayerController::AcknowledgedPawn);
    if (!fn::IsValidAddress(snapshot.LocalPawn)) {
        snapshot.LocalPawn = Read<std::uintptr_t>(controller + Controller::Pawn);
    }

    if (fn::IsValidAddress(snapshot.LocalPawn)) {
        snapshot.LocalPlayerState = Read<std::uintptr_t>(snapshot.LocalPawn + Pawn::PlayerState);
    }
    if (!fn::IsValidAddress(snapshot.LocalPlayerState)) {
        snapshot.LocalPlayerState = Read<std::uintptr_t>(controller + Pawn::PlayerState);
    }
    if (fn::IsValidAddress(snapshot.LocalPlayerState)) {
        snapshot.LocalTeam = Read<std::uint8_t>(
            snapshot.LocalPlayerState + FortPlayerStateAthena::TeamIndex);
    }

    const std::uintptr_t gameState = Read<std::uintptr_t>(world + World::GameState);
    const fn::TArray<std::uintptr_t> playerArray = Read<fn::TArray<std::uintptr_t>>(
        gameState + GameStateBase::PlayerArray);
    if (playerArray.Count <= 0 || playerArray.Count > kMaxPlayers ||
        !fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(playerArray.Data))) {
        status_ = "attached; waiting for a valid GameState PlayerArray";
        return snapshot;
    }
    snapshot.PlayerStateCount = playerArray.Count;

    std::vector<std::uintptr_t> playerStates(static_cast<std::size_t>(playerArray.Count));
    if (!ReadInto(reinterpret_cast<std::uintptr_t>(playerArray.Data), playerStates.data(),
                  playerStates.size() * sizeof(std::uintptr_t))) {
        status_ = "PlayerArray bulk read failed; retrying";
        return snapshot;
    }

    for (const std::uintptr_t playerState : playerStates) {
        if (!fn::IsValidAddress(playerState) || playerState == snapshot.LocalPlayerState) continue;

        PlayerSnapshot player;
        std::uintptr_t rootComponent = 0;
        constexpr std::array<std::uint64_t, 3> pawnOffsets{
            PlayerState::PawnPrivate, 0x2E8, 0x2F8
        };
        for (const std::uint64_t offset : pawnOffsets) {
            const std::uintptr_t candidatePawn = Read<std::uintptr_t>(playerState + offset);
            if (!fn::IsValidAddress(candidatePawn) || candidatePawn == snapshot.LocalPawn) continue;
            const std::uintptr_t candidateRoot = Read<std::uintptr_t>(candidatePawn + Actor::RootComponent);
            if (!fn::IsValidAddress(candidateRoot)) continue;
            player.Pawn = candidatePawn;
            rootComponent = candidateRoot;
            break;
        }
        if (!fn::IsValidAddress(player.Pawn)) continue;
        ++snapshot.CandidateCount;

        const std::uint8_t stateFlags = Read<std::uint8_t>(playerState + PlayerState::Flags);
        player.IsBot = (stateFlags & PlayerState::BotMask) != 0;
        if (player.IsBot && !config.includeBots) continue;

        const std::uint8_t actorFlags = Read<std::uint8_t>(player.Pawn + Actor::Flags);
        const std::uint8_t lifeFlags = Read<std::uint8_t>(player.Pawn + FortPawn::LifeFlags);
        player.Dead = (lifeFlags & FortPawn::DyingMask) != 0;
        if (player.Dead || (actorFlags & Actor::HiddenMask) != 0) continue;

        player.Root = Read<fn::FVector>(rootComponent + SceneComponent::RelativeLocation);
        if (!fn::IsFinite(player.Root)) continue;
        player.DistanceM = static_cast<float>(fn::Length(player.Root - snapshot.CameraLocation) / 100.0);
        if (!std::isfinite(player.DistanceM) || player.DistanceM > config.maxDistanceM) continue;

        player.Team = Read<std::uint8_t>(playerState + FortPlayerStateAthena::TeamIndex);
        player.Name = ReadPlayerName(playerState);
        if (player.Name.empty()) player.Name = player.IsBot ? "Bot" : "Player";

        player.FeetProjected = fn::WorldToScreen(player.Root, snapshot.CameraLocation,
            snapshot.CameraRotation, snapshot.CameraFov, screenWidth, screenHeight, player.FeetScreen);

        const std::uintptr_t healthSet = Read<std::uintptr_t>(player.Pawn + FortPawn::HealthSet);
        if (fn::IsValidAddress(healthSet)) {
            player.Health = ReadAttribute(healthSet, FortHealthSet::Health);
            player.MaxHealth = ReadAttribute(healthSet, FortHealthSet::MaxHealth);
            player.Shield = ReadAttribute(healthSet, FortHealthSet::Shield);
            if (player.MaxHealth <= 0.0f) player.MaxHealth = 100.0f;
        }

        const std::uintptr_t mesh = Read<std::uintptr_t>(player.Pawn + Character::Mesh);
        if (fn::IsValidAddress(mesh)) {
            const std::uint8_t renderFlags = Read<std::uint8_t>(
                mesh + SkinnedMeshComponent::RecentlyRenderedFlags);
            player.RecentlyRendered = (renderFlags & SkinnedMeshComponent::RecentlyRenderedMask) != 0;

            const fn::FTransform cachedWorldToLocal = Read<fn::FTransform>(
                mesh + SkinnedMeshComponent::CachedWorldToLocalTransform);
            const fn::TArray<fn::FTransform> cachedBones = Read<fn::TArray<fn::FTransform>>(
                mesh + SkeletalMeshComponent::CachedComponentSpaceTransforms);
            fn::FMatrix localToWorld;
            if (cachedBones.Count > 0 && cachedBones.Count <= kMaxBones &&
                fn::IsValidAddress(reinterpret_cast<std::uintptr_t>(cachedBones.Data)) &&
                fn::InvertMatrix(fn::ToMatrix(cachedWorldToLocal), localToWorld)) {
                std::vector<fn::FTransform> bones(static_cast<std::size_t>(cachedBones.Count));
                if (ReadInto(reinterpret_cast<std::uintptr_t>(cachedBones.Data), bones.data(),
                             bones.size() * sizeof(fn::FTransform))) {
                    const int headBone = std::clamp(config.headBone, 0, cachedBones.Count - 1);
                    const fn::FVector candidateHead = fn::TransformPoint(localToWorld,
                        bones[static_cast<std::size_t>(headBone)].Translation);
                    if (ReasonableBone(candidateHead, player.Root)) {
                        player.HasBoneData = true;
                        player.Head = candidateHead;
                        player.Bones.reserve(std::size(kBodyBones));
                        for (const NamedBone& namedBone : kBodyBones) {
                            if (namedBone.Index >= cachedBones.Count) continue;
                            BonePoint point;
                            point.Name = namedBone.Name;
                            point.World = fn::TransformPoint(localToWorld,
                                bones[static_cast<std::size_t>(namedBone.Index)].Translation);
                            if (!ReasonableBone(point.World, player.Root)) continue;
                            point.Projected = fn::WorldToScreen(point.World, snapshot.CameraLocation,
                                snapshot.CameraRotation, snapshot.CameraFov,
                                screenWidth, screenHeight, point.Screen);
                            if (point.Projected) player.Bones.push_back(point);
                        }
                    }
                }
            }
        }

        if (!player.HasBoneData) {
            ++snapshot.BoneFallbackCount;
            player.Head = player.Root + fn::FVector{ 0.0, 0.0, 180.0 };
        }
        player.HeadProjected = fn::WorldToScreen(player.Head, snapshot.CameraLocation,
            snapshot.CameraRotation, snapshot.CameraFov, screenWidth, screenHeight, player.HeadScreen);
        snapshot.Players.push_back(std::move(player));
    }

    snapshot.Valid = true;
    status_ = "read-only | states: " + std::to_string(snapshot.PlayerStateCount) +
        " | candidates: " + std::to_string(snapshot.CandidateCount) +
        " | players: " + std::to_string(snapshot.Players.size()) +
        " | root fallback: " + std::to_string(snapshot.BoneFallbackCount) +
        (snapshot.CameraFallback ? " | approximate camera" : "");
    return snapshot;
}
