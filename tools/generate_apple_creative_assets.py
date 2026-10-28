"""
NutriLens — Apple App Store Creative Assets Generator
Uses REAL app screenshots in Dark Mode.
Produces:
1. Header: 3840 x 1646 px (header_3840x1646.png)
2. Search Results: 3840 x 2560 px (search_results_3840x2560.png)
"""
from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from screen_mockup_builder import (
    get_real_mockup,
    get_font,
)

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR_STORE = ROOT / "store_assets" / "ios" / "app_store"
OUT_DIR_ASSETS = ROOT / "assets" / "app_store"
ICON_PATH = ROOT / "assets" / "icon" / "nutrilens_icon_1024.png"
BG_PHOTO_PATH = ROOT / "assets" / "store" / "nutrilens_promo_bg.jpg"

# Palette matching the real dark app
DARK_GREEN_1 = (10, 30, 20)      # #0A1E14
DARK_GREEN_2 = (6, 20, 14)       # #06140E
EMERALD = (22, 163, 74)          # #16A34A
LIME_ACCENT = (85, 229, 143)     # #55E58F
WHITE = (255, 255, 255)
TEXT_LIGHT = (245, 250, 246)
TEXT_MUTED = (165, 195, 175)
TEXT_GOLD = (240, 215, 165)


def apply_gaussian_shadow(
    base: Image.Image,
    overlay: Image.Image,
    pos: tuple[int, int],
    shadow_blur: int = 35,
    shadow_alpha: int = 140,
    offset_y: int = 15,
):
    sw = overlay.width + shadow_blur * 2
    sh = overlay.height + shadow_blur * 2
    shadow = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    rad = int(overlay.width * 0.12)
    sd.rounded_rectangle(
        [shadow_blur, shadow_blur + offset_y, sw - shadow_blur, sh - shadow_blur + offset_y],
        radius=rad,
        fill=(0, 0, 0, shadow_alpha),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))
    base.paste(shadow, (pos[0] - shadow_blur, pos[1] - shadow_blur), shadow)
    base.paste(overlay, pos, overlay)


def create_floating_badge(title: str, subtitle: str, score: str = "1/5", S: float = 1.0) -> Image.Image:
    """Creates a dark glassmorphic floating badge matching the real app."""
    w = int(340 * S)
    h = int(120 * S)
    badge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    rad = int(24 * S)
    # Dark translucent card with subtle green border
    d.rounded_rectangle([0, 0, w, h], radius=rad, fill=(14, 34, 24, 245), outline=(35, 75, 52, 255), width=int(2 * S))

    # Score circle on left
    cs = int(72 * S)
    cx = int(24 * S)
    cy = int(24 * S)
    d.ellipse([cx, cy, cx + cs, cy + cs], fill=(22, 163, 74))
    f_sc = get_font("ExtraBold", int(26 * S))
    sb = d.textbbox((0, 0), score, font=f_sc)
    d.text((cx + (cs - (sb[2] - sb[0])) // 2, cy + int(18 * S)), score, font=f_sc, fill=WHITE)

    # Text on right
    tx = cx + cs + int(18 * S)
    f_t = get_font("Bold", int(20 * S))
    f_s = get_font("SemiBold", int(15 * S))
    d.text((tx, cy + int(12 * S)), title, font=f_t, fill=WHITE)
    d.text((tx, cy + int(40 * S)), subtitle, font=f_s, fill=LIME_ACCENT)
    return badge


def generate_header_asset(W: int = 3840, H: int = 1646, out_name: str = "header_3840x1646.png") -> Path:
    print(f"Generating Apple Header Asset: {W}x{H} (Real App UI)...")
    bg = Image.new("RGB", (W, H), DARK_GREEN_1)

    # 1. Master food photo on right
    if BG_PHOTO_PATH.exists():
        with Image.open(BG_PHOTO_PATH) as master_im:
            scale_m = (H * 1.15) / master_im.height
            new_w = int(master_im.width * scale_m)
            new_h = int(master_im.height * scale_m)
            scaled = master_im.resize((new_w, new_h), Image.Resampling.LANCZOS)
            x_offset = W - new_w + int(W * 0.05)
            y_offset = (H - new_h) // 2
            bg.paste(scaled, (x_offset, y_offset))

    # 2. Scrim (horizontal fade for crisp typography readability)
    scrim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    scrim_draw = ImageDraw.Draw(scrim)
    scrim_stop1 = int(W * 0.36)
    scrim_stop2 = int(W * 0.72)
    for x in range(W):
        if x < scrim_stop1:
            alpha = 250
        elif x < scrim_stop2:
            p = (x - scrim_stop1) / (scrim_stop2 - scrim_stop1)
            factor = (math.cos(p * math.pi) + 1) / 2
            alpha = int(250 * factor)
        else:
            alpha = 0
        if alpha > 0:
            scrim_draw.line([(x, 0), (x, H)], fill=(DARK_GREEN_1[0], DARK_GREEN_1[1], DARK_GREEN_1[2], alpha))

    # Top & bottom vignettes
    vignette = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vg_draw = ImageDraw.Draw(vignette)
    top_band = int(H * 0.18)
    for y in range(top_band):
        p = 1.0 - (y / top_band)
        vg_draw.line([(0, y), (W, y)], fill=(6, 20, 14, int(150 * p)))
    bot_band = int(H * 0.22)
    for y in range(bot_band):
        p = y / bot_band
        vg_draw.line([(0, H - bot_band + y), (W, H - bot_band + y)], fill=(6, 20, 14, int(180 * p)))

    bg_rgba = bg.convert("RGBA")
    bg_rgba = Image.alpha_composite(bg_rgba, scrim)
    bg_rgba = Image.alpha_composite(bg_rgba, vignette)

    S = W / 3840.0

    # 3. App Icon
    if ICON_PATH.exists():
        with Image.open(ICON_PATH) as icon_im:
            icon_size = int(170 * S)
            icon_res = icon_im.convert("RGBA").resize((icon_size, icon_size), Image.Resampling.LANCZOS)
            mask = Image.new("L", (icon_size, icon_size), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, icon_size, icon_size], radius=int(icon_size * 0.22), fill=255)
            icon_clipped = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
            icon_clipped.paste(icon_res, (0, 0), mask)
            icon_pos = (int(160 * S), int(150 * S))
            apply_gaussian_shadow(bg_rgba, icon_clipped, icon_pos, shadow_blur=int(26 * S), shadow_alpha=130, offset_y=int(10 * S))

    # 4. Brand & Category Pill
    d = ImageDraw.Draw(bg_rgba)
    pill_x = int(360 * S)
    pill_y = int(175 * S)
    pill_w = int(490 * S)
    pill_h = int(58 * S)
    d.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=int(pill_h // 2), fill=(22, 163, 74, 240))
    font_pill = get_font("Bold", int(25 * S))
    d.text((pill_x + int(32 * S), pill_y + int(12 * S)), "GIDA ANALİZİ & SAĞLIK PUANI", fill=WHITE, font=font_pill)

    font_brand = get_font("Bold", int(44 * S))
    d.text((pill_x, pill_y + int(72 * S)), "NutriLens", fill=(215, 245, 225), font=font_brand)

    # 5. Headlines
    font_h1 = get_font("ExtraBold", int(92 * S))
    font_h2 = get_font("Bold", int(42 * S))
    font_body = get_font("Medium", int(33 * S))

    text_x = int(160 * S)
    y_cursor = int(390 * S)
    d.text((text_x, y_cursor), "Sağlıklı Seçimler Buradan Başlar", fill=WHITE, font=font_h1)
    y_cursor += int(120 * S)
    d.text((text_x, y_cursor), "Barkodu tara, katkı maddelerini ve sağlık puanını anında gör.", fill=TEXT_GOLD, font=font_h2)
    y_cursor += int(90 * S)

    # 6. Bullets matching real app features
    bullets = [
        "5 Kademeli Bilimsel Sağlık Puanı (1 En İyi • 5 En Kötü)",
        "E-Kod & Katkı Maddesi Analizi (Güvenli, Dikkat, Riskli)",
        "Yapay Zeka ile Tabak Fotoğrafından Kalori & Makro Analizi",
        "Kritik Şeker, Doymuş Yağ ve Alerjen Uyarıları",
    ]
    for b in bullets:
        c_r = int(14 * S)
        cy = y_cursor + int(24 * S)
        d.ellipse([text_x, cy - c_r, text_x + c_r * 2, cy + c_r], fill=EMERALD)
        d.ellipse([text_x + int(5 * S), cy - int(5 * S), text_x + int(15 * S), cy + int(5 * S)], fill=WHITE)
        d.text((text_x + int(48 * S), y_cursor + int(6 * S)), b, fill=TEXT_LIGHT, font=font_body)
        y_cursor += int(68 * S)

    # 7. iPhone Mockup with REAL Meal AI Analysis screen
    mock_w = int(620 * S)
    mockup = get_real_mockup("meal", mock_w)
    mock_pos = (int(W * 0.54), int(H * 0.10))
    apply_gaussian_shadow(bg_rgba, mockup, mock_pos, shadow_blur=int(50 * S), shadow_alpha=180, offset_y=int(30 * S))

    # 8. Floating Badge overlapping phone mockup
    badge_im = create_floating_badge("Sağlık Puanı 1/5", "En İyi Derece • 280 kcal", score="1/5", S=S)
    badge_pos = (int(W * 0.46), int(H * 0.58))
    apply_gaussian_shadow(bg_rgba, badge_im, badge_pos, shadow_blur=int(30 * S), shadow_alpha=160, offset_y=int(14 * S))

    # 9. Footer
    d = ImageDraw.Draw(bg_rgba)
    font_footer = get_font("Medium", int(26 * S))
    d.text((int(160 * S), H - int(90 * S)), "NutriLens • Bilinçli Beslenmenin Akıllı Rehberi", fill=TEXT_MUTED, font=font_footer)

    # Save to both target directories
    OUT_DIR_STORE.mkdir(parents=True, exist_ok=True)
    OUT_DIR_ASSETS.mkdir(parents=True, exist_ok=True)

    out_path1 = OUT_DIR_STORE / out_name
    out_path2 = OUT_DIR_ASSETS / out_name
    bg_final = bg_rgba.convert("RGB")
    bg_final.save(out_path1, format="PNG", optimize=True)
    bg_final.save(out_path2, format="PNG", optimize=True)
    print(f"  [OK] Saved Apple Header to {out_path1}")
    return out_path1


def generate_search_results_asset(W: int = 3840, H: int = 2560, out_name: str = "search_results_3840x2560.png") -> Path:
    print(f"Generating Apple Search Results Asset: {W}x{H} (Real App UI)...")
    bg = Image.new("RGB", (W, H), DARK_GREEN_2)

    # 1. Master food photo
    if BG_PHOTO_PATH.exists():
        with Image.open(BG_PHOTO_PATH) as master_im:
            scale_m = (H * 0.82) / master_im.height
            new_w = int(master_im.width * scale_m)
            new_h = int(master_im.height * scale_m)
            scaled = master_im.resize((new_w, new_h), Image.Resampling.LANCZOS)
            x_offset = W - new_w + int(W * 0.08)
            y_offset = int(H * 0.12)
            bg.paste(scaled, (x_offset, y_offset))

    # 2. Scrim
    scrim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    scrim_draw = ImageDraw.Draw(scrim)
    scrim_stop1 = int(W * 0.38)
    scrim_stop2 = int(W * 0.76)
    for x in range(W):
        if x < scrim_stop1:
            alpha = 252
        elif x < scrim_stop2:
            p = (x - scrim_stop1) / (scrim_stop2 - scrim_stop1)
            factor = (math.cos(p * math.pi) + 1) / 2
            alpha = int(252 * factor)
        else:
            alpha = 0
        if alpha > 0:
            scrim_draw.line([(x, 0), (x, H)], fill=(DARK_GREEN_2[0], DARK_GREEN_2[1], DARK_GREEN_2[2], alpha))

    # Bottom dark gradient band for feature footer
    bot_h = int(H * 0.22)
    for y in range(bot_h):
        p = y / bot_h
        alpha = 255 if p > 0.45 else int(255 * (p / 0.45))
        scrim_draw.line([(0, H - bot_h + y), (W, H - bot_h + y)], fill=(6, 18, 12, alpha))

    bg_rgba = bg.convert("RGBA")
    bg_rgba = Image.alpha_composite(bg_rgba, scrim)

    S = W / 3840.0

    # 3. App Icon
    if ICON_PATH.exists():
        with Image.open(ICON_PATH) as icon_im:
            icon_size = int(190 * S)
            icon_res = icon_im.convert("RGBA").resize((icon_size, icon_size), Image.Resampling.LANCZOS)
            mask = Image.new("L", (icon_size, icon_size), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, icon_size, icon_size], radius=int(icon_size * 0.22), fill=255)
            icon_clipped = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
            icon_clipped.paste(icon_res, (0, 0), mask)
            icon_pos = (int(180 * S), int(180 * S))
            apply_gaussian_shadow(bg_rgba, icon_clipped, icon_pos, shadow_blur=int(32 * S), shadow_alpha=140, offset_y=int(12 * S))

    # 4. Brand Name & Tag Pill
    d = ImageDraw.Draw(bg_rgba)
    brand_x = int(410 * S)
    brand_y = int(195 * S)
    font_brand = get_font("ExtraBold", int(60 * S))
    d.text((brand_x, brand_y), "NutriLens", fill=WHITE, font=font_brand)

    pill_w = int(400 * S)
    pill_h = int(52 * S)
    pill_y = brand_y + int(82 * S)
    d.rounded_rectangle([brand_x, pill_y, brand_x + pill_w, pill_y + pill_h], radius=int(pill_h // 2), fill=(22, 163, 74, 240))
    font_pill = get_font("Bold", int(24 * S))
    d.text((brand_x + int(28 * S), pill_y + int(10 * S)), "BARKOD TARAMA & ÖĞÜN ANALİZİ", fill=WHITE, font=font_pill)

    # 5. Main Hero Typography
    font_h1 = get_font("ExtraBold", int(106 * S))
    font_h2 = get_font("Bold", int(48 * S))
    font_body = get_font("Medium", int(36 * S))

    text_x = int(180 * S)
    y_cursor = int(480 * S)
    d.text((text_x, y_cursor), "Gıdanın Gerçek Yüzünü", fill=WHITE, font=font_h1)
    y_cursor += int(135 * S)
    d.text((text_x, y_cursor), "Tek Dokunuşla Keşfet", fill=WHITE, font=font_h1)
    y_cursor += int(140 * S)
    d.text((text_x, y_cursor), "Katkı Maddeleri, Şeker Yükü ve Sağlık Puanı Cebinde", fill=TEXT_GOLD, font=font_h2)
    y_cursor += int(105 * S)

    # 6. Bullets matching real app
    bullets = [
        "TÜBİTAK & EFSA Standartlarında Katkı Maddesi Analizi",
        "E-Kod Risk Değerlendirmesi ve Katkısız Alternatifler",
        "Yapay Zeka ile Tabak Fotoğrafından Kalori & Makro Ayrıştırma",
        "Market Raflarında Hızlı ve Bilinçli Karar Ver",
    ]
    for b in bullets:
        c_r = int(16 * S)
        cy = y_cursor + int(26 * S)
        d.ellipse([text_x, cy - c_r, text_x + c_r * 2, cy + c_r], fill=EMERALD)
        d.ellipse([text_x + int(6 * S), cy - int(6 * S), text_x + int(16 * S), cy + int(6 * S)], fill=WHITE)
        d.text((text_x + int(54 * S), y_cursor + int(6 * S)), b, fill=TEXT_LIGHT, font=font_body)
        y_cursor += int(82 * S)

    # 7. Dual Phone Mockups on Right (REAL in-app screenshots)
    # Background phone: Product E-Code & Content Analysis (real screen)
    mock_w2 = int(660 * S)
    m2 = get_real_mockup("ingredients", mock_w2)
    pos2 = (int(W * 0.70), int(H * 0.11))
    apply_gaussian_shadow(bg_rgba, m2, pos2, shadow_blur=int(45 * S), shadow_alpha=150, offset_y=int(22 * S))

    # Foreground phone: Meal AI & Health Score Analysis (real screen)
    mock_w1 = int(710 * S)
    m1 = get_real_mockup("meal", mock_w1)
    pos1 = (int(W * 0.49), int(H * 0.24))
    apply_gaussian_shadow(bg_rgba, m1, pos1, shadow_blur=int(55 * S), shadow_alpha=190, offset_y=int(32 * S))

    # 8. Floating Badge
    badge_im = create_floating_badge("Sağlık Puanı 1/5", "En İyi Derece • 280 kcal", score="1/5", S=S * 1.15)
    badge_pos = (int(W * 0.41), int(H * 0.62))
    apply_gaussian_shadow(bg_rgba, badge_im, badge_pos, shadow_blur=int(32 * S), shadow_alpha=180, offset_y=int(18 * S))

    # 9. Bottom 4-Column Feature Strip
    d = ImageDraw.Draw(bg_rgba)
    strip_y = H - int(240 * S)
    features = [
        ("SAĞLIK PUANI", "1-5 Kademeli Bilimsel İndeks"),
        ("E-KOD ANALİZİ", "Güvenli, Dikkat ve Riskli"),
        ("AI ÖĞÜN ANALİZİ", "Fotoğraftan Kalori ve Makrolar"),
        ("BESİN DEĞERİ", "Kritik Şeker ve Yağ Uyarıları"),
    ]
    col_w = W // 4
    for i, (f_title, f_sub) in enumerate(features):
        fx = int(i * col_w + 160 * S)
        d.ellipse([fx, strip_y + int(6 * S), fx + int(14 * S), strip_y + int(20 * S)], fill=EMERALD)
        font_ft = get_font("Bold", int(28 * S))
        font_fs = get_font("Regular", int(22 * S))
        d.text((fx + int(26 * S), strip_y), f_title, fill=WHITE, font=font_ft)
        d.text((fx + int(26 * S), strip_y + int(42 * S)), f_sub, fill=TEXT_MUTED, font=font_fs)

    # Save to both locations
    OUT_DIR_STORE.mkdir(parents=True, exist_ok=True)
    OUT_DIR_ASSETS.mkdir(parents=True, exist_ok=True)

    out_path1 = OUT_DIR_STORE / out_name
    out_path2 = OUT_DIR_ASSETS / out_name
    bg_final = bg_rgba.convert("RGB")
    bg_final.save(out_path1, format="PNG", optimize=True)
    bg_final.save(out_path2, format="PNG", optimize=True)
    print(f"  [OK] Saved Apple Search Results to {out_path1}")
    return out_path1


def main():
    print("=" * 60)
    print("NutriLens — Apple Store Creative Assets Generation (Real Screenshots)")
    print("=" * 60)
    h_path = generate_header_asset()
    sr_path = generate_search_results_asset()
    print("=" * 60)
    print("FINISHED SUCCESSFULLY!")
    print(f"1. Header: {h_path}")
    print(f"2. Search Results: {sr_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
