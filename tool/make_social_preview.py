"""生成 GitHub 仓库的社交预览图 screenshots/social-preview.png（1280×640）。

链接贴到论坛、群聊时显示的就是这张卡片。GitHub 没有接口上传它，生成后在
仓库 Settings → General → Social preview 手动上传。

用到 tool/icon.png 和 screenshots/ai-answer.png；字体用 Windows 自带的
Noto Serif SC / Noto Sans SC，找不到时退回微软雅黑。

  python tool/make_social_preview.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "screenshots" / "social-preview.png"
W, H = 1280, 640

INK = (59, 42, 32)
BRAND = (139, 90, 60)
MUTED = (110, 92, 80)
FONTS = Path("C:/Windows/Fonts")


def font(names: list[str], size: int, variation: str | None = None) -> ImageFont.FreeTypeFont:
    for name in names:
        path = FONTS / name
        if path.exists():
            loaded = ImageFont.truetype(str(path), size)
            if variation:
                try:
                    loaded.set_variation_by_name(variation)
                except (OSError, ValueError):
                    pass
            return loaded
    raise SystemExit(f"找不到字体：{names}")


def background() -> Image.Image:
    canvas = Image.new("RGB", (W, H))
    top, bottom = (251, 246, 239), (242, 233, 222)
    draw = ImageDraw.Draw(canvas)
    for y in range(H):
        t = y / (H - 1)
        draw.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((-260, -320, 520, 380), fill=(*BRAND, 34))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    return Image.alpha_composite(canvas.convert("RGBA"), glow)


def phone(screenshot: Image.Image, height: int) -> Image.Image:
    width = round(screenshot.width * height / screenshot.height)
    shot = screenshot.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=26, fill=255)
    framed = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    framed.paste(shot, (0, 0), mask)
    ImageDraw.Draw(framed).rounded_rectangle(
        (0, 0, width - 1, height - 1), radius=26, outline=(0, 0, 0, 36), width=2)
    return framed


def main() -> None:
    canvas = background()
    draw = ImageDraw.Draw(canvas)

    icon = Image.open(ROOT / "tool" / "icon.png").convert("RGBA").resize((108, 108), Image.Resampling.LANCZOS)
    canvas.alpha_composite(icon, (84, 92))

    serif = ["NotoSerifSC-VF.ttf", "msyhbd.ttc"]
    sans = ["NotoSansSC-VF.ttf", "msyh.ttc"]
    draw.text((84, 226), "芸窗 Yunchuang", font=font(serif, 66, "Bold"), fill=INK)
    draw.text((86, 318), "不剧透的 AI 阅读器", font=font(serif, 46, "SemiBold"), fill=BRAND)
    body = font(sans, 27, "Regular")
    lines = [
        "AI 只看你读过的部分，没读到的章节不发给模型",
        "回答附原文出处，点一下跳回原文",
        "离线优先 · EPUB / PDF / TXT · Android / Windows",
    ]
    for i, line in enumerate(lines):
        y = 404 + i * 46
        draw.ellipse((88, y + 14, 98, y + 24), fill=BRAND)
        draw.text((112, y), line, font=body, fill=MUTED)
    draw.text((86, 568), "github.com/yarizm/Yunchuang", font=font(sans, 22, "Regular"), fill=(150, 132, 120))

    device = phone(Image.open(ROOT / "screenshots" / "ai-answer.png"), 560)
    x, y = W - device.width - 110, (H - device.height) // 2
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 6, y + 18, x + device.width + 6, y + device.height + 18), radius=30, fill=(60, 40, 25, 70))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(18)))
    canvas.alpha_composite(device, (x, y))

    canvas.convert("RGB").save(OUT, optimize=True)
    print(f"{OUT.relative_to(ROOT)}: {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
