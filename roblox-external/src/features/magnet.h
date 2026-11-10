#pragma once
#include <cstdint>

#include "../config.h"
#include "esp.h"

class Memory;

// ============================================================
// MAGNET — puxa item filtrado pra perto de voce.
//
// Reusa a varredura do "ESP de objetos": os PartMark ja vem com nome,
// posicao e o endereco do Primitive. Aqui so escrevemos
// Primitive::Position do item pra perto do personagem.
//
// Quando funciona: item desancorado e com network ownership do cliente
// (o caso normal de loot largado no chao). Quando nao funciona: item
// Anchored, ou o servidor com ownership — o item volta e a gente nao
// insiste (conta as recusas e mostra na aba).
//
// Alternativa garantida (botao "ir ate"): escreve a posicao do SEU
// personagem, que o cliente sempre manda.
// ============================================================

class Magnet {
public:
    void Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local,
              const SceneSnapshot& scene, bool blocked);

    // puxa agora, ignorando o toggle (botao da aba)
    void PullOnce(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                  const SceneSnapshot& scene);

    // leva o personagem ate o item mais proximo do filtro
    bool TeleportToNearest(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                           const SceneSnapshot& scene);

    void Reset();

    int   Pulled() const { return m_pulled; }
    int   Refused() const { return m_refused; }

private:
    bool PullOne(Memory& memory, const LocalState& local, const PartMark& part,
                 const cfg::MagnetSettings& magnet);

    uint64_t m_lastPull = 0;
    int      m_pulled = 0;
    int      m_refused = 0;
    uint64_t m_lastRefuseLog = 0;
};
