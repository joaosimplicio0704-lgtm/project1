#pragma once
#include "../config.h"
#include "../sdk/sdk.h"

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
//
// Detalhes que fazem diferenca (e que a versao anterior errava):
//   - posicao propria: integra m_pos e escreve esse valor, em vez de
//     somar o passo em cima do snapshot do leitor (que chega atrasado e
//     fazia o movimento tremer / andar menos que o slider);
//   - resync: se o jogo moveu o personagem (teleporte, knockback,
//     respawn, morte) a posicao volta a ser a real em vez de brigar;
//   - hover: sem WASD o personagem segura a altura (velocidade zerada)
//     em vez de cair, que era o sintoma de "voar bugado";
//   - dt limitado: um frame travado nao vira um teleporte de 300 studs;
//   - solta a tecla = velocidade zerada uma vez, senao o personagem
//     continuava planando com o ultimo vetor.
// ============================================================

class Fly {
public:
    void Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked);
    void Reset();

    bool    Active() const { return m_active; }
    bool    Hovering() const { return m_active && m_hovering; }
    bool    HasPosition() const { return m_havePos; }
    Vector3 Position() const { return m_pos; }

private:
    void Stop(Memory& memory);

    bool      m_active = false;     // armado e com write valido
    bool      m_hovering = false;   // parado no ar (so segurando altura)
    bool      m_toggled = false;
    bool      m_prevDown = false;
    bool      m_havePos = false;
    bool      m_wasActive = false;
    Vector3   m_pos{};
    uintptr_t m_primitive = 0;
    uint64_t  m_lastTick = 0;
};
