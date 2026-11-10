#pragma once
#include "../config.h"

class AimAssist;
class CameraHack;
class Detector;
class Esp;
class Fly;
class Magnet;
class Speed;
class Teleport;
class MemView;
class Overlay;
class Trigger;

namespace menu {

// desenha o menu. *open controla visibilidade (INSERT).
void Draw(cfg::Settings& settings, Esp& esp, Overlay& overlay, Detector& detector,
          MemView& memView, AimAssist& aim, const Trigger& trigger, const Fly& fly,
          CameraHack& cameraHack, Magnet& magnet, Speed& speed, Teleport& teleport,
          bool* open);

} // namespace menu
