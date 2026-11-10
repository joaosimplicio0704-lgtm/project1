#pragma once
#include <cstdint>

// ============================================================
// Roblox offsets — dump colado pelo dono do projeto
//   versao: version-f0ea5da9412f4e35
//
// COMO ATUALIZAR:
//   1. pegue o dump novo do cliente
//   2. substitua o namespace inteiro abaixo (o formato e o mesmo)
//   3. recompile. nada mais no projeto referencia offset cru.
//
// uso:  rbx::Player::ModelInstance, rbx::Primitive::Position, ...
// ============================================================

namespace rbx
{

inline constexpr const char* kVersion = "version-f0ea5da9412f4e35";

struct TaskScheduler {
    inline static constexpr uintptr_t Pointer = 0x8E4D7B8;
    inline static constexpr uintptr_t JobStart = 0xC8;
    inline static constexpr uintptr_t JobEnd = 0xD0;
    inline static constexpr uintptr_t JobName = 0x18;
    inline static constexpr uintptr_t MaxFPS = 0xB0;
};

struct VisualEngine {
    inline static constexpr uintptr_t Pointer = 0x8942E38;
    inline static constexpr uintptr_t Dimensions = 0xB10;
    inline static constexpr uintptr_t ViewMatrix = 0x1B0;
    inline static constexpr uintptr_t RenderView = 0xC50;
    inline static constexpr uintptr_t FakeDataModel = 0xAF0;
};

struct FakeDataModel {
    inline static constexpr uintptr_t Pointer = 0x8EB6960;
    inline static constexpr uintptr_t RealDataModel = 0x1F8;
};

struct Instance {
    inline static constexpr uintptr_t This = 0x8;
    inline static constexpr uintptr_t NameContainer = 0x68;
    inline static constexpr uintptr_t Name = 0x0;
    inline static constexpr uintptr_t ChildrenStart = 0x70;
    inline static constexpr uintptr_t ChildrenEnd = 0x8;
    inline static constexpr uintptr_t Parent = 0x60;
    inline static constexpr uintptr_t ClassDescriptor = 0x18;
    inline static constexpr uintptr_t ClassName = 0x8;
    inline static constexpr uintptr_t ClassBase = 0x1B0;
};

struct Misc {
    inline static constexpr uintptr_t StringLength = 0x10;
    inline static constexpr uintptr_t Adornee = 0xD8;
    inline static constexpr uintptr_t Value = 0xA0;
    inline static constexpr uintptr_t AnimationId = 0xA8;
};

struct DataModel {
    inline static constexpr uintptr_t PlaceId = 0x180;
    inline static constexpr uintptr_t GameId = 0x178;
    inline static constexpr uintptr_t CreatorId = 0x170;
    inline static constexpr uintptr_t GameLoaded = 0x588;
    inline static constexpr uintptr_t JobId = 0x108;
    inline static constexpr uintptr_t Workspace = 0x148;
    inline static constexpr uintptr_t ScriptContext = 0x440;
    inline static constexpr uintptr_t PlaceVersion = 0x19C;
    inline static constexpr uintptr_t ServerIP = 0x570;
    inline static constexpr uintptr_t ToRenderView1 = 0x1B8;
    inline static constexpr uintptr_t ToRenderView2 = 0x8;
    inline static constexpr uintptr_t ToRenderView3 = 0x28;
    inline static constexpr uintptr_t PrimitiveCount = 0x410;
};

struct Workspace {
    inline static constexpr uintptr_t World = 0x3F8;
    inline static constexpr uintptr_t ReadOnlyGravity = 0x9D0;
    inline static constexpr uintptr_t DistributedGameTime = 0x4C0;
    inline static constexpr uintptr_t CurrentCamera = 0x4A0;
};

struct Camera {
    inline static constexpr uintptr_t Position = 0xE4;
    inline static constexpr uintptr_t Rotation = 0xC0;
    inline static constexpr uintptr_t CameraSubject = 0xB0;
    inline static constexpr uintptr_t FieldOfView = 0x128;
    inline static constexpr uintptr_t ImagePlaneDepth = 0x2D4;
    inline static constexpr uintptr_t CameraType = 0x120;
    inline static constexpr uintptr_t Viewport = 0x284;
    inline static constexpr uintptr_t ViewportSize = 0x2C4;
};

struct Player {
    inline static constexpr uintptr_t LocalPlayer = 0x118;
    inline static constexpr uintptr_t UserId = 0xB8;
    inline static constexpr uintptr_t DisplayName = 0x120;
    inline static constexpr uintptr_t HealthDisplayDistance = 0x3A0;
    inline static constexpr uintptr_t NameDisplayDistance = 0x3B0;
    inline static constexpr uintptr_t ModelInstance = 0x2A0;
    inline static constexpr uintptr_t Team = 0x2E0;
    inline static constexpr uintptr_t TeamColor = 0x3B8;
    inline static constexpr uintptr_t LocaleId = 0x100;
    inline static constexpr uintptr_t AccountAge = 0x364;
    inline static constexpr uintptr_t MinZoomDistance = 0x374;
    inline static constexpr uintptr_t MaxZoomDistance = 0x370;
    inline static constexpr uintptr_t CameraMode = 0x378;
    inline static constexpr uintptr_t Mouse = 0x11F0;
};

struct Team {
    inline static constexpr uintptr_t BrickColor = 0xA0;
};

struct Humanoid {
    inline static constexpr uintptr_t Health = 0x184;
    inline static constexpr uintptr_t MaxHealth = 0x19C;
    inline static constexpr uintptr_t Walkspeed = 0x1C4;
    inline static constexpr uintptr_t JumpPower = 0x198;
    inline static constexpr uintptr_t JumpHeight = 0x194;
    inline static constexpr uintptr_t HipHeight = 0x188;
    inline static constexpr uintptr_t HumanoidRootPart = 0x460;
    inline static constexpr uintptr_t CameraOffset = 0x110;
    inline static constexpr uintptr_t DisplayName = 0xA0;
    inline static constexpr uintptr_t MoveDirection = 0x134;
    inline static constexpr uintptr_t RigType = 0x1B4;
    inline static constexpr uintptr_t IsWalking = 0xA2E;
    inline static constexpr uintptr_t HumanoidState = 0x8A8;
};

struct BasePart {
    inline static constexpr uintptr_t Primitive = 0x178;
    inline static constexpr uintptr_t Transparency = 0x118;
    inline static constexpr uintptr_t Color3 = 0x11C;
    inline static constexpr uintptr_t Shape = 0x1A0;
    inline static constexpr uintptr_t Massless = 0x122;
    inline static constexpr uintptr_t CastShadow = 0x120;
    inline static constexpr uintptr_t Locked = 0x121;
    inline static constexpr uintptr_t Reflectance = 0xF4;
};

struct Primitive {
    inline static constexpr uintptr_t Position = 0xD4;
    inline static constexpr uintptr_t Validate = 0x6;
    inline static constexpr uintptr_t Owner = 0x218;
    inline static constexpr uintptr_t Size = 0x1C4;
    inline static constexpr uintptr_t Rotation = 0xB0;
    inline static constexpr uintptr_t Flags = 0x1BE;
    inline static constexpr uintptr_t Material = 0x0;
    inline static constexpr uintptr_t AssemblyLinearVelocity = 0xE0;
    inline static constexpr uintptr_t AssemblyAngularVelocity = 0xEC;
};

struct PrimitiveFlags {
    inline static constexpr uintptr_t Anchored = 0x2;
    inline static constexpr uintptr_t CanCollide = 0x8;
    inline static constexpr uintptr_t CanTouch = 0x10;
    inline static constexpr uintptr_t CanQuery = 0x20;
};

struct Model {
    inline static constexpr uintptr_t PrimaryPart = 0x240;
    inline static constexpr uintptr_t Scale = 0x12C;
};

} // namespace rbx
