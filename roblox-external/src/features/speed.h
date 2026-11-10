#pragma once
#include <cstdint>

#include "../config.h"

class Memory;
struct LocalState;

// ============================================================
// CORRIDA — WalkSpeed (e opcionalmente JumpPower).
//
// Escreve Humanoid::Walkspeed. O personagem tem network ownership do
// cliente, entao o movimento e aplicado localmente e replicado; e o jeito
// mais barato de "correr mais rapido" que existe.
//
// Duas coisas que importam:
//   - guarda o valor original e devolve ao desligar (senao o jogo fica
//     com walkspeed alterado pra sempre, inclusive depois de morrer);
//   - reescreve a cada 250 ms, porque muito jogo reseta WalkSpeed no
//     servidor/script. Sem isso "as vezes funciona, as vezes nao".
// ============================================================

class Speed {
public:
    void Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked);

    // devolve o WalkSpeed original (panic / shutdown)
    void Restore(Memory& memory);

    bool  Active() const { return m_owned; }
    float Original() const { return m_original; }
    int   Writes() const { return m_writes; }

private:
    bool      m_owned = false;
    bool      m_jumpOwned = false;
    float     m_original = 16.f;
    float     m_originalJump = 50.f;
    uintptr_t m_humanoid = 0;
    uint64_t  m_lastWrite = 0;
    uint64_t  m_lastJump = 0;
    int       m_writes = 0;
};
