#pragma once

#include <cstdint>

// Subset of the cheatoffsets.com Fortnite dump supplied with the project.
namespace FortniteOffsets {
    inline constexpr std::uintptr_t UWorld = 0x1C8E1578;
    inline constexpr std::uintptr_t GEngine = 0x1C8E2F48;

    namespace Engine {
        inline constexpr std::uint64_t GameInstance = 0x1100;
    }

    namespace World {
        inline constexpr std::uint64_t GameState = 0x1D0;
        inline constexpr std::uint64_t OwningGameInstance = 0x248;
    }

    namespace GameInstance {
        inline constexpr std::uint64_t LocalPlayers = 0x38;
    }

    namespace Player {
        // FILL: UPlayer was absent from the supplied dump. If LocalPlayer->Controller
        // fails, dump UPlayer::PlayerController in the SDK and replace 0x30.
        inline constexpr std::uint64_t Controller = 0x30;
    }

    namespace GameStateBase {
        inline constexpr std::uint64_t PlayerArray = 0x290;
    }

    namespace PlayerState {
        inline constexpr std::uint64_t Flags = 0x282;
        inline constexpr std::uint64_t PawnPrivate = 0x2F0;
        inline constexpr std::uint64_t PlayerNamePrivate = 0x310;
        inline constexpr std::uint8_t BotMask = 1u << 3;
    }

    namespace FortPlayerStateAthena {
        inline constexpr std::uint64_t TeamIndex = 0xF81;
    }

    namespace Controller {
        inline constexpr std::uint64_t Pawn = 0x2B8;
        inline constexpr std::uint64_t ControlRotation = 0x2F0;
    }

    namespace PlayerController {
        inline constexpr std::uint64_t AcknowledgedPawn = 0x320;
        inline constexpr std::uint64_t PlayerCameraManager = 0x330;
    }

    namespace PlayerCameraManager {
        inline constexpr std::uint64_t CameraCachePrivate = 0x15A0;
    }

    namespace CameraCacheEntry {
        inline constexpr std::uint64_t Timestamp = 0x0;
        inline constexpr std::uint64_t POV = 0x10;
    }

    namespace MinimalViewInfo {
        inline constexpr std::uint64_t Location = 0x0;
        inline constexpr std::uint64_t Rotation = 0x18;
        inline constexpr std::uint64_t FOV = 0x30;
    }

    namespace Actor {
        inline constexpr std::uint64_t Flags = 0x58;
        inline constexpr std::uint64_t RootComponent = 0x1B0;
        inline constexpr std::uint8_t HiddenMask = 1u << 7;
    }

    namespace Pawn {
        inline constexpr std::uint64_t PlayerState = 0x298;
    }

    namespace Character {
        inline constexpr std::uint64_t Mesh = 0x2F8;
    }

    namespace SceneComponent {
        inline constexpr std::uint64_t RelativeLocation = 0x140;
    }

    namespace SkinnedMeshComponent {
        // FILL: the supplied dump omitted this field storage and exact visibility flag.
        inline constexpr std::uint64_t RecentlyRenderedFlags = 0x7E1;
        inline constexpr std::uint64_t CachedWorldToLocalTransform = 0x870;
        inline constexpr std::uint8_t RecentlyRenderedMask = 1u << 1;
    }

    namespace SkeletalMeshComponent {
        inline constexpr std::uint64_t CachedComponentSpaceTransforms = 0x9C8;
    }

    namespace FortPawn {
        inline constexpr std::uint64_t LifeFlags = 0x738;
        inline constexpr std::uint64_t DbnoFlags = 0x892;
        inline constexpr std::uint64_t HealthSet = 0x1430;
        inline constexpr std::uint8_t DyingMask = 1u << 5;
        inline constexpr std::uint8_t DbnoMask = 1u << 7;
    }

    namespace FortHealthSet {
        inline constexpr std::uint64_t Health = 0x48;
        inline constexpr std::uint64_t MaxHealth = 0x70;
        inline constexpr std::uint64_t Shield = 0x98;
    }

    namespace FortGameplayAttributeData {
        // FILL: the supplied dump gave the attributes but not this nested field.
        inline constexpr std::uint64_t CurrentValue = 0x4;
    }
}
