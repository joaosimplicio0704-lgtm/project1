#pragma once
// Fortnite offsets (Unreal Engine) — xerozify dump + comum UE.
// Valores abaixo são do dump fornecido. Onde o dump não cobre, deixei // FILL:
// com a receita para tirar do dumper/CE.
// Não verifiquei contra o seu executável: confirme cada offset com um dumper atual.

namespace off {
constexpr uintptr_t kImageBase = 0x0; // preenchido em runtime pelo module base

// --- globais (RVA sobre a base do módulo FortniteClient-Win64-Shipping.exe) ---
// GWorld / UWorld global. O dump lista UWORLD em Class (0x1C8E1578) — trata como global RVA.
// Receita: CE pointer-scan no endereço que aponta pra UWorld, ou dumper de globals.
inline constexpr uintptr_t kGWorld = 0x1C8E1578;
inline constexpr uintptr_t kGEngine = 0x1C8E2F48;
// GNames não está no dump — obrigatório para comparar nomes de classe. // FILL:
//   CE: ache uma string de classe conhecida (ex: "FortPlayerPawnAthena"), descubra o
//   FName pool, o offset de GNames costuma ficar perto de outras globais de engine.
inline constexpr uintptr_t kGNames = 0x0; // FILL: RVA de GNames

// --- UWorld (World) ---
inline constexpr uintptr_t kWorld_PersistentLevel = 0x40;
inline constexpr uintptr_t kWorld_GameState = 0x1D0;
inline constexpr uintptr_t kWorld_Levels = 0x1E8;

// --- ULevel ---
// ULevel::Actors (TArray<AActor*>) NÃO está no dump. // FILL:
//   CE: PersistentLevel -> Levels[0] -> ponteiro do TArray de Atores (pointer-scan).
//   Tamanho típico ~0x... varia por build; ache com "pointer scan" no endereço do primeiro ator.
inline constexpr uintptr_t kLevel_Actors = 0x0; // FILL

// --- AActor ---
inline constexpr uintptr_t kActor_RootComponent = 0x1B0;

// --- USceneComponent ---
// mundo do ator: usar ComponentToWorld (não está no dump). RelativeLocation é aproximação.
inline constexpr uintptr_t kScene_RelativeLocation = 0x140;
inline constexpr uintptr_t kScene_ComponentToWorld = 0x0; // FILL: se quiser posição exata

// --- APawn ---
inline constexpr uintptr_t kPawn_PlayerState = 0x298;
inline constexpr uintptr_t kPawn_Controller = 0x2A8;

// --- ACharacter ---
inline constexpr uintptr_t kCharacter_Mesh = 0x2F8;
inline constexpr uintptr_t kCharacter_Movement = 0x300;

// --- AFortPawn ---
inline constexpr uintptr_t kFortPawn_HealthSet = 0x1430;
inline constexpr uintptr_t kFortPawn_CurrentWeapon = 0x9E0;
inline constexpr uintptr_t kFortPawn_bIsDBNO = 0x892; // bit dentro de um byte — mascara necessária

// --- UFortHealthSet ---
inline constexpr uintptr_t kHealthSet_Health = 0x48;
inline constexpr uintptr_t kHealthSet_MaxHealth = 0x70;
inline constexpr uintptr_t kHealthSet_Shield = 0x98;
inline constexpr uintptr_t kHealthSet_CurrentShield = 0xC0;

// --- APlayerController ---
inline constexpr uintptr_t kController_PlayerCameraManager = 0x330;
inline constexpr uintptr_t kController_AcknowledgedPawn = 0x320;
inline constexpr uintptr_t kController_Pawn = 0x2B8;

// --- APlayerCameraManager ---
inline constexpr uintptr_t kCameraManager_CameraCachePrivate = 0x15A0;

// --- FCameraCacheEntry / FMinimalViewInfo ---
inline constexpr uintptr_t kCameraCacheEntry_POV = 0x10;
inline constexpr uintptr_t kMinimalViewInfo_Location = 0x0;
inline constexpr uintptr_t kMinimalViewInfo_Rotation = 0x18;
inline constexpr uintptr_t kMinimalViewInfo_FOV = 0x30;

// --- APlayerState ---
inline constexpr uintptr_t kPlayerState_PlayerNamePrivate = 0x310;
inline constexpr uintptr_t kPlayerState_TeamIndex = 0xF81;      // FortPlayerStateAthena
inline constexpr uintptr_t kPlayerState_PlayerTeam = 0x650;    // FortPlayerState

// --- USkeletalMeshComponent (ossa) ---
inline constexpr uintptr_t kMesh_CachedComponentSpaceTransforms = 0x9C8;
// // FILL: offset do array de ossos + índice do osso da cabeça (head bone index),
//   não vêm no dump. CE: SkeletalMeshComponent -> BoneArray / GetBoneMatrix.

// --- UWorld::PersistentLevel -> Actors (TArray) template helpers ---
inline constexpr size_t kTArray_Data = 0x0;
inline constexpr size_t kTArray_Count = 0x8;
} // namespace off
