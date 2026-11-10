#pragma once
#include "mem.hpp"
#include "offsets.hpp"
#include "math.hpp"
#include <vector>
#include <string>

struct Entity {
    uintptr_t addr = 0;          // AActor (ou APawn quando for jogador)
    uintptr_t mesh = 0;
    uintptr_t healthSet = 0;
    uintptr_t playerState = 0;
    FVector head{};              // espaço do mundo (// FILL: cabeça via BoneArray)
    FVector feet{};              // posição do ator no mundo
    float health = 0.f;
    float maxHealth = 1.f;
    float shield = 0.f;
    int teamIndex = -1;
    bool bDBNO = false;
    bool valid = false;
    std::wstring name;
};

struct LocalPlayer {
    uintptr_t controller = 0;
    uintptr_t pawn = 0;
    uintptr_t cameraManager = 0;
    FVector camLoc{};
    FRotator camRot{};
    double fov = 90.0;
    int teamIndex = -1;
    bool valid = false;
};

class Entities {
public:
    explicit Entities(Mem& mem) : mem_(mem) {}

    void update(LocalPlayer& local, std::vector<Entity>& out) {
        out.clear();
        local = {};

        std::optional<uintptr_t> gWorldPtr = mem_.readPtr(off::kImageBase + off::kGWorld);
        if (!gWorldPtr) return;
        uintptr_t uWorld = *gWorldPtr;

        std::optional<uintptr_t> persistentLevel = mem_.readPtr(uWorld + off::kWorld_PersistentLevel);
        if (!persistentLevel) return;

        // GameState -> PlayerArray (para nomes/times dos player states)
        std::optional<uintptr_t> gameState = mem_.readPtr(uWorld + off::kWorld_GameState);
        uintptr_t playerArrayAddr = 0;
        size_t playerCount = 0;
        if (gameState) {
            playerArrayAddr = *gameState; // TArray começa no próprio objeto (Data no +0, Count no +8)
            mem_.read(*gameState + off::kTArray_Count, playerCount);
        }

        // ULevel::Actors — offset não no dump: // FILL (CE pointer-scan PersistentLevel->Levels[0]->Actors)
        std::vector<uintptr_t> actors;
        actors.resize(512);
        size_t actorCount = 0;
        mem_.read(*persistentLevel + off::kTArray_Count, actorCount);
        if (actorCount && actorCount <= 4096) {
            actors.resize(actorCount);
            mem_.readArray(*persistentLevel + off::kTArray_Data, actors.data(), actorCount);
        }

        for (size_t i = 0; i < actorCount && i < actors.size(); i++) {
            uintptr_t actor = actors[i];
            if (!actor) continue;
            Entity e;
            if (!readActor(actor, e)) continue;

            // cruza com player state (se o ator for um pawn) pra nome/time
            if (e.playerState) {
                int team = 0;
                if (mem_.read(e.playerState + off::kPlayerState_TeamIndex, team)) e.teamIndex = team;
                wchar_t nameBuf[64] = {};
                if (mem_.read(e.playerState + off::kPlayerState_PlayerNamePrivate, nameBuf, sizeof(nameBuf)))
                    e.name = nameBuf;
            }

            e.valid = true;
            out.push_back(e);
        }
    }

    // preenche local player a partir do controller conhecido (chamar depois de resolver o local controller)
    void setLocal(LocalPlayer& local, uintptr_t controller) {
        local = {};
        local.controller = controller;
        mem_.readPtr(controller + off::kController_AcknowledgedPawn, local.pawn);
        mem_.readPtr(controller + off::kController_PlayerCameraManager, local.cameraManager);
        if (local.cameraManager) {
            uintptr_t cache = 0;
            if (mem_.readPtr(local.cameraManager + off::kCameraManager_CameraCachePrivate, cache)) {
                // CameraCacheEntry[0].POV -> MinimalViewInfo
                uintptr_t pov = 0;
                if (mem_.readPtr(cache + off::kCameraCacheEntry_POV, pov)) {
                    mem_.read(pov + off::kMinimalViewInfo_Location, local.camLoc);
                    mem_.read(pov + off::kMinimalViewInfo_Rotation, local.camRot);
                    mem_.read(pov + off::kMinimalViewInfo_FOV, local.fov);
                }
            }
        }
        if (local.pawn) epawnPlayerState(local.pawn, local.teamIndex);
        local.valid = local.cameraManager != 0;
    }

private:
    Mem& mem_;

    bool readActor(uintptr_t actor, Entity& e) {
        e.addr = actor;
        e.feet = {};
        e.head = {};

        std::optional<uintptr_t> root = mem_.readPtr(actor + off::kActor_RootComponent);
        if (!root) return false;

        // posição: ComponentToWorld (FTransform, Translation em +0x20) se disponível, senão RelativeLocation
        FVector loc{};
        std::optional<uintptr_t> ctw = mem_.readPtr(*root + off::kScene_ComponentToWorld);
        if (ctw) {
            FVector trans{};
            if (!mem_.read(*ctw + 0x20, trans)) return false;
            loc = trans;
        } else {
            if (!mem_.read(*root + off::kScene_RelativeLocation, loc)) return false;
        }
        e.feet = loc;
        e.head = {loc.X, loc.Y, loc.Z + 90.0}; // // FILL: osso da cabeça (BoneArray + head index)

        std::optional<uintptr_t> mesh = mem_.readPtr(actor + off::kCharacter_Mesh);
        e.mesh = mesh ? *mesh : 0;

        std::optional<uintptr_t> healthSet = mem_.readPtr(actor + off::kFortPawn_HealthSet);
        e.healthSet = healthSet ? *healthSet : 0;
        if (e.healthSet) {
            mem_.read(e.healthSet + off::kHealthSet_Health, e.health);
            mem_.read(e.healthSet + off::kHealthSet_MaxHealth, e.maxHealth);
            mem_.read(e.healthSet + off::kHealthSet_CurrentShield, e.shield);
        }

        uint8_t dbnoByte = 0;
        if (mem_.read(actor + off::kFortPawn_bIsDBNO, dbnoByte)) e.bDBNO = (dbnoByte & 1) != 0;

        std::optional<uintptr_t> ps = mem_.readPtr(actor + off::kPawn_PlayerState);
        e.playerState = ps ? *ps : 0;

        return true;
    }

    bool epawnPlayerState(uintptr_t pawn, int& team) {
        std::optional<uintptr_t> ps = mem_.readPtr(pawn + off::kPawn_PlayerState);
        if (!ps) return false;
        return mem_.read(*ps + off::kPlayerState_TeamIndex, team);
    }
};
