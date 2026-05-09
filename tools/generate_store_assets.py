from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "store_assets" / "ios"
SCREENSHOT_DIR = OUT_DIR / "screenshots_6_5"
MARKETING_DIR = OUT_DIR / "marketing"
ICON_DIR = OUT_DIR / "app_icon"
ICON_PATH = (
    ROOT
    / "ios"
    / "Runner"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "Icon-App-1024x1024@1x.png"
)

W, H = 1242, 2688
AD_W, AD_H = 1080, 1350

GREEN = "#0C5A2D"
DARK = "#08361F"
MINT = "#DFF7E8"
LIME = "#55E58F"
CREAM = "#F8F6EF"
INK = "#102119"
MUTED = "#65756B"
RED = "#D84646"
AMBER = "#E6A23C"
BLUE = "#2A6FDB"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "arialbd.ttf" if bold else "arial.ttf"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), size)


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text_center(draw, box, text, fnt, fill):
    bbox = draw.textbbox((0, 0), text, font=fnt)
    x = box[0] + ((box[2] - box[0]) - (bbox[2] - bbox[0])) / 2
    y = box[1] + ((box[3] - box[1]) - (bbox[3] - bbox[1])) / 2
    draw.text((x, y), text, font=fnt, fill=fill)


def wrap(draw, text, fnt, max_width):
    lines: list[str] = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        line = ""
        for word in words:
            candidate = word if not line else f"{line} {word}"
            if draw.textlength(candidate, font=fnt) <= max_width:
                line = candidate
            else:
                if line:
                    lines.append(line)
                line = word
        if line:
            lines.append(line)
    return lines


def multiline(draw, xy, text, fnt, fill, max_width, line_gap=10):
    x, y = xy
    for line in wrap(draw, text, fnt, max_width):
        draw.text((x, y), line, font=fnt, fill=fill)
        y += fnt.size + line_gap
    return y


def vertical_gradient(width, height, top, bottom):
    img = Image.new("RGB", (width, height), top)
    draw = ImageDraw.Draw(img)
    t = tuple(int(top.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))
    b = tuple(int(bottom.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))
    for y in range(height):
        p = y / max(1, height - 1)
        color = tuple(round(t[i] * (1 - p) + b[i] * p) for i in range(3))
        draw.line((0, y, width, y), fill=color)
    return img


def paste_shadow(base, layer, xy, blur=28, offset=(0, 20), alpha=90):
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    mask = layer.split()[-1]
    shadow.putalpha(mask.point(lambda p: min(alpha, p)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(shadow, (xy[0] + offset[0], xy[1] + offset[1]))
    base.alpha_composite(layer, xy)


def phone_frame(screen: Image.Image) -> Image.Image:
    pw, ph = 720, 1510
    frame = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    rounded(d, (0, 0, pw, ph), 86, "#111716")
    rounded(d, (22, 22, pw - 22, ph - 22), 70, "#F9FAF7")
    resized = screen.resize((pw - 56, ph - 70), Image.Resampling.LANCZOS)
    mask = Image.new("L", resized.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, resized.width, resized.height), radius=52, fill=255)
    clipped = resized.convert("RGBA")
    clipped.putalpha(mask)
    frame.alpha_composite(clipped, (28, 42))
    d.rounded_rectangle((pw // 2 - 92, 34, pw // 2 + 92, 64), radius=18, fill="#111716")
    return frame


def app_screen(kind: str) -> Image.Image:
    img = Image.new("RGB", (664, 1440), "#FAFBF7")
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 664, 140), fill=GREEN)
    d.text((42, 58), "NutriLens", font=font(42, True), fill="white")
    d.ellipse((560, 54, 604, 98), fill=LIME)

    if kind == "scan":
        d.text((42, 190), "Barkod Tara", font=font(44, True), fill=INK)
        d.text((42, 250), "Ürün etiketini hızlıca analiz et.", font=font(25), fill=MUTED)
        rounded(d, (52, 355, 612, 825), 38, "#102119")
        for x in range(120, 560, 36):
            h = 260 + (x % 5) * 18
            d.rounded_rectangle((x, 470, x + 12, 470 + h), radius=6, fill="white")
        d.rectangle((92, 580, 572, 604), fill=LIME)
        rounded(d, (72, 940, 592, 1048), 28, GREEN)
        text_center(d, (72, 940, 592, 1048), "Taramaya Başla", font(31, True), "white")
        chip_row(d, 86, 1138, ["HP Score", "Katkı", "Alerjen"])
    elif kind == "score":
        d.text((42, 190), "Ürün Analizi", font=font(44, True), fill=INK)
        card(d, (42, 270, 622, 710))
        d.text((84, 316), "Tam Buğday Kraker", font=font(34, True), fill=INK)
        gauge(d, (332, 520), 156, 78, "#35B36A")
        d.text((270, 485), "78", font=font(86, True), fill=INK)
        d.text((260, 595), "HP Score", font=font(28, True), fill=MUTED)
        score_bar(d, 82, 790, "Kimyasal Yük", 0.22, "#35B36A")
        score_bar(d, 82, 900, "Risk Faktörü", 0.38, AMBER)
        score_bar(d, 82, 1010, "Besin Kalitesi", 0.72, BLUE)
    elif kind == "ingredients":
        d.text((42, 190), "İçindekiler", font=font(44, True), fill=INK)
        d.text((42, 250), "Katkı maddelerini sade dille gör.", font=font(25), fill=MUTED)
        y = 340
        for title, desc, color in [
            ("E300 Askorbik Asit", "Düşük riskli katkı maddesi", "#35B36A"),
            ("Gluten içerir", "Diyet filtresi için uyarı", AMBER),
            ("Eklenmiş şeker", "Skora ceza olarak işlenir", RED),
        ]:
            card(d, (42, y, 622, y + 190))
            d.ellipse((82, y + 54, 142, y + 114), fill=color)
            d.text((170, y + 44), title, font=font(29, True), fill=INK)
            d.text((170, y + 92), desc, font=font(22), fill=MUTED)
            y += 225
    elif kind == "meal":
        d.text((42, 190), "Öğünlerim", font=font(44, True), fill=INK)
        d.text((42, 250), "Fotoğrafla kalori ve makro takibi.", font=font(25), fill=MUTED)
        card(d, (42, 330, 622, 690))
        d.text((84, 382), "Bugün", font=font(31, True), fill=INK)
        d.text((84, 445), "1.482 kcal", font=font(68, True), fill=GREEN)
        macro(d, 84, 565, "Protein", 58, "#35B36A")
        macro(d, 258, 565, "Karbonhidrat", 176, AMBER)
        macro(d, 466, 565, "Yağ", 44, BLUE)
        meal_row(d, 42, 760, "Kahvaltı", "Yulaf, muz, süt", "412 kcal")
        meal_row(d, 42, 965, "Öğle", "Ev yapımı tabak", "690 kcal")
    elif kind == "history":
        d.text((42, 190), "Geçmiş", font=font(44, True), fill=INK)
        d.text((42, 250), "Favorilerini ve önceki analizleri sakla.", font=font(25), fill=MUTED)
        for i, (name, score, color) in enumerate(
            [("Yoğurt", "86", "#35B36A"), ("Kraker", "78", "#35B36A"), ("Bisküvi", "42", AMBER), ("Gazlı İçecek", "18", RED)]
        ):
            y = 340 + i * 190
            card(d, (42, y, 622, y + 150))
            d.rounded_rectangle((84, y + 38, 160, y + 112), radius=18, fill=MINT)
            d.text((190, y + 36), name, font=font(30, True), fill=INK)
            d.text((190, y + 84), "Barkod analizi", font=font(22), fill=MUTED)
            d.ellipse((516, y + 38, 586, y + 108), fill=color)
            text_center(d, (516, y + 38, 586, y + 108), score, font(26, True), "white")
    return img


def card(d, box):
    rounded(d, box, 32, "white", "#E6ECE6", 2)


def chip_row(d, x, y, labels):
    cx = x
    for label in labels:
        w = int(d.textlength(label, font=font(23, True))) + 52
        rounded(d, (cx, y, cx + w, y + 62), 31, MINT)
        text_center(d, (cx, y, cx + w, y + 62), label, font(23, True), GREEN)
        cx += w + 18


def gauge(d, center, radius, percent, color):
    x, y = center
    box = (x - radius, y - radius, x + radius, y + radius)
    d.arc(box, 180, 360, fill="#E7EEE7", width=28)
    d.arc(box, 180, 180 + 180 * percent / 100, fill=color, width=28)


def score_bar(d, x, y, label, value, color):
    d.text((x, y), label, font=font(24, True), fill=INK)
    rounded(d, (x, y + 48, x + 500, y + 78), 15, "#E9EFE9")
    rounded(d, (x, y + 48, x + int(500 * value), y + 78), 15, color)


def macro(d, x, y, label, value, color):
    d.ellipse((x, y, x + 104, y + 104), fill=color)
    text_center(d, (x, y, x + 104, y + 104), str(value), font(28, True), "white")
    d.text((x - 4, y + 124), label, font=font(20), fill=MUTED)


def meal_row(d, x, y, title, desc, kcal):
    card(d, (x, y, 622, y + 160))
    d.text((82, y + 34), title, font=font(28, True), fill=INK)
    d.text((82, y + 82), desc, font=font(22), fill=MUTED)
    d.text((470, y + 58), kcal, font=font(24, True), fill=GREEN)


def screenshot(filename, headline, subhead, kind):
    bg = vertical_gradient(W, H, "#F7FBF2", "#DAF2E2").convert("RGBA")
    d = ImageDraw.Draw(bg)
    d.text((86, 122), "NutriLens", font=font(42, True), fill=GREEN)
    multiline(d, (86, 235), headline, font(76, True), INK, 980, 12)
    multiline(d, (86, 445), subhead, font(34), "#415247", 980, 10)
    phone = phone_frame(app_screen(kind))
    paste_shadow(bg, phone, (W // 2 - phone.width // 2, 815), blur=34, offset=(0, 28), alpha=80)
    bg.convert("RGB").save(SCREENSHOT_DIR / filename, quality=95)


def marketing(filename, headline, subhead, kind):
    bg = vertical_gradient(AD_W, AD_H, "#0B3F25", "#138044").convert("RGBA")
    d = ImageDraw.Draw(bg)
    icon = Image.open(ICON_PATH).convert("RGBA").resize((138, 138), Image.Resampling.LANCZOS)
    paste_shadow(bg, icon, (72, 72), blur=22, offset=(0, 14), alpha=70)
    d.text((235, 96), "NutriLens", font=font(49, True), fill="white")
    multiline(d, (72, 260), headline, font(58, True), "white", 500, 12)
    multiline(d, (72, 495), subhead, font(27), "#DDF7E8", 490, 10)
    phone = phone_frame(app_screen(kind)).resize((410, 860), Image.Resampling.LANCZOS)
    paste_shadow(bg, phone, (AD_W - 470, 390), blur=30, offset=(0, 20), alpha=85)
    rounded(d, (72, 1110, 520, 1200), 45, "white")
    text_center(d, (72, 1110, 520, 1200), "Barkod Tara", font(34, True), GREEN)
    bg.convert("RGB").save(MARKETING_DIR / filename, quality=95)


def app_icon_preview():
    img = Image.new("RGBA", (1200, 630), CREAM)
    icon = Image.open(ICON_PATH).convert("RGBA").resize((260, 260), Image.Resampling.LANCZOS)
    paste_shadow(img, icon, (92, 185))
    d = ImageDraw.Draw(img)
    d.text((410, 190), "NutriLens", font=font(74, True), fill=INK)
    d.text((414, 292), "Barkod Scanner & Meal Tracker", font=font(34), fill=MUTED)
    d.text((414, 365), "HP Score ile ürünleri sade, hızlı ve anlaşılır analiz et.", font=font(30), fill=GREEN)
    img.convert("RGB").save(MARKETING_DIR / "nutrilens-og-preview.png", quality=95)


def clean_icon_candidate():
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    src = Image.open(ICON_PATH).convert("RGB")
    img = src.copy()
    px = img.load()
    target = tuple(int(GREEN.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))
    w, h = img.size
    seen: set[tuple[int, int]] = set()
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]

    def near_white(c):
        return c[0] > 150 and c[1] > 150 and c[2] > 150

    while stack:
        x, y = stack.pop()
        if (x, y) in seen or x < 0 or y < 0 or x >= w or y >= h:
            continue
        seen.add((x, y))
        if not near_white(px[x, y]):
            continue
        px[x, y] = target
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    img.save(ICON_DIR / "nutrilens-ios-icon-1024-clean.png", quality=95)


def main():
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    MARKETING_DIR.mkdir(parents=True, exist_ok=True)
    screenshot(
        "01-barcode-scan.png",
        "Barkodu tara,\nürünü anında anla",
        "NutriLens etiketi analiz eder, HP Score ile net bir özet sunar.",
        "scan",
    )
    screenshot(
        "02-hp-score.png",
        "HP Score ile\nhızlı karar ver",
        "Kimyasal yük, risk faktörü ve besin kalitesi tek ekranda.",
        "score",
    )
    screenshot(
        "03-ingredients.png",
        "İçindekileri\nsade dile çevir",
        "Katkı maddeleri, alerjenler ve dikkat edilmesi gerekenler görünür olur.",
        "ingredients",
    )
    screenshot(
        "04-meal-tracker.png",
        "Öğünlerini\nfotoğrafla takip et",
        "Kalori ve makro takibini günlük özetle birlikte yönet.",
        "meal",
    )
    screenshot(
        "05-history-favorites.png",
        "Geçmişini ve\nfavorilerini sakla",
        "Sık aldığın ürünlere ve önceki analizlere hızlıca dön.",
        "history",
    )
    marketing(
        "ad-barcode-score-1080x1350.png",
        "Market rafında\nbilinçli seçim",
        "Barkodu tara, HP Score'u gör, içerikleri hızlıca değerlendir.",
        "score",
    )
    marketing(
        "ad-ingredients-1080x1350.png",
        "Etiket okumayı\nkolaylaştır",
        "Katkı maddeleri ve alerjen uyarıları daha anlaşılır hale gelir.",
        "ingredients",
    )
    marketing(
        "ad-meal-tracker-1080x1350.png",
        "Ürün analizi ve\nöğün takibi bir arada",
        "Günlük kalori ve makro özetini NutriLens içinde takip et.",
        "meal",
    )
    app_icon_preview()
    clean_icon_candidate()


if __name__ == "__main__":
    main()
