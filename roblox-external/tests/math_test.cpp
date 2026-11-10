// ============================================================
// Harness de testes offline (Linux/g++ — roda sem Windows, sem cliente).
//
//   cd roblox-external && ./tests/run.sh
//
// Cobre a parte que da pra provar sem executar o jogo:
//   1. WorldToScreen (matriz, centro, fora da tela, atras da camera)
//   2. FOV -> radianos por pixel (horizontal == vertical)
//   3. laco do aim: converge com calibracao, oscila sem ela
//   4. integracao do voo e o clamp de dt
//   5. config.json: round-trip e parser de string com virgula
// ============================================================

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <string>

#include "../src/sdk/mathx.h"
#include "../src/config.h"

namespace {

int g_failures = 0;
int g_checks = 0;

void Check(bool ok, const char* what) {
    ++g_checks;
    if (!ok) {
        ++g_failures;
        std::printf("  [FALHOU] %s\n", what);
    }
}

void CheckNear(float a, float b, float tol, const char* what) {
    ++g_checks;
    if (std::fabs(a - b) > tol) {
        ++g_failures;
        std::printf("  [FALHOU] %s  (%.4f vs %.4f, tol %.4f)\n", what, a, b, tol);
    }
}

// ---- matriz de projecao estilo Roblox: row-major, w na linha 3 ----
// camera em yaw/pitch olhando pra -Z, w = profundidade (positivo na frente)
Matrix4x4 MakeView(float yaw, float pitch, float fovDeg, float aspect) {
    const float cy = std::cos(yaw), sy = std::sin(yaw);
    const float cp = std::cos(pitch), sp = std::sin(pitch);

    // forward (look) com yaw 0 = (0,0,-1); right com yaw 0 = (1,0,0)
    const Vector3 look{ -cp * sy, sp, -cp * cy };
    const Vector3 right{ cy, 0.f, -sy };
    // up = right x look
    const Vector3 up{
        right.y * look.z - right.z * look.y,
        right.z * look.x - right.x * look.z,
        right.x * look.y - right.y * look.x
    };

    const float f = 1.f / std::tan(mathx::DegToRad(fovDeg) * 0.5f);

    Matrix4x4 vm{};
    vm.m[0][0] = right.x * f / aspect;
    vm.m[0][1] = right.y * f / aspect;
    vm.m[0][2] = right.z * f / aspect;
    vm.m[1][0] = up.x * f;
    vm.m[1][1] = up.y * f;
    vm.m[1][2] = up.z * f;
    vm.m[3][0] = look.x;
    vm.m[3][1] = look.y;
    vm.m[3][2] = look.z;
    vm.m[3][3] = 0.001f;
    return vm;
}

void TestWorldToScreen() {
    std::printf("[1] WorldToScreen\n");

    const float w = 1920.f, h = 1080.f;
    const Matrix4x4 vm = MakeView(0.f, 0.f, 70.f, w / h);

    Vector2 center{};
    Check(WorldToScreen(Vector3{ 0.f, 0.f, -100.f }, center, vm, w, h), "ponto na frente projeta");
    CheckNear(center.x, w * 0.5f, 2.f, "ponto no eixo -> centro X");
    CheckNear(center.y, h * 0.5f, 2.f, "ponto no eixo -> centro Y");

    Vector2 right{};
    Check(WorldToScreen(Vector3{ 40.f, 0.f, -100.f }, right, vm, w, h), "ponto a direita projeta");
    Check(right.x > center.x + 10.f, "ponto a direita cai a direita do centro");

    Vector2 up{};
    Check(WorldToScreen(Vector3{ 0.f, 40.f, -100.f }, up, vm, w, h), "ponto acima projeta");
    Check(up.y < center.y - 10.f, "ponto acima cai acima do centro (y cresce pra baixo)");

    Vector2 behind{};
    Check(!WorldToScreen(Vector3{ 0.f, 0.f, 100.f }, behind, vm, w, h), "ponto atras nao projeta");

    // 45 graus pra direita: offset esperado = tan(45)/tan(35) * h/2
    const float dist = 100.f;
    const float ang = mathx::DegToRad(45.f);
    Vector2 diag{};
    Check(WorldToScreen(Vector3{ std::sin(ang) * dist, 0.f, -std::cos(ang) * dist }, diag, vm, w, h),
          "45 graus projeta");

    const float expected = std::tan(ang) / std::tan(mathx::DegToRad(70.f) * 0.5f) * h * 0.5f;
    CheckNear(diag.x - w * 0.5f, expected, 3.f, "offset horizontal bate com tan(fov)");
    CheckNear(diag.x - w * 0.5f, std::tan(ang) / mathx::RadiansPerPixel(70.f, h), 3.f,
              "offset = tan(angulo) / rad-por-pixel");
}

void TestRadiansPerPixel() {
    std::printf("[2] radianos por pixel\n");

    const float fov = 70.f, height = 1080.f, width = 1920.f;

    const float expected = 2.f * std::tan(mathx::DegToRad(fov) * 0.5f) / height;
    CheckNear(mathx::RadiansPerPixel(fov, height), expected, 1e-7f, "derivada exata 2*tan(fov/2)/H");

    // o mesmo angulo, projetado na horizontal e na vertical, tem que dar o mesmo
    // numero de pixels (aspect cancela): e isso que permite uma conversao unica
    const Matrix4x4 vm = MakeView(0.f, 0.f, fov, width / height);
    const float tanOffset = 0.35f;                 // ~19 graus
    const float d = 200.f;

    Vector2 horizontal{}, vertical{};
    Check(WorldToScreen(Vector3{ tanOffset * d, 0.f, -d }, horizontal, vm, width, height), "proj horizontal");
    Check(WorldToScreen(Vector3{ 0.f, tanOffset * d, -d }, vertical, vm, width, height), "proj vertical");

    const float pxHorizontal = horizontal.x - width * 0.5f;
    const float pxVertical = height * 0.5f - vertical.y;
    CheckNear(pxHorizontal, pxVertical, 0.5f, "mesmo angulo = mesmo offset em px nos dois eixos");
    CheckNear(pxHorizontal, tanOffset / mathx::RadiansPerPixel(fov, height), 1.f,
              "px = tan(angulo)/rad-por-pixel");

    CheckNear(mathx::RadiansPerPixel(0.f, height), 0.f, 1e-9f, "fov invalido -> 0");
    CheckNear(mathx::RadiansPerPixel(70.f, 0.f), 0.f, 1e-9f, "altura invalida -> 0");
    CheckNear(mathx::CountsPerPixel(fov, height, 0.f), 0.f, 1e-9f, "sem calibracao -> 0");

    const float cpp = mathx::CountsPerPixel(fov, height, 0.0035f);
    Check(cpp > 0.f && cpp < 40.f, "counts/px dentro do clamp");
    CheckNear(cpp, expected / 0.0035f, 1e-6f, "counts/px = rad-por-px / rad-por-count");
}

// simulacao do laco do aim, fiel ao aim.cpp: o resto fracionario fica no
// acumulador e o delta e truncado (static_cast<int>), nao arredondado
struct AimSim {
    float radPerCount = 0.0035f;   // sensibilidade "do jogo"
    float fov = 70.f;
    float height = 1080.f;
    float errorPx = 60.f;          // alvo a direita do centro
    float accum = 0.f;

    float Step(float gain, float countsPerPx) {
        float step = errorPx * gain * countsPerPx + accum;
        const int counts = static_cast<int>(step);
        accum = step - static_cast<float>(counts);

        const float radPerPx = mathx::RadiansPerPixel(fov, height);
        errorPx -= static_cast<float>(counts) * radPerCount / radPerPx;
        return static_cast<float>(counts);
    }
};

void TestAimLoop() {
    std::printf("[3] laco do aim\n");

    // --- calibrado: converge, nao passa do alvo ---
    {
        AimSim sim;
        const float cpp = mathx::CountsPerPixel(sim.fov, sim.height, sim.radPerCount);
        const float farGain = 0.55f / 4.f;   // default do menu
        float worst = sim.errorPx;
        int ticks = 0;

        while (std::fabs(sim.errorPx) > 1.f && ticks < 300) {
            const float gain = std::fabs(sim.errorPx) <= 18.f ? 0.7f : farGain;
            sim.Step(gain, cpp);
            worst = std::fmin(worst, sim.errorPx);
            ++ticks;
        }

        Check(std::fabs(sim.errorPx) <= 1.f, "calibrado converge pra menos de 1 px");
        Check(worst > -6.f, "calibrado nao ultrapassa o alvo (sem overshoot)");
        Check(ticks < 90, "calibrado chega em menos de 90 ticks");
        std::printf("      calibrado: %d ticks, sobra %.2f px\n", ticks, sim.errorPx);
    }

    // --- sem calibracao (1px = 1count) num jogo que gira 3px por count ---
    {
        AimSim sim;
        sim.radPerCount = 0.0105f;   // 3x o chute
        float worst = sim.errorPx;
        int flips = 0;
        float last = sim.errorPx;

        for (int i = 0; i < 40; ++i) {
            const float gain = std::fabs(sim.errorPx) <= 18.f ? 0.35f : 0.55f / 4.f;
            sim.Step(gain, 1.f);   // <- o chute de 1px = 1count
            if ((last > 0.f) != (sim.errorPx > 0.f) && std::fabs(sim.errorPx) > 0.5f)
                ++flips;
            worst = std::fmin(worst, sim.errorPx);
            last = sim.errorPx;
        }

        Check(flips > 0 || worst < -1.f, "sem calibracao o laco passa do alvo (regressao do bug)");
        std::printf("      sem calibracao: %d inversoes de sinal, pior %.1f px\n", flips, worst);
    }

    // --- FOV muda (mira ADS): a conversao tem que se adaptar ---
    {
        const float radPerCount = 0.0035f;
        AimSim sim;
        sim.radPerCount = radPerCount;
        sim.errorPx = 40.f;

        sim.fov = 35.f;   // entrou em ADS
        const float cpp = mathx::CountsPerPixel(sim.fov, sim.height, radPerCount);
        const float pxPerCount = radPerCount / mathx::RadiansPerPixel(sim.fov, sim.height);

        int ticks = 0;
        while (std::fabs(sim.errorPx) > pxPerCount && ticks < 300) {
            sim.Step(0.7f, cpp);
            ++ticks;
        }
        // em ADS 1 count vale ~6 px: o limite e a resolucao fisica do mouse
        Check(std::fabs(sim.errorPx) <= pxPerCount,
              "ADS (fov 35) converge ate a resolucao do mouse com a conversao recalculada");
        std::printf("      ADS: %d ticks, sobra %.2f px (1 count = %.2f px)\n", ticks, sim.errorPx,
                    pxPerCount);
    }
}

// o write de posicao do voo nunca pode andar mais que maxStepStuds: e o que
// separa "voar" de "tomar Disconnect 277" no modo posicao
void TestFlyWriteCap() {
    std::printf("[7] voo: teto por write (disconnect 277)\n");

    const float maxStep = 1.2f;
    const float hz = 60.f;
    const float speed = 300.f;   // usuario colocou 300 no slider
    const Vector3 dir{ 1.f, 0.f, 0.f };

    Vector3 pos{};
    float worst = 0.f;

    for (int i = 0; i < 600; ++i) {   // 10 s
        const float dt = 1.f / hz;
        const float step = std::min(speed * dt, maxStep);
        const Vector3 next = mathx::StepAlong(pos, dir, step);
        worst = std::fmax(worst, (next - pos).Length());
        pos = next;
    }

    Check(worst <= maxStep + 1e-4f, "nenhum write anda mais que maxStepStuds");
    CheckNear(pos.x, maxStep * hz * 10.f, 2.f, "velocidade efetiva = passo * writes/s (72 studs/s)");
    std::printf("      pior passo %.2f studs, velocidade efetiva %.0f studs/s\n", worst,
                pos.x / 10.f);

    // sem o teto, o mesmo slider de 300 studs/s andaria 5 studs por write
    const float unclamped = speed / hz;
    Check(unclamped > maxStep, "sem teto o write seria um teleporte de 5 studs por frame");
}

void TestLookRotation() {
    std::printf("[6] LookRotation (mira por camera)\n");

    const Vector3 eye{ 12.f, 5.f, -3.f };
    const Vector3 target{ -40.f, 9.f, 60.f };

    float m[9]{};
    Check(mathx::LookRotation(eye, target, m), "gera matriz olhando pro alvo");

    // look recuperado da matriz tem que ser a direcao normalizada eye->target
    Vector3 want{ target.x - eye.x, target.y - eye.y, target.z - eye.z };
    const float len = want.Length();
    want.x /= len; want.y /= len; want.z /= len;

    const Vector3 got{ -m[2], -m[5], -m[8] };
    CheckNear(got.x, want.x, 1e-5f, "look.x bate");
    CheckNear(got.y, want.y, 1e-5f, "look.y bate");
    CheckNear(got.z, want.z, 1e-5f, "look.z bate");

    // ortonormal: linhas e colunas unitarias e ortogonais
    const Vector3 right{ m[0], m[3], m[6] };
    const Vector3 up{ m[1], m[4], m[7] };
    CheckNear(right.Length(), 1.f, 1e-5f, "right unitario");
    CheckNear(up.Length(), 1.f, 1e-5f, "up unitario");
    CheckNear(right.x * up.x + right.y * up.y + right.z * up.z, 0.f, 1e-5f, "right . up = 0");
    CheckNear(right.x * got.x + right.y * got.y + right.z * got.z, 0.f, 1e-5f, "right . look = 0");
    CheckNear(up.x * got.x + up.y * got.y + up.z * got.z, 0.f, 1e-5f, "up . look = 0");

    // CameraAngles le de volta um angulo coerente com a direcao
    float yaw = 0.f, pitch = 0.f;
    Check(mathx::CameraAngles(m, yaw, pitch), "CameraAngles le a matriz gerada");
    CheckNear(std::sin(pitch), want.y, 1e-4f, "pitch reconstroi a componente vertical");
    CheckNear(std::cos(pitch) * -std::sin(yaw), want.x, 1e-4f, "yaw reconstroi x");
    CheckNear(std::cos(pitch) * -std::cos(yaw), want.z, 1e-4f, "yaw reconstroi z");

    // inversa: yaw/pitch -> matriz -> CameraAngles tem que voltar nos mesmos angulos
    for (float yaw : { 0.f, 1.2f, -2.4f, 3.0f }) {
        for (float pitch : { 0.f, 0.6f, -0.9f }) {
            float rot[9]{};
            Check(mathx::RotationFromYawPitch(yaw, pitch, rot), "RotationFromYawPitch gera matriz");

            float y2 = 0.f, p2 = 0.f;
            Check(mathx::CameraAngles(rot, y2, p2), "CameraAngles le de volta");

            CheckNear(mathx::WrapPi(y2 - yaw), 0.f, 1e-4f, "round-trip do yaw");
            CheckNear(p2, pitch, 1e-4f, "round-trip do pitch");
        }
    }

    // alvo em cima da camera: sem direcao definida
    float bad[9]{};
    Check(!mathx::LookRotation(eye, eye, bad), "eye == target nao gera matriz");

    // olhando reto pra cima: right degenera e deve recusar (evita NaN)
    Check(!mathx::LookRotation(Vector3{ 0.f, 0.f, 0.f }, Vector3{ 0.f, 10.f, 0.f }, bad),
          "olhar reto pra cima e recusado");
}

void TestFly() {
    std::printf("[4] voo\n");

    CheckNear(mathx::ClampDt(0.5f, 0.05f), 0.05f, 1e-6f, "dt de frame travado corta em 50 ms");
    CheckNear(mathx::ClampDt(0.004f, 0.05f), 0.004f, 1e-6f, "dt normal passa intacto");
    CheckNear(mathx::ClampDt(0.f, 0.05f), 0.004f, 1e-6f, "dt zero vira o default");
    CheckNear(mathx::ClampDt(-1.f, 0.05f), 0.004f, 1e-6f, "dt negativo vira o default");

    // 1 segundo a 60 studs/s = 60 studs
    Vector3 pos{};
    const Vector3 dir{ 1.f, 0.f, 0.f };
    const float dt = mathx::ClampDt(0.004f, 0.05f);
    for (int i = 0; i < 250; ++i)
        pos = mathx::FlyStep(pos, dir, 60.f, dt);

    CheckNear(pos.x, 60.f, 1.5f, "60 studs/s por 1 s anda ~60 studs");
    CheckNear(pos.y, 0.f, 1e-6f, "sem componente vertical nao muda altura");
    CheckNear(pos.z, 0.f, 1e-6f, "eixo z intacto");

    // direcao normalizada: diagonal nao pode ser mais rapida
    const Vector3 diagonal{ 0.7071f, 0.f, 0.7071f };
    Vector3 d{};
    for (int i = 0; i < 250; ++i)
        d = mathx::FlyStep(d, diagonal, 60.f, dt);
    CheckNear(d.Length(), 60.f, 1.5f, "diagonal normalizada anda a mesma velocidade");
}

void TestConfig() {
    std::printf("[5] config.json\n");

    // roda num diretorio temporario: o teste nao pode comer o config do usuario
    char previous[512]{};
    if (getcwd(previous, sizeof(previous)) == nullptr)
        std::snprintf(previous, sizeof(previous), ".");

    const char* dir = "build/test_cfg";
    std::system("mkdir -p build/test_cfg");
    if (chdir(dir) != 0) {
        std::printf("  [skip] nao consegui entrar em %s\n", dir);
        return;
    }

    cfg::Settings a{};
    a.espParts = true;
    a.partsFilter = "coin,cash,crate";
    a.crosshair = true;
    a.crosshairSize = 12.f;
    a.aim.snapPx = 9.f;
    a.aim.key = 'V';
    a.fire.burst = 4;
    a.fly.hoverOnIdle = false;
    a.fly.speed = 120.f;
    a.fly.mode = cfg::kFlyPosition;
    a.speed.enabled = true;
    a.speed.walkSpeed = 88.f;
    a.teleport.smooth = true;
    a.teleport.stepStuds = 2.5f;

    Check(cfg::Save(a), "save escreveu o arquivo");

    cfg::Settings b{};
    b.partsFilter = "nao-deve-ficar";
    Check(cfg::Load(b), "load leu o arquivo");

    Check(b.partsFilter == "coin,cash,crate", "string com virgula sobrevive ao round-trip");
    Check(b.espParts, "espParts voltou");
    Check(b.crosshair, "crosshair voltou");
    CheckNear(b.crosshairSize, 12.f, 1e-4f, "crosshairSize voltou");
    CheckNear(b.aim.snapPx, 9.f, 1e-4f, "aimSnapPx voltou");
    Check(b.aim.key == 'V', "aimKey voltou");
    Check(b.fire.burst == 4, "fireBurst voltou");
    Check(!b.fly.hoverOnIdle, "flyHoverOnIdle voltou");
    CheckNear(b.fly.speed, 120.f, 1e-4f, "flySpeed voltou");
    Check(b.fly.mode == cfg::kFlyPosition, "flyMode voltou");
    Check(b.speed.enabled && std::fabs(b.speed.walkSpeed - 88.f) < 1e-4f, "speed voltou");
    Check(b.teleport.smooth && std::fabs(b.teleport.stepStuds - 2.5f) < 1e-4f, "teleport voltou");
    Check(cfg::Same(a, b), "Same() diz que o round-trip e identico");

    // mudanca detectada (base do auto-save)
    b.aim.snapPx = 20.f;
    Check(!cfg::Same(a, b), "Same() detecta mudanca (auto-save depende disso)");

    chdir(previous);
}

} // namespace

int main() {
    std::printf("== testes offline roblox-external ==\n");

    TestWorldToScreen();
    TestRadiansPerPixel();
    TestAimLoop();
    TestFly();
    TestFlyWriteCap();
    TestLookRotation();
    TestConfig();

    std::printf("== %d checagens, %d falha(s) ==\n", g_checks, g_failures);
    return g_failures == 0 ? 0 : 1;
}
