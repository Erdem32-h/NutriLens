"""
Real app screenshot processor and iPhone mockup builder for NutriLens.
Uses actual in-app screenshots in Dark Mode.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONTS_DIR = ROOT / "assets" / "fonts"
RAW_DIR = ROOT / "assets" / "store" / "raw_screens"

BG_APP_DARK = (7, 14, 7)  # Real app dark background


def get_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    path = FONTS_DIR / f"PlusJakartaSans-{name}.ttf"
    if path.exists():
        return ImageFont.truetype(str(path), size)
    fallback = "C:/Windows/Fonts/seguisb.ttf" if "Bold" in name else "C:/Windows/Fonts/segoeui.ttf"
    return ImageFont.truetype(fallback, size)


def prepare_real_screen(
    filename: str,
    top_crop: int = 44,
    bot_crop: int = 910,
    target_w: int = 1080,
    target_h: int = 2340,
) -> Image.Image:
    """Crops Android status bar and bottom nav from real screenshots and fits into an iOS canvas."""
    img_path = RAW_DIR / filename
    if not img_path.exists():
        raise FileNotFoundError(f"Missing screenshot: {img_path}")

    with Image.open(img_path) as im:
        raw = im.convert("RGBA")
        cropped = raw.crop((0, top_crop, raw.width, bot_crop))

    canvas = Image.new("RGBA", (target_w, target_h), (BG_APP_DARK[0], BG_APP_DARK[1], BG_APP_DARK[2], 255))
    scale = target_w / cropped.width
    new_h = int(cropped.height * scale)
    scaled_content = cropped.resize((target_w, new_h), Image.Resampling.LANCZOS)

    # Position content below Dynamic Island
    content_y = 100
    canvas.paste(scaled_content, (0, content_y))

    # Add iOS Home Indicator Bar
    d = ImageDraw.Draw(canvas)
    hi_w = int(target_w * 0.36)
    hi_h = 10
    hi_x = (target_w - hi_w) // 2
    hi_y = target_h - 40
    d.rounded_rectangle([hi_x, hi_y, hi_x + hi_w, hi_y + hi_h], radius=hi_h // 2, fill=(255, 255, 255, 140))

    return canvas


def create_iphone_mockup(screen: Image.Image, target_w: int) -> Image.Image:
    """Wraps an app screen into a realistic modern iPhone mockup."""
    scale = target_w / screen.width
    target_h = int(screen.height * scale)
    sc_res = screen.resize((target_w, target_h), Image.Resampling.LANCZOS)

    border = max(10, int(target_w * 0.024))
    mw = target_w + border * 2
    mh = target_h + border * 2

    mockup = Image.new("RGBA", (mw, mh), (0, 0, 0, 0))
    d = ImageDraw.Draw(mockup)

    radius = int(mw * 0.125)

    # Outer titanium bezel with metallic highlight
    d.rounded_rectangle([0, 0, mw, mh], radius=radius, fill=(24, 32, 28), outline=(100, 130, 115), width=max(2, int(border * 0.35)))
    d.rounded_rectangle([border - 2, border - 2, mw - border + 2, mh - border + 2], radius=radius - border // 2, fill=BG_APP_DARK)

    # Screen clipping mask
    mask = Image.new("L", (target_w, target_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, target_w, target_h], radius=int(radius * 0.82), fill=255)
    mockup.paste(sc_res, (border, border), mask)

    # Dynamic Island Pill
    di_w = int(target_w * 0.28)
    di_h = int(target_w * 0.075)
    di_x = (mw - di_w) // 2
    di_y = border + int(target_w * 0.028)
    d.rounded_rectangle([di_x, di_y, di_x + di_w, di_y + di_h], radius=di_h // 2, fill=(2, 6, 3))
    # Camera sensor dot
    d.ellipse([di_x + di_w - int(di_h * 0.75), di_y + int(di_h * 0.25), di_x + di_w - int(di_h * 0.25), di_y + int(di_h * 0.75)], fill=(12, 24, 18))

    return mockup


def get_real_mockup(kind: str, target_w: int) -> Image.Image:
    """Returns a realistic iPhone mockup for the specified app screen."""
    if kind == "meal":
        # Akşam Yemeği: Sağlık puanı 1/5, 280 kcal, 6'lı makro grid
        screen = prepare_real_screen("meal_detail.jpg", top_crop=44, bot_crop=922)
    elif kind == "ingredients":
        # Ürün Detayı: İçerik Analizi (Riskli) & E-Kod Analizi (Güvenli/Dikkat)
        screen = prepare_real_screen("product_content.jpg", top_crop=44, bot_crop=895)
    elif kind == "product":
        # Ürün Detayı: Petit Beurre fotoğrafı, Besin sekmesi, Şeker Kritik uyarısı
        screen = prepare_real_screen("product_top.jpg", top_crop=44, bot_crop=895)
    elif kind == "history":
        # Tarama Geçmişi
        screen = prepare_real_screen("history_list.jpg", top_crop=44, bot_crop=780)
    else:
        raise ValueError(f"Unknown kind: {kind}")

    return create_iphone_mockup(screen, target_w)
