# GS1 Digital Link QR reading — design

Date: 2026-10-29 · Status: awaiting approval · Size: small change

## Why

Brands are moving from EAN barcodes to QR codes in the GS1 Digital Link format
(GS1 "Sunrise 2027"; vendors like qrpages.io generate them for traceability /
"digital product identity" pages). Such a QR carries a URL like
`https://brand.example/01/08690000000001/10/LOT42?17=271231`. Today
`BarcodeValidator.isLikelyBarcode` rejects anything containing `/`, so the scan
fails with "invalid barcode". NutriLens is a **reader only** (decided in chat):
it does not create or host traceability pages, and it has no legal obligation
here — EU food traceability (Reg. 178/2002 art. 18) is B2B, and the Digital
Product Passport (ESPR 2024/1781) excludes food.

## Goals

- A GS1 Digital Link QR opens the normal product page for its GTIN (HP Score
  etc. unchanged), with the same scan-limit / guest / analytics path as a
  barcode.
- The product page shows lot and expiry when the QR carries them, and a
  "Producer page / traceability" button that opens the QR's URL externally.
- Works for any brand/vendor, not just qrpages.

## Non-goals

- Fetching or rendering the producer page's data in-app (JSON-LD) — option B,
  revisit after seeing real QRs.
- Recall lookup by lot (RASFF / Tarım Bakanlığı) — separate project.
- Storing lot/expiry in history or favourites.
- Compressed Digital Link URIs, GS1 element strings (`(01)...(10)...`) in
  DataMatrix, serial (`21`) display.

## Anti-goals

- Arbitrary URL QRs must still be rejected as today (no open-any-URL scanner).
- The scanned URL is never sent to analytics or our servers.

## Approaches (picked: A)

- **A — Standard parser + link button (picked).** Parse the URL on device,
  route by GTIN, show lot/expiry + external link. Small, no server, no new
  privacy surface; works for every vendor.
- B — A + fetch JSON-LD and render origin/certificates/recall in-app. Formats
  vary by vendor and are unverified; brittle and large. Deferred.
- C — qrpages API deal. Dropped: the API is a paid producer-side plan; a reader
  does not need it.

## How

1. `lib/core/utils/gs1_digital_link.dart` — `Gs1DigitalLink.tryParse(String)`
   → `Gs1DigitalLink? {String gtin, String? lot, DateTime? expiry, Uri uri}`.
   - `https` only (my call: `http` links rejected).
   - Find the `01` path segment anywhere in the path (resolvers may prefix
     paths); next segment = GTIN, 8/12/13/14 digits, valid GS1 check digit.
   - Optional `10/<lot>` path pair (URL-decoded). Expiry from query `17`
     (YYMMDD; `DD=00` = last day of month; years 2000+).
   - GTIN normalisation: left-pad to 14, then strip one leading `0` → 13 digits
     when the 14-digit form starts with `0` (matches how EAN-13 products are
     keyed today).
2. `scanner_screen._processBarcode`: before validation, `tryParse(value)`; on
   success continue with `gtin` as the barcode and keep the link. Push
   `/product/$gtin` with `extra: link`. Analytics `scanBarcodeDetected` gets
   `'source': 'digital_link'` (no URL).
3. Router `/product/:barcode`: pass `state.extra as Gs1DigitalLink?` to
   `ProductDetailScreen(digitalLink: …)`.
4. `ProductDetailScreen`: if `digitalLink != null`, a small card near the top:
   "Lot: X · Expiry: dd.MM.yyyy" (expiry in red with "expired" label when past
   — my call), and a button "Producer page" with the URL's host as subtitle so
   the user sees where it goes; opens via `url_launcher` in external mode.
5. l10n: new strings in all 6 ARB files.

## Tests

- Unit: parser — plain GTIN-13 / GTIN-14 with leading 0, prefixed path, lot
  with encoded chars, expiry incl. `DD=00`, bad check digit, `http`, non-GS1
  URL, missing `01`.
- Widget: card shows lot/expiry/button only when `digitalLink` is given.
- Device: scan a generated test QR end to end (screenshot).

## Left to the builder

Card styling in the existing product-page idiom; exact placement among the
header widgets; ARB key names.
