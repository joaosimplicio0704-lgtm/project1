#pragma once
#include "../config.h"
#include "../sdk/sdk.h"

struct LocalState;
class Memory;

// ============================================================
// Voo externo.
//
// ESTE E O UNICO MODULO QUE ESCREVE NO PERSONAGEM.
//
// DOIS MODOS, e a escolha do modo e o que separa "voar" de "levar
// Disconnect (erro 277)":
//
//   kFlyVelocity (padrao)
//     escreve AssemblyLinearVelocity. O servidor ve fisica normal de um
//     personagem que ele ja deixa o cliente simular: nao existe delta de
//     posicao absurdo pra validar, entao nao toma kick. E o modo "seguro".
//
//   kFlyPosition
//     escreve Primitive::Position direto. Anda mais e atravessa coisa,
//     mas cada write e um teleporte: e exatamente o que a validacao de
//     movimento do servidor derruba. Por isso aqui o passo por write e
//     limitado (maxStepStuds) e a taxa e limitada (writeHz ~60): num
//     frame de 60 fps o cliente nunca "pula" mais que alguns studs.
//
// Se o jogo engolir a velocidade (humanoid reescrevendo), o modo cai
// sozinho pra posicao e avisa na aba.
//
// Ainda no modo posicao: resync com pausa (brigar com o servidor
// escrevendo/vendo reverter a cada tick e o que parece teleporte pra ele).
//
// WASD no plano da camera, Space/Ctrl sobem/descem.
// ============================================================

class Fly {
public:
    void Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked);
    void Reset();

    bool    Active() const { return m_active; }
    bool    Hovering() const { return m_active && m_hovering; }
    bool    HasPosition() const { return m_havePos; }
    Vector3 Position() const { return m_pos; }

    // o jogo aceitou o ultimo write? (false = handle sem VM_WRITE / posicao recusada)
    bool    WriteOk() const { return m_writeOk; }
    int     WriteFails() const { return m_writeFails; }
    // o jogo esta revertendo a posicao escrita (precisa do modo Ancorar)
    bool    Reverting() const { return m_reverting; }
    bool    Anchored() const { return m_anchored; }

    // modo em uso neste instante (pode ter caido pra posicao sozinho)
    int     Mode() const { return m_effectiveMode; }
    bool    AutoSwitched() const { return m_autoSwitched; }
    // diagnostico: em modo fisica, o jogo esta ignorando a velocidade escrita
    bool    Ignoring() const { return m_autoSwitched && m_effectiveMode == cfg::kFlyVelocity; }

private:
    void Stop(Memory& memory);
    bool SetAnchored(Memory& memory, uintptr_t primitive, bool anchored);

    bool      m_active = false;     // armado e com write valido
    bool      m_hovering = false;   // parado no ar (so segurando altura)
    bool      m_toggled = false;
    bool      m_prevDown = false;
    bool      m_havePos = false;
    bool      m_wasActive = false;
    Vector3   m_pos{};
    uintptr_t m_primitive = 0;
    uint64_t  m_lastTick = 0;
    uint64_t  m_lastWrite = 0;
    uint64_t  m_pauseUntil = 0;

    bool      m_writeOk = false;
    int       m_writeFails = 0;

    bool      m_anchored = false;
    uintptr_t m_anchorPrimitive = 0;
    bool      m_reverting = false;
    uint64_t  m_revertSince = 0;

    // deteccao de "o jogo ignora a velocidade"
    int       m_effectiveMode = cfg::kFlyVelocity;
    bool      m_autoSwitched = false;
    Vector3   m_probePos{};
    uint64_t  m_stillSince = 0;
};
