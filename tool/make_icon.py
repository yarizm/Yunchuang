"""生成应用图标（Android 传统 + 自适应图标、Windows .ico）。

用法：python tool/make_icon.py   （需要 Pillow，Windows 自带的华文字体）

图案：暗琥珀木色的圆角方块，中间一个「芸」字，细双线框取「窗」意，
右下一枚朱红小印。四倍超采样再缩小，边缘才平滑。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SS = 4  # 超采样倍数
SIZE = 1024
WOOD_TOP = (0xB0, 0x78, 0x50)
WOOD_BOTTOM = (0x8A, 0x58, 0x39)
CREAM = (0xFB, 0xF3, 0xE4)
SEAL = (0xB8, 0x3B, 0x2E)
FONT = "C:/Windows/Fonts/STZHONGS.TTF"
SEAL_FONT = "C:/Windows/Fonts/STKAITI.TTF"


def gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = c
    return img


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius, fill=255)
    return m


def draw_glyph(canvas, ch, font_path, height, center, fill):
    """把单个字按墨迹包围盒居中画到 center。height 是墨迹高度。"""
    font = ImageFont.truetype(font_path, height)
    d = ImageDraw.Draw(canvas)
    l, t, r, b = d.textbbox((0, 0), ch, font=font)
    # 按墨迹高度缩放到目标高度
    scale = height / max(1, b - t)
    font = ImageFont.truetype(font_path, int(height * scale))
    l, t, r, b = d.textbbox((0, 0), ch, font=font)
    x = center[0] - (l + r) / 2
    y = center[1] - (t + b) / 2
    d.text((x, y), ch, font=font, fill=fill)


def full_icon():
    """圆角方块 + 框 + 字 + 印。透明角。"""
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bg = gradient(s, WOOD_TOP, WOOD_BOTTOM)
    img.paste(bg, (0, 0), rounded_mask(s, int(s * 0.225)))

    d = ImageDraw.Draw(img)
    # 双线框：外粗内细，取窗棂之意
    o = int(s * 0.10)
    d.rounded_rectangle([o, o, s - o, s - o], int(s * 0.03), outline=CREAM, width=int(s * 0.010))
    i = int(s * 0.128)
    d.rounded_rectangle([i, i, s - i, s - i], int(s * 0.018), outline=CREAM, width=int(s * 0.004))

    draw_glyph(img, "芸", FONT, int(s * 0.50), (s * 0.5, s * 0.485), CREAM)

    # 朱印
    ps = int(s * 0.115)
    px, py = s - i - int(s * 0.055) - ps, s - i - int(s * 0.055) - ps
    d.rounded_rectangle([px, py, px + ps, py + ps], int(s * 0.008), fill=SEAL)
    draw_glyph(img, "窗", SEAL_FONT, int(ps * 0.62), (px + ps / 2, py + ps / 2), CREAM)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def adaptive_foreground():
    """自适应图标前景：108dp 画布，只有中间 66dp 的圆保证可见，字放在里面。"""
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_glyph(img, "芸", FONT, int(s * 0.42), (s * 0.5, s * 0.49), CREAM)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def adaptive_background():
    s = SIZE * SS
    return gradient(s, WOOD_TOP, WOOD_BOTTOM).resize((SIZE, SIZE), Image.LANCZOS)


def save_png(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(path.relative_to(ROOT), size)


def main():
    full = full_icon()
    fg = adaptive_foreground()
    bg = adaptive_background()

    res = ROOT / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, scale in densities.items():
        save_png(full, res / f"mipmap-{name}/ic_launcher.png", int(48 * scale))
        save_png(fg, res / f"mipmap-{name}/ic_launcher_foreground.png", int(108 * scale))
        save_png(bg, res / f"mipmap-{name}/ic_launcher_background.png", int(108 * scale))

    v26 = res / "mipmap-anydpi-v26"
    v26.mkdir(exist_ok=True)
    (v26 / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )

    ico = ROOT / "windows/runner/resources/app_icon.ico"
    sizes = [256, 128, 64, 48, 32, 24, 16]
    frames = [full.resize((n, n), Image.LANCZOS) for n in sizes]
    frames[0].save(ico, format="ICO", sizes=[(n, n) for n in sizes], append_images=frames[1:])
    print(ico.relative_to(ROOT), sizes)

    master = ROOT / "tool/icon.png"
    full.save(master, optimize=True)
    print(master.relative_to(ROOT))


if __name__ == "__main__":
    main()
