#pragma once
#include "../config.h"

struct LocalState;
class Memory;

// ============================================================
// Voo externo.
//
// ESTE E O UNICO MODULO QUE ESCREVE EM MEMORIA.
//
// Nao existe voo read-only: voar significa mudar a posicao do personagem.
// Aqui o write vai direto no Primitive::Position do HumanoidRootPart
// (o cliente tem network ownership do proprio personagem, entao a posicao
// escrita e aceita pelo servidor na maioria dos jogos), com a velocidade
// linear zerada pra gravidade nao brigar.
//
// WASD move no plano da camera, Space/Ctrl sobem/descem.
// ============================================================

class Fly {
public:
    void Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked);
    void Reset();

    bool Active() const { return m_active; }

private:
    bool      m_active = false;
    bool      m_toggled = false;
    bool      m_prevDown = false;
    uint64_t  m_lastTick = 0;
};
