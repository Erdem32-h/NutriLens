# GS1 Digital Link QR Reading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A GS1 Digital Link QR opens the product page for its GTIN and shows lot / expiry / producer-page link.

**Architecture:** Pure on-device parser in `lib/core/utils`; scanner swaps the QR URL for the GTIN before validation and passes the parsed link to the product route via GoRouter `extra`; a stateless card on the product page renders it.

**Tech Stack:** Flutter, GoRouter, url_launcher (already a dependency), gen-l10n (6 ARB files).

**Spec:** `docs/superpowers/specs/2026-10-29-gs1-digital-link-design.md`

## Global Constraints

- `https` only; non-GS1 URLs still rejected with `invalidBarcode` snackbar.
- The scanned URL never goes to analytics or servers; analytics only gets `'source': 'digital_link'`.
- Link opens with `LaunchMode.externalApplication`.
- New strings in all 6 ARBs: tr, en, es, pt, ar, zh.

## Review Focus

- QR with uppercase host / trailing slash / extra query params → still parses (parser test `extra params and trailing slash`).
- GTIN-14 not starting with `0` (real ITF-14 / packaging-level GTIN) → kept as 14 digits (parser test `gtin14 without leading zero`).
- Expiry `DD=00` in December → 31 Dec, not overflow (parser test `dd 00 december`).
- Product page opened from history / deep link (no `extra`) → no card, no crash (widget test via `digitalLink: null`).
- Malformed percent-encoding in lot → returns link with lot null rather than throwing (parser test `bad percent encoding`).

---

### Task 1: Parser

**Files:**
- Create: `lib/core/utils/gs1_digital_link.dart`
- Test: `test/core/utils/gs1_digital_link_test.dart`

**Interfaces:**
- Produces: `class Gs1DigitalLink { final String gtin; final String? lot; final DateTime? expiry; final Uri uri; static Gs1DigitalLink? tryParse(String raw); }` (const constructor, immutable).
- Consumes: `BarcodeValidator.hasValidGtinCheckDigit(String)`.

- [ ] **Step 1: Write failing tests** — cases (input → expected):
  - `https://id.example.com/01/08690504000013` → gtin `8690504000013`, lot null, expiry null
  - `https://x.io/p/01/08690504000013/10/LOT%2042?17=271231` → gtin `8690504000013`, lot `LOT 42`, expiry `DateTime(2027,12,31)`
  - `https://x.io/01/8690504000013` (13 digits) → gtin `8690504000013`
  - gtin14 without leading zero `https://x.io/01/18690504000010` → gtin `18690504000010`
  - dd 00 december `...?17=271200` → `DateTime(2027,12,31)`; `?17=270200` → `DateTime(2027,2,28)`
  - extra params and trailing slash: `HTTPS://X.IO/01/08690504000013/?utm=a&17=270101` → gtin ok, expiry `2027-01-01`
  - bad percent encoding: `/10/%E0%A4%A` → lot null, gtin ok
  - null cases: `http://x.io/01/08690504000013`, `https://x.io/01/08690504000014` (bad check), `https://example.com/menu`, `https://x.io/01/abc`, `8690504000013`, `?17=271340` → expiry null (invalid month)
- [ ] **Step 2:** `flutter test test/core/utils/gs1_digital_link_test.dart` → FAIL (file missing).
- [ ] **Step 3: Implement.** `Uri.tryParse`; scheme lowercase == `https`; find first `01` in `pathSegments`, next segment `^\d{8}$|^\d{12,14}$` and valid check digit; pad to 14, if starts with `0` drop it (→13). Lot: segment after `10` decoded with `Uri.decodeComponent` in try/catch. Expiry: `queryParameters['17']` `^\d{6}$`, month 1–12, day 0 → `DateTime(y, m + 1, 0)`, reject day > days-in-month.
- [ ] **Step 4:** same command → PASS.

### Task 2: Scanner + router wiring

**Files:**
- Modify: `lib/features/scanner/presentation/screens/scanner_screen.dart` (`_processBarcode`, ~880–967)
- Modify: `lib/config/router/app_router.dart:191-199`
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart` (constructor)

**Interfaces:**
- Consumes: `Gs1DigitalLink.tryParse`.
- Produces: `ProductDetailScreen({required String barcode, Gs1DigitalLink? digitalLink})`.

- [ ] **Step 1:** At the top of `_processBarcode`: `final link = Gs1DigitalLink.tryParse(value); if (link != null) value = link.gtin;` (make parameter a local). Add `if (link != null) 'source': 'digital_link'` to the `scanBarcodeDetected` props. Push `context.push('/product/$value', extra: link)`.
- [ ] **Step 2:** Router builder: `ProductDetailScreen(barcode: barcode, digitalLink: state.extra is Gs1DigitalLink ? state.extra as Gs1DigitalLink : null)`.
- [ ] **Step 3:** `flutter analyze` → no new issues.

### Task 3: Product card + l10n

**Files:**
- Create: `lib/features/product/presentation/widgets/digital_link_card.dart`
- Modify: `product_detail_screen.dart` `_buildProductDetail` — insert after `CounterfeitWarningBanner`: `if (widget.digitalLink != null) DigitalLinkCard(link: widget.digitalLink!)`
- Modify: `lib/l10n/app_{tr,en,es,pt,ar,zh}.arb`
- Test: `test/features/product/presentation/widgets/digital_link_card_test.dart`

**Interfaces:**
- Produces: `DigitalLinkCard({required Gs1DigitalLink link, DateTime Function()? now})` (`now` for tests).
- ARB keys: `digitalLinkLot` ("Parti: {lot}"), `digitalLinkExpiry` ("SKT: {date}"), `digitalLinkExpired` ("Süresi geçmiş"), `digitalLinkProducerPage` ("Üretici sayfası"), `digitalLinkOpenFailed` ("Bağlantı açılamadı").

- [ ] **Step 1: Failing widget tests** (tr locale, `AppTheme.light`, pattern of `compare_hint_strip_test.dart`):
  - lot+expiry future → finds `Parti: LOT 42`, `SKT: 31.12.2027`, `Üretici sayfası`, host `x.io`; no `Süresi geçmiş`.
  - expiry past (`now` = 2028-01-01) → finds `Süresi geçmiş`.
  - no lot, no expiry → only producer button + host.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** Add ARB strings (6 languages) and `flutter gen-l10n`; implement card in the blacklisted-banner idiom (padding 24/0/24/8, radius 16, `context.colors`); date `dd.MM.yyyy` via `intl` `DateFormat`; expired text `Colors.red`; button `TextButton.icon(Icons.open_in_new)` → `launchUrl(link.uri, mode: externalApplication)`, on false show snackbar `digitalLinkOpenFailed`.
- [ ] **Step 4:** run → PASS; `flutter analyze` clean; full `flutter test` green.
- [ ] **Step 5:** Device check: scan a QR of `https://id.example.com/01/08690504000013/10/LOT42?17=271231` on a real product GTIN → product page with card (screenshot).
