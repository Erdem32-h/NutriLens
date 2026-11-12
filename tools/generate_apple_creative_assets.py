"""
NutriLens — Apple App Store Creative Assets Generator (v1.5.3+)
Uses Playwright Chromium + Pillow RGB flattening (zero alpha, Apple-compliant).

Produces for each language (tr, en, ar):
1. universal_5244x2950.png      (16:9 Universal Asset — Header + Search Results)
2. header_3840x1646.png         (21:9 Dedicated Product Page Header)
3. search_results_3840x2560.png (3:2 Dedicated Search Results Asset)
"""
from __future__ import annotations

import base64
import html
import re
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR_STORE = ROOT / "store_assets" / "ios" / "app_store"
OUT_DIR_ASSETS = ROOT / "assets" / "app_store"
FONTS_DIR = ROOT / "assets" / "fonts"
ICON_PATH = ROOT / "assets" / "icon" / "nutrilens_icon_1024.png"
BG_PHOTO_PATH = ROOT / "assets" / "store" / "nutrilens_promo_bg.jpg"

LANGUAGES = ("tr", "en", "ar")

COPY = {
    "tr": {
        "dir": "ltr",
        "pill": "BARKOD TARAMA & ÖĞÜN ANALİZİ",
        "brand": "NutriLens",
        "h1_line1": "Sağlıklı Seçimler",
        "h1_line2": "Buradan Başlar",
        "subtitle": "Barkodu okut, katkı maddelerini ve 0–100 HP Skorunu anında gör.",
        "bullets": [
            "0–100 Bilimsel HP Skoru ve Şeffaf Puan Dökümü",
            "E-Kod & Katkı Maddesi Analizi (Güvenli, Dikkat, Riskli)",
            "Yapay Zeka ile Tabak Fotoğrafından Kalori & Makro Analizi",
            "Tek Ekranda Bugün: Öğün Özeti ve +1 Bardak Su Takibi",
        ],
        "badge_title": "HP Score 84/100",
        "badge_sub": "Temiz İçerik • 380 kcal",
        "footer_tagline": "NutriLens • Bilinçli Beslenmenin Akıllı Rehberi",
        "strip": [
            ("HP SCORE (0–100)", "Şeffaf Kimyasal & Besin Analizi"),
            ("E-KOD ANALİZİ", "Güvenli, Dikkat ve Riskli"),
            ("AI ÖĞÜN ANALİZİ", "Fotoğraftan Kalori & Makrolar"),
            ("BUGÜN & SU TAKİBİ", "Tek Dokunuşla +1 Bardak"),
        ],
        "phone1": {
            "screen_title": "Akşam Yemeği",
            "chips": ["380 kcal", "HP 84", "%92 güven"],
            "hp_label": "SAĞLIK PUANI (100 EN İYİ)",
            "score": "84",
            "energy_label": "Enerji Değeri",
            "energy_val": "380",
            "energy_pct": "%19",
            "macros": [
                ("Protein", "28.0 g", "YÜKSEK", "56%", "#4ADE80", 0.72),
                ("Karbonhidrat", "32.0 g", "DENGELİ", "24%", "#60A5FA", 0.42),
                ("Yağ", "14.0 g", "ORTA", "20%", "#86EFAC", 0.36),
                ("Şeker", "4.5 g", "DÜŞÜK", "9%", "#4ADE80", 0.16),
                ("Doymuş yağ", "3.2 g", "DÜŞÜK", "16%", "#86EFAC", 0.25),
                ("Tuz", "1.1 g", "ORTA", "18%", "#FCD34D", 0.30),
            ],
            "today_water_title": "Bugün • Su",
            "today_water_val": "6 / 8 bardak",
            "today_water_btn": "+1 bardak",
        },
        "phone2": {
            "screen_title": "Ürün Analizi",
            "product_name": "Tam Buğday Kraker",
            "why_title": "Neden 84/100?",
            "why_sub": "Kimyasal yük -4 • Besinsel risk -12",
            "sec_additives": "İçerik & E-Kod Analizi",
            "items": [
                ("E300 Askorbik Asit", "Antioksidan • Düşük risk", "GÜVENLİ", "safe"),
                ("E322 Lesitin", "Doğal emülgatör", "GÜVENLİ", "safe"),
                ("E471 Yağ Asitleri", "İşlenmiş emülgatör", "DİKKAT", "warn"),
                ("Eklenmiş Şeker", "Skora ceza uygulanır", "RİSKLİ", "risk"),
                ("Palm Yağı Yok", "Temiz yağ profili", "GÜVENLİ", "safe"),
            ],
        },
    },
    "en": {
        "dir": "ltr",
        "pill": "BARCODE SCANNER & MEAL AI",
        "brand": "NutriLens",
        "h1_line1": "Smart Food Choices",
        "h1_line2": "Start Right Here",
        "subtitle": "Scan any barcode or meal photo to see additives and your 0–100 HP Score.",
        "bullets": [
            "0–100 Scientific HP Score with Transparent Breakdown",
            "Instant E-Code & Additive Check (Safe, Caution, Risk)",
            "AI Plate Analysis for Calories & Macros from One Photo",
            "Today View: Daily Meal Summary & One-Tap +1 Glass Water",
        ],
        "badge_title": "HP Score 84/100",
        "badge_sub": "Clean Choice • 380 kcal",
        "footer_tagline": "NutriLens • Smart Guide to Conscious Nutrition",
        "strip": [
            ("HP SCORE (0–100)", "Transparent Health Breakdown"),
            ("E-CODE CHECK", "Safe, Caution & Risk Ratings"),
            ("AI MEAL SCAN", "Calories & Macros from Photo"),
            ("TODAY & WATER", "One-Tap +1 Glass Tracking"),
        ],
        "phone1": {
            "screen_title": "Dinner Plate",
            "chips": ["380 kcal", "HP 84", "92% conf."],
            "hp_label": "HEALTH SCORE (100 IS BEST)",
            "score": "84",
            "energy_label": "Energy Value",
            "energy_val": "380",
            "energy_pct": "19%",
            "macros": [
                ("Protein", "28.0 g", "HIGH", "56%", "#4ADE80", 0.72),
                ("Carbs", "32.0 g", "BALANCED", "24%", "#60A5FA", 0.42),
                ("Fat", "14.0 g", "MODERATE", "20%", "#86EFAC", 0.36),
                ("Sugar", "4.5 g", "LOW", "9%", "#4ADE80", 0.16),
                ("Sat. fat", "3.2 g", "LOW", "16%", "#86EFAC", 0.25),
                ("Salt", "1.1 g", "MODERATE", "18%", "#FCD34D", 0.30),
            ],
            "today_water_title": "Today • Water",
            "today_water_val": "6 / 8 glasses",
            "today_water_btn": "+1 glass",
        },
        "phone2": {
            "screen_title": "Product Analysis",
            "product_name": "Whole Grain Cracker",
            "why_title": "Why 84/100?",
            "why_sub": "Chem. load -4 • Nutri. risk -12",
            "sec_additives": "Ingredients & E-Code Check",
            "items": [
                ("E300 Ascorbic Acid", "Antioxidant • Low risk", "SAFE", "safe"),
                ("E322 Lecithin", "Natural emulsifier", "SAFE", "safe"),
                ("E471 Fatty Acids", "Processed emulsifier", "CAUTION", "warn"),
                ("Added Sugar", "Penalty applied to score", "RISK", "risk"),
                ("No Palm Oil", "Clean oil profile", "SAFE", "safe"),
            ],
        },
    },
    "ar": {
        "dir": "rtl",
        "pill": "ماسح الباركود وتحليل الوجبات",
        "brand": "NutriLens",
        "h1_line1": "اختياراتك الصحية",
        "h1_line2": "تبدأ من هنا",
        "subtitle": "امسح الباركود أو صوّر طبقك لتعرف المضافات وتقييم الصحة من 100.",
        "bullets": [
            "تقييم صحة علمي (0–100) مع تفاصيل الحساب الكاملة",
            "فحص رموز E والمواد المضافة (آمن، تنبيه، مرتفع الخطورة)",
            "تحليل السعرات والماكروز بالذكاء الاصطناعي من صورة واحدة",
            "شاشة اليوم: ملخص الوجبات وتتبع الماء بلمسة +1 كوب",
        ],
        "badge_title": "HP Score 84/100",
        "badge_sub": "اختيار نظيف • 380 kcal",
        "footer_tagline": "NutriLens • دليلك الذكي للتغذية الواعية",
        "strip": [
            ("تقييم الصحة (0–100)", "تحليل شفاف للمكونات والغذاء"),
            ("فحص رموز E", "آمن، تنبيه ومرتفع الخطورة"),
            ("تحليل الوجبات AI", "السعرات والماكروز من صورة"),
            ("اليوم وتتبع الماء", "أضف +1 كوب بلمسة واحدة"),
        ],
        "phone1": {
            "screen_title": "وجبة العشاء",
            "chips": ["380 kcal", "HP 84", "ثقة 92%"],
            "hp_label": "درجة الصحة (100 هو الأفضل)",
            "score": "84",
            "energy_label": "السعرات الحرارية",
            "energy_val": "380",
            "energy_pct": "19%",
            "macros": [
                ("البروتينات", "28.0 g", "مرتفع", "56%", "#4ADE80", 0.72),
                ("الكربوهيدرات", "32.0 g", "متوازن", "24%", "#60A5FA", 0.42),
                ("الدهون", "14.0 g", "متوسط", "20%", "#86EFAC", 0.36),
                ("السكر", "4.5 g", "منخفض", "9%", "#4ADE80", 0.16),
                ("الدهون المشبعة", "3.2 g", "منخفض", "16%", "#86EFAC", 0.25),
                ("الملح", "1.1 g", "متوسط", "18%", "#FCD34D", 0.30),
            ],
            "today_water_title": "اليوم • الماء",
            "today_water_val": "6 / 8 أكواب",
            "today_water_btn": "+1 كوب",
        },
        "phone2": {
            "screen_title": "تحليل المنتج",
            "product_name": "بسكويت القمح الكامل",
            "why_title": "لماذا 84/100؟",
            "why_sub": "الحمل الكيميائي -4 • المخاطر -12",
            "sec_additives": "المكونات وفحص رموز E",
            "items": [
                ("E300 حمض الأسكوربيك", "مضاد أكسدة • خطر منخفض", "آمن", "safe"),
                ("E322 الليسيثين", "مستحلب طبيعي", "آمن", "safe"),
                ("E471 أحماض دهنية", "مستحلب معالج", "تنبيه", "warn"),
                ("سكر مضاف", "يؤثر سلبًا على التقييم", "خطر", "risk"),
                ("خالٍ من زيت النخيل", "تركيبة دهون نظيفة", "آمن", "safe"),
            ],
        },
    },
}


def esc(text: str, rtl: bool = False) -> str:
    escaped = html.escape(text)
    if not rtl:
        return escaped
    # Keep numeric ranges/ratios/units (0–100, 84/100, +1, 6 / 8, 380 kcal, 92%) strictly LTR inside RTL prose.
    return re.sub(
        r"(\+?\d+(?:\.\d+)?(?:\s*(?:kcal|%)|\s*[/–-]\s*\d+)?)",
        r'<span dir="ltr" style="unicode-bidi:isolate;">\1</span>',
        escaped,
    )


def file_to_data_uri(path: Path, mime: str) -> str:
    data = path.read_bytes()
    return f"data:{mime};base64,{base64.b64encode(data).decode('ascii')}"


def font_face_css() -> str:
    weights = [
        ("Regular", 400),
        ("Medium", 500),
        ("SemiBold", 600),
        ("Bold", 700),
        ("ExtraBold", 800),
    ]
    rules = []
    for name, weight in weights:
        fp = FONTS_DIR / f"PlusJakartaSans-{name}.ttf"
        if fp.exists():
            uri = file_to_data_uri(fp, "font/ttf")
            rules.append(
                f"@font-face {{ font-family: 'PlusJakartaSans'; src: url('{uri}') format('truetype'); font-weight: {weight}; font-style: normal; }}"
            )
    return "\n".join(rules)


def render_phone_primary(p: dict, rtl: bool) -> str:
    macros_html = []
    for label, val, level, pct, color, fill in p["macros"]:
        macros_html.append(f"""
        <div class="m-card" style="border-color: {color}44;">
          <div class="m-label">{html.escape(label)}</div>
          <div class="m-val" dir="ltr">{html.escape(val)}</div>
          <div class="m-bar-bg"><div class="m-bar-fill" style="width:{int(fill*100)}%; background:{color};"></div></div>
          <div class="m-foot">
            <span class="m-lvl" style="color:{color};">{html.escape(level)}</span>
            <span class="m-pct" dir="ltr">{html.escape(pct)}</span>
          </div>
        </div>
        """)
    chips_html = "".join(f'<span class="ui-chip">{esc(c, rtl)}</span>' for c in p["chips"])
    arrow_back = "&#8594;" if rtl else "&#8592;"
    return f"""
    <div class="iphone iphone-front">
      <div class="dynamic-island"><span class="cam-dot"></span></div>
      <div class="iphone-screen">
        <div class="ui-topbar">
          <span class="ui-back">{arrow_back}</span>
          <span class="ui-title">{html.escape(p["screen_title"])}</span>
        </div>
        <div class="ui-chips">{chips_html}</div>

        <div class="ui-card hp-card">
          <div class="hp-label">{html.escape(p["hp_label"])}</div>
          <div class="hp-score-row" dir="ltr">
            <span class="hp-big">{html.escape(p["score"])}</span><span class="hp-100">/100</span>
          </div>
          <div class="hp-marker-wrap" dir="ltr">
            <div class="hp-arrow" style="left: 82%;"></div>
          </div>
          <div class="hp-bands" dir="ltr">
            <div class="band b5" style="flex:40;"></div>
            <div class="band b4" style="flex:15;"></div>
            <div class="band b3" style="flex:15;"></div>
            <div class="band b2" style="flex:15;"></div>
            <div class="band b1" style="flex:15;"></div>
          </div>
        </div>

        <div class="ui-card energy-card">
          <div>
            <div class="e-lbl">{html.escape(p["energy_label"])}</div>
            <div class="e-val" dir="ltr">{html.escape(p["energy_val"])} <span>kcal</span></div>
          </div>
          <div class="e-ring"><span>{html.escape(p["energy_pct"])}</span></div>
        </div>

        <div class="macro-grid">
          {''.join(macros_html)}
        </div>

        <div class="ui-card water-mini">
          <div class="w-info">
            <span class="w-dot"></span>
            <div>
              <div class="w-t">{esc(p["today_water_title"], rtl)}</div>
              <div class="w-v">{esc(p["today_water_val"], rtl)}</div>
            </div>
          </div>
          <div class="w-btn">{esc(p["today_water_btn"], rtl)}</div>
        </div>
      </div>
      <div class="home-indicator"></div>
    </div>
    """


def render_phone_secondary(p: dict, rtl: bool) -> str:
    items_html = []
    for title, sub, badge, kind in p["items"]:
        items_html.append(f"""
        <div class="add-row add-{kind}">
          <div class="add-accent"></div>
          <div class="add-body">
            <div class="add-title">{esc(title, rtl)}</div>
            <div class="add-sub">{esc(sub, rtl)}</div>
          </div>
          <span class="add-pill pill-{kind}">{esc(badge, rtl)}</span>
        </div>
        """)
    arrow_back = "&#8594;" if rtl else "&#8592;"
    return f"""
    <div class="iphone iphone-back">
      <div class="dynamic-island"><span class="cam-dot"></span></div>
      <div class="iphone-screen">
        <div class="ui-topbar">
          <span class="ui-back">{arrow_back}</span>
          <span class="ui-title">{esc(p["screen_title"], rtl)}</span>
        </div>

        <div class="ui-card prod-head">
          <div class="prod-name">{esc(p["product_name"], rtl)}</div>
          <div class="why-box">
            <div class="why-t">{esc(p["why_title"], rtl)}</div>
            <div class="why-s">{esc(p["why_sub"], rtl)}</div>
          </div>
        </div>

        <div class="sec-hdr">{esc(p["sec_additives"], rtl)}</div>
        <div class="add-list">
          {''.join(items_html)}
        </div>
      </div>
      <div class="home-indicator"></div>
    </div>
    """


def build_html(lang: str, variant: str, css_w: int, css_h: int) -> str:
    c = COPY[lang]
    rtl = c["dir"] == "rtl"
    icon_uri = file_to_data_uri(ICON_PATH, "image/png")
    bg_uri = file_to_data_uri(BG_PHOTO_PATH, "image/jpeg")

    # Layout tuning per variant (all coords in 1x CSS px, rendered at device_scale_factor=2)
    is_header = variant == "header"
    is_search = variant == "search"
    is_universal = variant == "universal"

    # Safe margins for universal 5244x2950 (2622x1475 CSS):
    # 21:9 header crop loses ~176px top & bottom; 3:2 search crop loses ~205px left & right.
    if is_header:
        pad_x = 92
        pad_y = 66
        h1_size = 52 if lang != "ar" else 56
        sub_size = 22
        bullet_size = 18
        phone_scale = 1.0
        show_two_phones = False
        show_strip = False
    elif is_search:
        pad_x = 96
        pad_y = 86
        h1_size = 62 if lang != "ar" else 66
        sub_size = 24
        bullet_size = 19
        phone_scale = 1.10
        show_two_phones = True
        show_strip = True
    else:  # universal 2622x1475 CSS
        pad_x = 240
        pad_y = 205
        h1_size = 68 if lang != "ar" else 72
        sub_size = 27
        bullet_size = 21
        phone_scale = 1.22
        show_two_phones = True
        show_strip = True

    bullets_html = "".join(
        f'<li><span class="b-check"></span><span>{esc(b, rtl)}</span></li>'
        for b in c["bullets"]
    )
    strip_html = "".join(
        f"""
        <div class="strip-item">
          <span class="strip-dot"></span>
          <div>
            <div class="strip-t">{esc(t, rtl)}</div>
            <div class="strip-s">{esc(s, rtl)}</div>
          </div>
        </div>
        """
        for t, s in c["strip"]
    )

    phones_html = render_phone_primary(c["phone1"], rtl)
    if show_two_phones:
        phones_html = phones_html + render_phone_secondary(c["phone2"], rtl)

    photo_side_css = (
        f"left: -4%; right: auto;" if rtl else f"right: -4%; left: auto;"
    )
    scrim_dir = "to left" if rtl else "to right"
    badge_pos_css = (
        "left: -135px; bottom: 52px;" if not rtl else "right: -135px; bottom: 52px;"
    )
    if is_header:
        badge_pos_css = (
            "left: -175px; bottom: 54px;" if not rtl else "right: -175px; bottom: 54px;"
        )

    footer_block = (
        f'<div class="strip" style="padding: 0 {pad_x}px;">{strip_html}</div>'
        if show_strip
        else f'<div class="tagline" style="padding: 0 {pad_x}px;">{esc(c["footer_tagline"], rtl)}</div>'
    )

    return f"""<!DOCTYPE html>
<html lang="{lang}" dir="{c['dir']}">
<head>
<meta charset="UTF-8" />
<style>
{font_face_css()}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{
  width: {css_w}px;
  height: {css_h}px;
  overflow: hidden;
  background: #06130C;
  color: #F4FAF5;
  font-family: 'PlusJakartaSans', 'Segoe UI', 'Tahoma', 'Arial', sans-serif;
  -webkit-font-smoothing: antialiased;
}}
.canvas {{
  position: relative;
  width: {css_w}px;
  height: {css_h}px;
  overflow: hidden;
  background: radial-gradient(circle at 22% 30%, #0D291B 0%, #071910 55%, #05110B 100%);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}}
/* Food photo seamlessly feathered on opposite side of text (zero rectangular seams) */
.bg-photo {{
  position: absolute;
  top: -6%;
  height: 112%;
  width: 64%;
  {photo_side_css}
  background-image: url('{bg_uri}');
  background-size: cover;
  background-position: center;
  opacity: 0.90;
  -webkit-mask-image:
    linear-gradient({scrim_dir}, transparent 0%, rgba(0,0,0,0.45) 28%, rgba(0,0,0,1) 62%, rgba(0,0,0,0.92) 92%, transparent 100%),
    linear-gradient(to bottom, transparent 0%, black 14%, black 82%, transparent 100%);
  -webkit-mask-composite: source-in;
  mask-composite: intersect;
  pointer-events: none;
  z-index: 1;
}}
.bg-scrim {{
  position: absolute;
  inset: 0;
  background:
    linear-gradient({scrim_dir}, rgba(6,19,12,0.97) 0%, rgba(6,19,12,0.94) 40%, rgba(6,19,12,0.58) 64%, rgba(6,19,12,0.18) 100%),
    linear-gradient(to top, rgba(5,16,10,0.95) 0%, rgba(5,16,10,0.55) 18%, transparent 40%);
  z-index: 2;
}}
.main {{
  position: relative;
  z-index: 4;
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: {pad_y}px {pad_x}px {20 if is_header else 10}px {pad_x}px;
  gap: 40px;
}}
.copy-col {{
  flex: 0 0 {'50%' if is_header else '47%'};
  max-width: {'940px' if not is_universal else '1040px'};
  display: flex;
  flex-direction: column;
  gap: {22 if is_header else 28}px;
}}
.brand-row {{
  display: flex;
  align-items: center;
  gap: 18px;
}}
.app-icon {{
  width: {78 if is_header else 92}px;
  height: {78 if is_header else 92}px;
  border-radius: 22px;
  box-shadow: 0 14px 36px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.08);
  flex-shrink: 0;
}}
.brand-meta {{
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
}}
.pill {{
  display: inline-flex;
  align-items: center;
  width: fit-content;
  white-space: nowrap;
  padding: 7px 16px;
  border-radius: 999px;
  background: linear-gradient(135deg, #22C55E, #16A34A);
  color: #FFFFFF;
  font-size: {13 if is_header else 14}px;
  font-weight: 800;
  letter-spacing: {'0.6px' if lang != 'ar' else '0px'};
  box-shadow: 0 8px 22px rgba(22,163,74,0.35);
}}
.brand-name {{
  font-size: {24 if is_header else 28}px;
  font-weight: 800;
  color: #DDF7E5;
  letter-spacing: -0.3px;
}}
h1 {{
  font-size: {h1_size}px;
  font-weight: 800;
  line-height: {1.12 if lang != 'ar' else 1.24};
  letter-spacing: {'-1.2px' if lang != 'ar' else '0px'};
  color: #FFFFFF;
  text-shadow: 0 6px 24px rgba(0,0,0,0.45);
}}
.subtitle {{
  font-size: {sub_size}px;
  font-weight: 600;
  line-height: 1.4;
  color: #F0D7A5;
}}
.bullets {{
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: {13 if is_header else 16}px;
  margin-top: 4px;
}}
.bullets li {{
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: {bullet_size}px;
  font-weight: 500;
  color: #EBF5EE;
  line-height: 1.35;
}}
.b-check {{
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #16A34A;
  border: 4px solid #4ADE80;
  box-shadow: 0 0 12px rgba(74,222,128,0.45);
  flex-shrink: 0;
}}

/* Stage & Mockups */
.stage-col {{
  position: relative;
  flex: 1;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}}
.phones-wrap {{
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  transform: scale({phone_scale});
  transform-origin: center center;
  height: 680px;
  width: {'340px' if not show_two_phones else '650px'};
}}
.iphone {{
  width: 312px;
  height: 646px;
  border-radius: 46px;
  padding: 10px;
  background: linear-gradient(145deg, #3A4D43 0%, #16211B 48%, #2C3D34 100%);
  box-shadow:
    0 34px 75px rgba(0,0,0,0.72),
    0 0 0 1px rgba(140,180,155,0.28),
    inset 0 0 0 2px #09110B;
  position: relative;
}}
.iphone-front {{
  z-index: 6;
}}
.iphone-back {{
  z-index: 4;
  transform: scale(0.92) translateY(-20px);
  margin-{'right' if rtl else 'left'}: -28px;
  opacity: 0.96;
}}
.dynamic-island {{
  position: absolute;
  top: 17px;
  left: 50%;
  transform: translateX(-50%);
  width: 84px;
  height: 22px;
  border-radius: 999px;
  background: #020503;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding-right: 7px;
}}
.cam-dot {{
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: radial-gradient(circle at 35% 35%, #2B5940, #07120C);
}}
.iphone-screen {{
  width: 100%;
  height: 100%;
  border-radius: 37px;
  background: #070D07;
  padding: 42px 13px 22px 13px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 7px;
}}
.home-indicator {{
  position: absolute;
  bottom: 16px;
  left: 50%;
  transform: translateX(-50%);
  width: 98px;
  height: 4px;
  border-radius: 999px;
  background: rgba(255,255,255,0.45);
  z-index: 10;
}}
.ui-topbar {{
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 2px 2px 4px 2px;
}}
.ui-back {{ font-size: 14px; color: #DDF7E5; font-weight: 700; }}
.ui-title {{ font-size: 13.5px; font-weight: 800; color: #F0FDF4; }}
.ui-chips {{ display: flex; gap: 6px; flex-wrap: nowrap; }}
.ui-chip {{
  font-size: 9.5px;
  font-weight: 700;
  color: #86EFAC;
  background: #132515;
  border: 1px solid #244028;
  padding: 3px 8px;
  border-radius: 999px;
  white-space: nowrap;
}}
.ui-card {{
  background: #141E14;
  border: 1px solid #223222;
  border-radius: 16px;
  padding: 10px 12px;
}}
.hp-label {{
  font-size: 8px;
  font-weight: 700;
  letter-spacing: {'0.6px' if lang != 'ar' else '0px'};
  color: #6B946B;
}}
.hp-score-row {{
  margin: 4px 0 6px 0;
  display: flex;
  align-items: baseline;
  gap: 2px;
}}
.hp-big {{ font-size: 28px; font-weight: 800; color: #4ADE80; line-height: 1; }}
.hp-100 {{ font-size: 12px; font-weight: 700; color: #5C885C; }}
.hp-marker-wrap {{ position: relative; height: 7px; }}
.hp-arrow {{
  position: absolute;
  top: 0;
  transform: translateX(-50%);
  width: 0;
  height: 0;
  border-left: 4px solid transparent;
  border-right: 4px solid transparent;
  border-top: 5px solid #4ADE80;
}}
.hp-bands {{ display: flex; gap: 3px; height: 7px; }}
.band {{ border-radius: 999px; }}
.b5 {{ background: #F8717144; }}
.b4 {{ background: #FB923C44; }}
.b3 {{ background: #FCD34D44; }}
.b2 {{ background: #86EFAC66; }}
.b1 {{ background: #4ADE80; box-shadow: 0 0 8px #4ADE8088; }}

.energy-card {{
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 9px 12px;
}}
.e-lbl {{ font-size: 9px; color: #78A378; font-weight: 600; }}
.e-val {{ font-size: 18px; font-weight: 800; color: #F0FDF4; margin-top: 2px; }}
.e-val span {{ font-size: 10px; font-weight: 600; color: #78A378; }}
.e-ring {{
  width: 34px;
  height: 34px;
  border-radius: 50%;
  border: 3px solid #223322;
  border-top-color: #4ADE80;
  border-right-color: #4ADE80;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 8.5px;
  font-weight: 800;
  color: #DDF7E5;
}}
.macro-grid {{
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px;
}}
.m-card {{
  background: #121C12;
  border: 1px solid #233323;
  border-radius: 12px;
  padding: 7px 9px;
}}
.m-label {{ font-size: 8.5px; color: #84AC84; font-weight: 600; }}
.m-val {{ font-size: 13px; font-weight: 800; color: #F0FDF4; margin: 2px 0 4px 0; }}
.m-bar-bg {{ height: 3.5px; border-radius: 999px; background: #1E2E1E; overflow: hidden; }}
.m-bar-fill {{ height: 100%; border-radius: 999px; }}
.m-foot {{ display: flex; justify-content: space-between; margin-top: 4px; font-size: 7.5px; font-weight: 700; }}
.m-pct {{ color: #6B946B; }}

.water-mini {{
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 10px;
  background: linear-gradient(135deg, #122419, #101D14);
  border-color: #244530;
}}
.w-info {{ display: flex; align-items: center; gap: 7px; }}
.w-dot {{
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #38BDF8;
  box-shadow: 0 0 8px rgba(56,189,248,0.65);
}}
.w-t {{ font-size: 8.5px; color: #86EFAC; font-weight: 700; }}
.w-v {{ font-size: 10.5px; color: #F0FDF4; font-weight: 800; }}
.w-btn {{
  padding: 4px 9px;
  border-radius: 999px;
  background: #16A34A;
  color: #FFFFFF;
  font-size: 8.5px;
  font-weight: 800;
  white-space: nowrap;
}}

/* Secondary Phone */
.prod-head {{ display: flex; flex-direction: column; gap: 6px; }}
.prod-name {{ font-size: 13px; font-weight: 800; color: #F0FDF4; }}
.why-box {{
  background: #0E170E;
  border: 1px solid #223522;
  border-radius: 10px;
  padding: 7px 9px;
}}
.why-t {{ font-size: 10.5px; font-weight: 800; color: #4ADE80; }}
.why-s {{ font-size: 8.5px; color: #84AC84; margin-top: 2px; }}
.sec-hdr {{ font-size: 10.5px; font-weight: 800; color: #DDF7E5; margin-top: 4px; }}
.add-list {{ display: flex; flex-direction: column; gap: 7px; }}
.add-row {{
  display: flex;
  align-items: center;
  gap: 8px;
  background: #141E14;
  border: 1px solid #223222;
  border-radius: 12px;
  padding: 8px 9px;
}}
.add-accent {{ width: 3.5px; height: 24px; border-radius: 999px; flex-shrink: 0; }}
.add-safe .add-accent {{ background: #4ADE80; }}
.add-warn .add-accent {{ background: #FCD34D; }}
.add-risk .add-accent {{ background: #F87171; }}
.add-body {{ flex: 1; min-width: 0; }}
.add-title {{ font-size: 10px; font-weight: 700; color: #F0FDF4; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
.add-sub {{ font-size: 8px; color: #78A378; margin-top: 1px; }}
.add-pill {{
  font-size: 7.5px;
  font-weight: 800;
  padding: 3px 7px;
  border-radius: 999px;
  white-space: nowrap;
}}
.pill-safe {{ background: #14331E; color: #4ADE80; }}
.pill-warn {{ background: #362B12; color: #FCD34D; }}
.pill-risk {{ background: #3B181A; color: #F87171; }}

/* Floating Badge */
.floating-badge {{
  position: absolute;
  {badge_pos_css}
  z-index: 12;
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 20px;
  border-radius: 20px;
  background: rgba(11, 28, 18, 0.94);
  border: 1.5px solid rgba(74, 222, 128, 0.38);
  box-shadow: 0 22px 48px rgba(0,0,0,0.68);
  backdrop-filter: blur(14px);
}}
.fb-circle {{
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: linear-gradient(135deg, #22C55E, #16A34A);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  font-weight: 800;
  color: #FFFFFF;
  flex-shrink: 0;
}}
.fb-title {{ font-size: 16px; font-weight: 800; color: #FFFFFF; white-space: nowrap; }}
.fb-sub {{ font-size: 12.5px; font-weight: 600; color: #6EE7A0; margin-top: 2px; white-space: nowrap; }}

/* Bottom Strip / Tagline */
.tagline {{
  position: relative;
  z-index: 4;
  padding-bottom: 34px !important;
  font-size: 15px;
  font-weight: 500;
  color: #9CC0A8;
}}
.strip {{
  position: relative;
  z-index: 4;
  padding-bottom: {'205px' if is_universal else '58px'} !important;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 24px;
}}
.strip-item {{
  display: flex;
  align-items: flex-start;
  gap: 11px;
}}
.strip-dot {{
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: #22C55E;
  box-shadow: 0 0 10px rgba(34,197,94,0.6);
  margin-top: 5px;
  flex-shrink: 0;
}}
.strip-t {{
  font-size: {16 if is_universal else 15}px;
  font-weight: 800;
  color: #FFFFFF;
}}
.strip-s {{
  font-size: {13.5 if is_universal else 12.5}px;
  color: #9CC0A8;
  margin-top: 3px;
}}
</style>
</head>
<body>
  <div class="canvas">
    <div class="bg-photo"></div>
    <div class="bg-scrim"></div>
    <div class="main">
      <div class="copy-col">
        <div class="brand-row">
          <img class="app-icon" src="{icon_uri}" alt="NutriLens" />
          <div class="brand-meta">
            <div class="pill">{html.escape(c['pill'])}</div>
            <div class="brand-name">{html.escape(c['brand'])}</div>
          </div>
        </div>
        <h1>{esc(c['h1_line1'], rtl)}<br />{esc(c['h1_line2'], rtl)}</h1>
        <div class="subtitle">{esc(c['subtitle'], rtl)}</div>
        <ul class="bullets">{bullets_html}</ul>
      </div>

      <div class="stage-col">
        <div class="phones-wrap">
          {phones_html}
          <div class="floating-badge">
            <div class="fb-circle" dir="ltr">84</div>
            <div>
              <div class="fb-title">{esc(c['badge_title'], rtl)}</div>
              <div class="fb-sub">{esc(c['badge_sub'], rtl)}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    {footer_block}
  </div>
</body>
</html>"""


def main():
    specs = [
        ("universal", 2622, 1475, "universal_5244x2950.png"),
        ("header", 1920, 823, "header_3840x1646.png"),
        ("search", 1920, 1280, "search_results_3840x2560.png"),
    ]
    temp_png = ROOT / "tools" / "_tmp_render.png"

    with sync_playwright() as p:
        browser = p.chromium.launch()
        for lang in LANGUAGES:
            out_store_lang = OUT_DIR_STORE / lang
            out_assets_lang = OUT_DIR_ASSETS / lang
            out_store_lang.mkdir(parents=True, exist_ok=True)
            out_assets_lang.mkdir(parents=True, exist_ok=True)

            for variant, css_w, css_h, filename in specs:
                page = browser.new_page(
                    viewport={"width": css_w, "height": css_h},
                    device_scale_factor=2,
                )
                page.set_content(build_html(lang, variant, css_w, css_h), wait_until="load")
                page.screenshot(path=str(temp_png), type="png")
                page.close()

                # Flatten RGBA -> 24-bit RGB PNG (Apple requires no alpha channel)
                with Image.open(temp_png) as im:
                    rgb = im.convert("RGB")
                    expected = (css_w * 2, css_h * 2)
                    assert rgb.size == expected, f"Size mismatch: {rgb.size} != {expected}"
                    assert rgb.mode == "RGB", f"Mode mismatch: {rgb.mode}"

                    p1 = out_store_lang / filename
                    p2 = out_assets_lang / filename
                    rgb.save(p1, format="PNG", optimize=True)
                    rgb.save(p2, format="PNG", optimize=True)

                    if lang == "tr":
                        OUT_DIR_STORE.mkdir(parents=True, exist_ok=True)
                        OUT_DIR_ASSETS.mkdir(parents=True, exist_ok=True)
                        rgb.save(OUT_DIR_STORE / filename, format="PNG", optimize=True)
                        rgb.save(OUT_DIR_ASSETS / filename, format="PNG", optimize=True)

                print(f"[OK] {lang}/{filename} -> {expected[0]}x{expected[1]} RGB PNG")

        browser.close()

    if temp_png.exists():
        temp_png.unlink()


if __name__ == "__main__":
    main()
