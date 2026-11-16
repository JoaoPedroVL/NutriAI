#!/usr/bin/env python3
"""Gera os ícones do NutriAI (Android, iOS e web) desenhando a folha.

Sem dependências além do Pillow: cada arte é desenhada em 4x e reduzida,
o que dá contorno suave em todos os tamanhos.

Uso:  python3 tool/make_icons.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

CREAM = (247, 242, 229, 255)   # fundo do app (#F7F2E5)
LEAF_DARK = (63, 109, 28, 255)  # #3F6D1C
LEAF_LIGHT = (92, 154, 46, 255)  # #5C9A2E
STEM = (47, 83, 20, 255)
SS = 4  # supersampling


def _bezier(p0, p1, p2, p3, steps=240):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def leaf_polygon(scale: float, center=(0.5, 0.5)):
    """Folha apontada para cima, centrada em `center`, com `scale` da altura."""
    base = (0.5, 0.80)
    tip = (0.5, 0.16)
    left = _bezier(base, (0.06, 0.66), (0.20, 0.30), tip)
    right = _bezier(tip, (0.80, 0.30), (0.94, 0.66), base)

    cx, cy = center
    out = []
    for x, y in left + right:
        out.append((cx + (x - 0.5) * scale, cy + (y - 0.47) * scale))
    return out


def draw_mark(size: int, scale: float, background: tuple | None) -> Image.Image:
    """Desenha a marca (folha + caule). `scale` = altura da folha / lado."""
    big = size * SS
    img = Image.new("RGBA", (big, big), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    poly = [(x * big, y * big) for x, y in leaf_polygon(scale)]
    # Metade esquerda mais clara: recorta a folha pela linha central.
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    shade = Image.new("RGBA", (big, big), LEAF_DARK)
    # Luz vindo da esquerda: metade esquerda mais clara, direita mais escura.
    ImageDraw.Draw(shade).rectangle([0, 0, big // 2, big], fill=LEAF_LIGHT)
    img.paste(shade, (0, 0), mask)

    # Caule: haste curta e arredondada saindo da base da folha.
    cx = 0.5 * big
    base_y = (0.5 + (0.80 - 0.47) * scale) * big
    stem_w = 0.028 * scale * big
    draw.rounded_rectangle(
        [cx - stem_w / 2, base_y - stem_w * 0.6, cx + stem_w / 2, base_y + 0.075 * big],
        radius=stem_w / 2,
        fill=STEM,
    )

    return img.resize((size, size), Image.LANCZOS)


def rounded(img: Image.Image, radius_ratio: float) -> Image.Image:
    """Aplica cantos arredondados (só para conferência visual)."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(img.size[0] * radius_ratio),
        fill=255,
    )
    out = img.copy()
    out.putalpha(mask)
    return out


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    try:
        shown = path.relative_to(ROOT)
    except ValueError:
        shown = path
    print("  ", shown)


def main() -> None:
    master = draw_mark(1024, 0.66, CREAM)
    save(master, ROOT / "assets/icon/icon.png")
    # Folha centralizada menor = área segura dos ícones adaptativos (Android 8+).
    save(draw_mark(1024, 0.56, None), ROOT / "assets/icon/icon_foreground.png")

    # Android: ícone legado por densidade.
    for dpi, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save(draw_mark(size, 0.66, CREAM), ROOT / f"android/app/src/main/res/mipmap-{dpi}/ic_launcher.png")

    # Android: camada de frente do ícone adaptativo (108dp, área segura de 66dp).
    for dpi, size in {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }.items():
        save(
            draw_mark(size, 0.56, None),
            ROOT / f"android/app/src/main/res/mipmap-{dpi}/ic_launcher_foreground.png",
        )

    anydpi = ROOT / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
    anydpi.parent.mkdir(parents=True, exist_ok=True)
    anydpi.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n"
    )
    print("  ", anydpi.relative_to(ROOT))

    colors = ROOT / "android/app/src/main/res/values/colors.xml"
    colors.parent.mkdir(parents=True, exist_ok=True)
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#F7F2E5</color>\n'
        "</resources>\n"
    )
    print("  ", colors.relative_to(ROOT))

    # iOS: AppIcon.appiconset (sem alfa, como a App Store exige).
    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios_dir / "Contents.json").read_text())
    for entry in contents["images"]:
        w, _h = entry["size"].split("x")
        px = int(round(float(w) * int(entry["scale"].rstrip("x"))))
        icon = draw_mark(px, 0.66, CREAM).convert("RGB")
        save(icon, ios_dir / entry["filename"])

    # Web: ícones normais e maskable (com margem maior) + favicon.
    save(draw_mark(192, 0.66, CREAM), ROOT / "web/icons/Icon-192.png")
    save(draw_mark(512, 0.66, CREAM), ROOT / "web/icons/Icon-512.png")
    save(draw_mark(192, 0.50, CREAM), ROOT / "web/icons/Icon-maskable-192.png")
    save(draw_mark(512, 0.50, CREAM), ROOT / "web/icons/Icon-maskable-512.png")
    save(draw_mark(64, 0.70, None), ROOT / "web/favicon.png")
    # iPhone/iPad usam 180x180 no "Adicionar à Tela de Início".
    save(draw_mark(180, 0.66, CREAM), ROOT / "web/icons/apple-touch-icon.png")

    # Prévia para conferir o recorte circular dos launchers.
    preview = rounded(master, 0.5).resize((256, 256), Image.LANCZOS)
    canvas = Image.new("RGBA", (256 * 3 + 32, 256), (255, 255, 255, 255))
    canvas.paste(preview, (0, 0), preview)
    canvas.paste(master.resize((256, 256), Image.LANCZOS), (272, 0))
    small = draw_mark(64, 0.66, CREAM).resize((64, 64), Image.LANCZOS)
    canvas.paste(small, (544, 96))
    save(canvas, Path("/tmp/opencode/icon_preview.png"))


if __name__ == "__main__":
    print("Gerando ícones...")
    main()
    print("Pronto.")
