#!/usr/bin/env python3
"""
preview.py — renderiza o .rbxlx gerado para PNG, para VER o jogo.

Não é o Roblox: é uma projeção isométrica com caixas de verdade (8 vértices,
3 faces visíveis) e ordenação por profundidade. Serve para responder "isso
parece um jogo?" olhando, em vez de adivinhar pelos números.

Uso:
    python3 tools/preview.py                    # hub
    python3 tools/preview.py --biome meadow     # um bioma
    python3 tools/preview.py --all              # um PNG por bioma
    python3 tools/preview.py --world            # arquipélago inteiro
"""

import argparse
import math
import os
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP_FILE = os.path.join(ROOT, "build", "EggTycoon.rbxlx")
OUT_DIR = os.path.join(ROOT, "build", "preview")

# peças que estragam o enquadramento: são enormes e ficam embaixo de tudo
IGNORE_BOUNDS = {"Ocean", "SeaFloor", "BaseUnder"}


def parse_rbxlx(path):
    tree = ET.parse(path)
    root = tree.getroot()

    def props(item):
        out = {}
        node = item.find("Properties")
        if node is None:
            return out
        for prop in node:
            out[prop.get("name")] = (prop.tag, prop)
        return out

    def num(el, default=0.0):
        try:
            return float(el.text)
        except (TypeError, ValueError):
            return default

    def vec(el, tags=("X", "Y", "Z")):
        return tuple(num(el.find(t)) for t in tags)

    parts = []
    lighting = {}

    def walk(item, ancestors):
        class_name = item.get("class")
        p = props(item)
        name = p["Name"][1].text if "Name" in p else class_name
        path = "/".join(ancestors + [name or ""])

        if class_name in ("Part", "SpawnLocation", "WedgePart", "MeshPart"):
            info = {"name": name, "class": class_name, "path": path}
            if "size" in p:
                info["size"] = vec(p["size"][1])
            if "CFrame" in p:
                cf = p["CFrame"][1]
                info["pos"] = vec(cf)
                try:
                    info["rot"] = (
                        (float(cf.find("R00").text), float(cf.find("R01").text), float(cf.find("R02").text)),
                        (float(cf.find("R10").text), float(cf.find("R11").text), float(cf.find("R12").text)),
                        (float(cf.find("R20").text), float(cf.find("R21").text), float(cf.find("R22").text)),
                    )
                except (AttributeError, TypeError, ValueError):
                    info["rot"] = None
            elif "Position" in p:
                info["pos"] = vec(p["Position"][1])

            if "Color3uint8" in p:
                packed = int(num(p["Color3uint8"][1]))
                info["color"] = (packed & 0xFF, (packed >> 8) & 0xFF, (packed >> 16) & 0xFF)
            else:
                info["color"] = (163, 162, 165)

            info["material"] = int(num(p["Material"][1])) if "Material" in p else 256
            # No XML do Roblox a propriedade Shape sai em MINUSCULO ("shape").
            # Eu lia "Shape" e caia no default: bolas e cilindros eram
            # desenhados como caixas, e o mapa inteiro parecia feito de blocos.
            shape_key = p.get("shape") or p.get("Shape")
            info["shape"] = int(num(shape_key[1])) if shape_key else 1
            info["transparency"] = num(p["Transparency"][1]) if "Transparency" in p else 0.0

            if "pos" in info and "size" in info:
                parts.append(info)

        # Lighting: o render precisa disto para mostrar a luz REAL do jogo.
        # Sem isso eu ajustava brilho no escuro, porque o render usava fator
        # fixo e todo valor parecia igual.
        if class_name == "Lighting":
            for key in ("Brightness", "ExposureCompensation", "Ambient",
                        "OutdoorAmbient", "EnvironmentDiffuseScale"):
                if key in p:
                    el = p[key][1]
                    if key in ("Brightness", "ExposureCompensation", "EnvironmentDiffuseScale"):
                        lighting[key] = num(el)
                    else:
                        lighting[key] = vec(el, ("R", "G", "B"))

        for child in item.findall("Item"):
            walk(child, ancestors + [name or class_name])

    for child in root.findall("Item"):
        walk(child, [])

    return parts, lighting


class Camera:
    """Isométrica com yaw/pitch. Projeta (x,y,z) -> (tela_x, tela_y, profundidade)."""

    def __init__(self, yaw_deg=40, pitch_deg=30):
        self.cy, self.sy = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
        self.cp, self.sp = math.cos(math.radians(pitch_deg)), math.sin(math.radians(pitch_deg))
        self.cx = self.cy_ = 0.0
        self.scale = 1.0
        self.ox = self.oy = 0.0

    def project(self, x, y, z):
        # gira em Y, depois inclina: tela_x anda com rx, tela_y com rz e y.
        rx = x * self.cy - z * self.sy
        rz = x * self.sy + z * self.cy
        screen_y = rz * self.sp - y * self.cp
        return (rx, screen_y, rz)

    def fit(self, parts, width, height, margin=0.9):
        minx = miny = minz = float("inf")
        maxx = maxy = maxz = float("-inf")
        for p in parts:
            if p["name"] in IGNORE_BOUNDS:
                continue
            x, y, z = p["pos"]
            sx, sy, sz = p["size"]
            minx, maxx = min(minx, x - sx / 2), max(maxx, x + sx / 2)
            miny, maxy = min(miny, y - sy / 2), max(maxy, y + sy / 2)
            minz, maxz = min(minz, z - sz / 2), max(maxz, z + sz / 2)
        if minx == float("inf"):
            return self

        # projeta os 8 cantos da caixa para achar a extensão em tela
        pts = []
        for x in (minx, maxx):
            for y in (miny, maxy):
                for z in (minz, maxz):
                    pts.append(self.project(x, y, z))
        sx = [p[0] for p in pts]
        sy = [p[1] for p in pts]
        span_x = max(sx) - min(sx)
        span_y = max(sy) - min(sy)
        if span_x <= 0 or span_y <= 0:
            span_x = span_y = 100

        self.scale = min(width * margin / span_x, height * margin / span_y)
        self.ox = width / 2 - (min(sx) + max(sx)) / 2 * self.scale
        self.oy = height / 2 - (min(sy) + max(sy)) / 2 * self.scale
        return self

    def to_screen(self, x, y, z):
        px, py, pz = self.project(x, y, z)
        return (self.ox + px * self.scale, self.oy + py * self.scale, pz)


def shade(color, f):
    return tuple(max(0, min(255, int(c * f))) for c in color)


def lighting_gain(lighting):
    """Fator de brilho derivado do Lighting real do jogo.

    O render usava 1.08 / 0.74 / 0.56 fixos na face de cima, lado e frente.
    Assim TODO valor de Brightness parecia igual, e ajustar luz virava chute.
    Aqui o ganho sai de Brightness + ExposureCompensation do build: subir o
    brilho no World.luau agora ESTOURA o render do mesmo jeito que estoura
    a tela do jogador.
    """
    if not lighting:
        return 1.0
    brightness = lighting.get("Brightness", 2.0)
    exposure = lighting.get("ExposureCompensation", 0.0)
    # Referência neutra = PADRÃO DO ROBLOX: Brightness 2.0 + Exposure 0.0 =
    # 1.0. Ancorar no padrão da engine é o único jeito de o número significar
    # algo: ganho 1.0 é "o jogo parece o Roblox normal".
    #
    # AQUI ESTAVA O MEU ERRO: eu limitava o ganho em 1.0 "para não estourar",
    # e com isso o render nunca mostrava a saturação. O jogo de verdade
    # estourava em branco na tela do jogador enquanto o preview dizia que
    # estava tudo certo. Um preview que não pode mostrar o defeito não serve
    # para validar nada.
    #
    # Agora o ganho é livre na parte de cima: se a luz do build estiver
    # forte, o render ESTOURA igual ao jogo, e o problema aparece antes de
    # eu commitar.
    return max(0.25, min(3.0, (brightness / 2.0) * (1.0 + exposure)))


def render(parts, out_path, yaw=40, pitch=30, width=1600, height=900, label=None,
           sky_top=(120, 180, 238), sky_bottom=(212, 236, 252), show_ground=True, zoom=1.0,
           lighting=None):
    cam = Camera(yaw, pitch).fit(parts, width, height)
    cam.scale *= zoom
    gain = lighting_gain(lighting)

    img = Image.new("RGB", (width, height))
    d = ImageDraw.Draw(img)
    for y in range(height):
        t = y / height
        d.line([(0, y), (width, y)],
               fill=tuple(int(sky_top[i] + (sky_bottom[i] - sky_top[i]) * t) for i in range(3)))

    # LIMITE CONHECIDO DESTE RENDERIZADOR (não do jogo):
    # é painter's algorithm puro, sem z-buffer. Duas peças coplanares (ex.: os
    # blocos de chão do bioma, que se sobrepõem de propósito) aparecem com uma
    # "costura" escura: o algoritmo desenha a FAIXA LATERAL de um bloco por
    # cima do topo do vizinho. No Roblox isso não existe — o z-buffer resolve.
    # Confirmei isolando 49 células: no render ficam listras; no jogo é chão
    # liso. Se a listra incomodar aqui, é do renderizador, não do mapa.
    #
    # Painter's algorithm ingênuo falha com peças grandes: o anel de terra
    # (430 de lado) é desenhado por cima da grama porque o centro dele está
    # mais perto da câmera. Chão é desenhado primeiro, sempre; o resto por
    # profundidade de centro.
    floors, items = [], []
    for p in parts:
        if p["transparency"] >= 0.93:
            continue
        if p["name"] in IGNORE_BOUNDS and not show_ground:
            continue
        x, y, z = p["pos"]
        sx, sy, sz = p["size"]
        depth = cam.project(x, y, z)[2]
        # Chão = laje: fina na VERTICAL e larga nos dois eixos horizontais.
        #
        # A regra antiga usava "extensão em qualquer eixo > 90". Isso deixava
        # a ArenaFloor (91.8 de lado) como chão por 1.7 stud, mas as células
        # de terreno (21 de lado) ficavam como objeto e eram pintadas DEPOIS,
        # por cima da arena — a arena existia no build e não aparecia no
        # render. O caso não era o limiar estar no valor errado: era a regra
        # olhar o eixo errado.
        #
        # Fina na vertical (sy) separa laje de tronco de árvore e de parede.
        # Larga nos dois horizontais separa laje de poste e de cerca.
        # Ordenar por face de cima resolve terreno em degraus: a célula mais
        # alta é pintada depois da mais baixa.
        # Espessura e extensão medidas NO MUNDO, não no tamanho local.
        #
        # Um cilindro deitado (o chão do bioma, os anéis de terra) tem a
        # espessura no X LOCAL: size = (7, 203.7, 203.7) com a rotação
        # trocando X por Y. Lendo o `size` cru, sy=203.7 parecia uma parede
        # de 200 studs e a peça ia para "objetos" — era pintada por último e
        # cobria a arena inteira. Medindo no mundo dá 203.7 x 7 x 203.7:
        # laje fina e larga, como no jogo.
        rot = p.get("rot")
        if rot:
            extent_x = abs(rot[0][0]) * sx + abs(rot[0][1]) * sy + abs(rot[0][2]) * sz
            extent_y = abs(rot[1][0]) * sx + abs(rot[1][1]) * sy + abs(rot[1][2]) * sz
            extent_z = abs(rot[2][0]) * sx + abs(rot[2][1]) * sy + abs(rot[2][2]) * sz
        else:
            extent_x, extent_y, extent_z = sx, sy, sz
        # A face de cima da laje: o centro MAIS a meia-espessura no mundo.
        # O cilindro deitado tem a espessura no X local, então metade dele
        # fica acima do centro e metade abaixo; extent_y/2 é exatamente a
        # meia-espessura no mundo depois de aplicada a rotação.
        # LAJE = espessura menor que METADE de cada lado horizontal.
        #
        # Não serve limiar absoluto: as células de terreno têm 10 de lado
        # (e 3.2 de espessura) e um limiar de "> 15" as jogava para objetos,
        # onde eram pintadas por profundidade — as células da frente cobriam
        # a arena, que fica no meio delas. Proporção é o que define laje, em
        # qualquer escala: chão do bioma (203x7), arena (92x1.4), célula
        # (10x3.2) entram; tronco, poste e pedra (mais alto que largo) não.
        if extent_y < extent_x * 0.5 and extent_y < extent_z * 0.5 and extent_x > 6 and extent_z > 6:
            floors.append((y + extent_y * 0.5, depth, p))
        else:
            items.append((depth, p))

    # ORDEM DE PINTURA
    #
    # Painter's algorithm adaptado a um mapa feito de camadas horizontais.
    #
    # Histórico de tentativas (todas quebraram em algo real):
    #   1. só profundidade do centro — a Base da ilha (centro 17 studs
    #      abaixo da arena, mas mais perto da câmera) cobria a arena.
    #   2. só face de cima — as 976 células de terreno vinham depois por
    #      causa do desempate e cobriam a arena.
    #   3. camadas de altura fixas (floor(y/6)) — a praia caía na mesma
    #      camada das árvores e o bioma virava um disco liso.
    #   4. dois grupos (subsolo/superfície) por profundidade — o GroundDisc,
    #      que é um CILINDRO DEITADO de 200 de diâmetro em Y 2.9, tem o
    #      centro no subsolo e era pintado por cima da arena em Y 5.2.
    #
    # O que resolve: chão é uma pilha de lajes, então se ordena por FACE DE
    # CIMA — a laje mais alta cobre a mais baixa, é exatamente o que se vê
    # no jogo. Objetos (tronco, pedra, monstro) se ordenam por PROFUNDIDADE,
    # porque ficam em pé e não se sobrepõem verticalmente.
    #
    # A arena fica em 5.9 e o GroundDisc em 3.24: arena depois, arena
    # aparece. O terreno em degraus (4.8) fica abaixo da arena e é coberto
    # por ela, como no Roblox.
    floors.sort(key=lambda t: (t[0], t[1]))
    items.sort(key=lambda t: t[0])
    ordered = [p for _, _, p in floors] + [p for _, p in items]
    for p in ordered:
        x, y, z = p["pos"]
        sx, sy, sz = p["size"]
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        rot = p.get("rot")

        # 8 cantos
        c = {}
        for i, (ox, oy, oz) in enumerate([
            (-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
            (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1),
        ]):
            lx, ly, lz = ox * hx, oy * hy, oz * hz
            if rot:
                rx = rot[0][0] * lx + rot[0][1] * ly + rot[0][2] * lz
                ry = rot[1][0] * lx + rot[1][1] * ly + rot[1][2] * lz
                rz = rot[2][0] * lx + rot[2][1] * ly + rot[2][2] * lz
                lx, ly, lz = rx, ry, rz
            px, py, _ = cam.to_screen(x + lx, y + ly, z + lz)
            c[i] = (float(px), float(py))

        base = p["color"]
        glow = p.get("material") == 288
        alpha = 1.0 - p["transparency"]

        # O ganho vem do Lighting do build (ver lighting_gain).
        # Neon fica de fora: brilha sozinho, não depende do sol.
        # O shade já trava em 255: com ganho alto, a cor vira branco puro
        # exatamente como no Roblox.
        top = shade(base, 1.08 if glow else 1.02 * gain)
        left = shade(base, 0.86 if glow else 0.74 * gain)
        right = shade(base, 0.76 if glow else 0.56 * gain)

        # topo (4,5,6,7) / esquerda (0,3,7,4) / direita (1,2,6,5)
        if p["shape"] == 0:  # Ball: esfera ou disco achatado
            cx, cyTop, _ = cam.to_screen(x, y + hy, z)
            _, cyBot, _ = cam.to_screen(x, y - hy, z)
            r = max(1.0, hx * cam.scale * 1.05)
            # Altura da elipse: esfera vista de cima continua sendo círculo
            # (ry ~ r); disco deitado (hy << hx) vira elipse achatada pelo
            # ângulo da câmera — um disco de 92 de diâmetro visto a 30 graus
            # ocupa 92*sin(30) = 46 studs na vertical. Antes o ry vinha da
            # ESPESSURA, então o chão da arena saía como faixa de 6 px e
            # sumia no meio do mato: a arena existia no build e não aparecia.
            flatten = hy / max(hx, 0.0001)
            ry = max(1.0, r * (cam.sp + (1.0 - cam.sp) * min(1.0, flatten)))
            # BOLA ACHATADA PRECISA DE LATERAL.
            # Sem isto, um disco de 92 de diâmetro e 1.4 de espessura (o chão
            # da arena, os anéis de terra) virava uma elipse de 2 px de altura
            # e sumia do render — a arena existia no build e não aparecia.
            # Só entra em bola achatada (hy bem menor que hx): esfera de
            # olho de monstro continua sendo só a elipse.
            if hy < hx * 0.6 and cyBot - cyTop > 1:
                fill_left = tuple(int(v) for v in (top if glow else left))
                d.rectangle([float(cx - r), float(cyTop), float(cx + r), float(cyBot)],
                            fill=fill_left)
                d.ellipse([float(cx - r), float(cyBot - ry), float(cx + r), float(cyBot + ry)],
                          fill=fill_left)
            d.ellipse([float(cx - r), float(cyTop - ry), float(cx + r), float(cyTop + ry)],
                      fill=tuple(int(v) for v in (top if glow else left)))
            d.ellipse([float(cx - r * 0.92), float(cyTop - ry * 0.92),
                       float(cx - r * 0.15), float(cyTop - ry * 0.1)],
                      fill=tuple(int(v) for v in shade(top, 1.15)))
        elif p["shape"] == 2:  # Cylinder: eixo no X local
            # Desenhar como caixa fazia o disco da praia virar um "muro".
            # Amostra o círculo e projeta cada ponto: como a câmera é
            # ortográfica, um disco vira uma elipse de verdade.
            def ring(xoff):
                pts = []
                for k in range(28):
                    a = 2 * math.pi * k / 28
                    lx, ly, lz = xoff, math.cos(a) * hy, math.sin(a) * hz
                    if rot:
                        lx, ly, lz = (
                            rot[0][0] * lx + rot[0][1] * ly + rot[0][2] * lz,
                            rot[1][0] * lx + rot[1][1] * ly + rot[1][2] * lz,
                            rot[2][0] * lx + rot[2][1] * ly + rot[2][2] * lz,
                        )
                    qx, qy, _ = cam.to_screen(x + lx, y + ly, z + lz)
                    pts.append((float(qx), float(qy)))
                return pts

            # As duas tampas do cilindro; a de cima e a que tem menor y na tela
            capA, capB = ring(hx), ring(-hx)
            ya = sum(q[1] for q in capA) / len(capA)
            yb = sum(q[1] for q in capB) / len(capB)
            near, far = (capA, capB) if ya <= yb else (capB, capA)
            # costado: faixa entre as duas bordas
            d.polygon(near + far[::-1], fill=tuple(int(v) for v in left))
            d.polygon(near, fill=tuple(int(v) for v in top))
            if len(near) > 6:
                cx2 = sum(q[0] for q in near) / len(near)
                cy2 = sum(q[1] for q in near) / len(near)
                inner = [(cx2 + (q[0] - cx2) * 0.78, cy2 + (q[1] - cy2) * 0.78) for q in near]
                d.polygon(inner, fill=tuple(int(v) for v in shade(top, 1.06)))
        else:
            d.polygon([c[4], c[5], c[6], c[7]], fill=tuple(int(v) for v in top))
            d.polygon([c[0], c[3], c[7], c[4]], fill=tuple(int(v) for v in left))
            d.polygon([c[1], c[2], c[6], c[5]], fill=tuple(int(v) for v in right))

    if label:
        d.rectangle([0, 0, width, 38], fill=(18, 16, 26))
        d.text((16, 13), label, fill=(240, 240, 250))

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img = img.filter(ImageFilter.SMOOTH)
    img.save(out_path)
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--biome")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--world", action="store_true")
    ap.add_argument("--yaw", type=float, default=40)
    ap.add_argument("--pitch", type=float, default=30)
    ap.add_argument("--zoom", type=float, default=1.0, help="multiplica o enquadramento")
    ap.add_argument("--no-ocean", action="store_true", help="esconde Ocean/SeaFloor")
    args = ap.parse_args()

    if not os.path.exists(MAP_FILE):
        print("rode npm run build primeiro", file=sys.stderr)
        return 1

    parts, lighting = parse_rbxlx(MAP_FILE)
    print(f"{len(parts)} partes de {os.path.basename(MAP_FILE)}")

    if args.all:
        for b in ["meadow", "forest", "desert", "ice", "shadow", "halloween", "cosmos"]:
            sub = [p for p in parts if f"Biome_{b}" in p["path"]]
            if not sub:
                print(f"  {b}: vazio")
                continue
            out = render(sub, os.path.join(OUT_DIR, f"{b}.png"), args.yaw, args.pitch, lighting=lighting,
                         label=f"Biome {b}  ({len(sub)} peças)")
            print("  ", b, "->", os.path.relpath(out, ROOT))
    elif args.biome:
        sub = [p for p in parts if f"Biome_{args.biome}" in p["path"]]
        out = render(sub, os.path.join(OUT_DIR, f"{args.biome}.png"), args.yaw, args.pitch,
                     label=f"Biome {args.biome}", lighting=lighting)
        print("->", os.path.relpath(out, ROOT))
    elif args.world:
        out = render(parts, os.path.join(OUT_DIR, "mundo.png"), 22, 34, label="Mundo inteiro", lighting=lighting)
        print("->", os.path.relpath(out, ROOT))
    else:
        hub = [p for p in parts if "Biomes/" not in p["path"] and "Sky/" not in p["path"]]
        if args.no_ocean:
            hub = [p for p in hub if p["name"] not in ("Ocean", "SeaFloor")]
        out = render(hub, os.path.join(OUT_DIR, "hub.png"), args.yaw, args.pitch,
                     label="Hub (praça + portais)", show_ground=True, zoom=args.zoom,
                     lighting=lighting)
        print("->", os.path.relpath(out, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
