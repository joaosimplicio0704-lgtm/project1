#pragma once

// ============================================================
// Log em arquivo (roblox-external.log, ao lado do .exe).
//
// O console some quando o .exe e aberto por duplo clique, e sem Windows
// aqui nao da pra depurar no cliente: entao todo evento que importa
// (attach, reattach, handle read-only, write recusado, panic, save)
// vai com timestamp pro arquivo. Thread-safe (o leitor loga de dentro
// da thread dele).
// ============================================================

namespace applog {

// abre o arquivo em modo append; chamar uma vez no inicio do main
void Init(const char* file = "roblox-external.log");

void Line(const char* fmt, ...);

void Shutdown();

} // namespace applog
