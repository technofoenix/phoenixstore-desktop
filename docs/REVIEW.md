# PhoenixStore Desktop — Technical Review

Scope: `lib/` (23 files, ~5.7k lines), `pubspec.yaml`, platform runners, tests.
Date: 2026-11-08. Reviewed as a POS terminal (cash till + barcode scanner + printer) for Algerian boutiques.

**Overall verdict:** The structure is clean and small: Riverpod, a single `DesktopApi`, a secure-storage session with a fallback, and an idempotency key on sales. The codebase looks like a solid MVP. But today it is a **thin online client**: it doesn't compile, it loses the cart when the cashier changes tabs, it can't sell when the network drops, and it sends credentials over plain HTTP. Those four points come before anything else.

---

## 1. Blockers (fix first)

| # | Problem | Where | Fix |
|---|---|---|---|
| B1 | **The app doesn't compile.** 5 analyzer errors from the half-finished redesign: `AppTheme.build(Brightness)` now expects `AppLanguage`, and `AppColors.primaryDark` doesn't exist. | `lib/main.dart:34-35`, `lib/features/auth/login_screen.dart:69` | Finish the theme API migration (pass the current language from `context.locale`), use `primaryDeep`/`primaryHover`, and add `flutter analyze` to CI. |
| B2 | **The cart is lost when the tab changes.** The shell uses a `switch (_tab)`, so going to "Stock" to check a product and coming back destroys `SalesScreen` and its `_cart`. In a shop, that means a lost sale. | `lib/features/shell/desktop_shell.dart:207-255` | Move the cart into a Riverpod `Notifier` keyed by warehouse (better), or wrap the tabs in an `IndexedStack`. Also persist the cart to disk so it survives a crash or power cut. |
| B3 | **Duplicate sales on retry.** `clientReference: Uuid().v4()` is generated *inside* `createSale`. If the request times out but the server committed it, the cashier clicks again and gets a **new** UUID, so the sale is recorded twice and stock is decremented twice. Same for `createOrder`. | `lib/features/api/desktop_api.dart:72,151` | Generate the reference once per cart/checkout attempt (store it in the cart state), reuse it on every retry, and clear it only after success. The server must enforce `UNIQUE(tenantId, clientReference)` and return the existing sale. |
| B4 | **Plain HTTP by default.** `normalize()` adds `http://` when no scheme is given, and the default is `http://localhost:4000`. Phone number, password and bearer tokens travel in clear text on the shop's Wi-Fi. | `lib/core/config/server_config.dart:26-28` | Default to `https://` and refuse `http://` in release builds, except for `localhost` or an explicit "LAN mode" with a pinned certificate (see §3). |

## 2. Functional / POS-logic issues

1. **The server choice isn't persisted.** `saveServerUrl`/`readServerUrl` exist but are never called. The comments say the login screen can change the server, but no UI does that. Either build it (with an admin PIN) or remove the dead code.
2. **No offline mode.** Each barcode scan is an HTTP round-trip (`lookupBarcode`), and checkout fails if the API is unreachable. On Algerian ADSL/4G this is the #1 complaint you'll get. See §4 for the design.
3. **Barcode lookup ignores the catalog that's already loaded.** `Product.barcode` is in memory, so look it up locally first (`Map<String, Product>`) and only call the API on a miss. Scans become instant.
4. **Stock checks use stale data.** `_addProduct` compares against `product.stock` from when the catalog loaded. That's fine as a UX hint, but the server must be the authority. Refresh the catalog after each sale.
5. **Discount/tax validation.** Nothing stops a discount larger than the subtotal (the total is silently clamped to 0), `"1.2.3"` parses to 0, and tax is a free amount instead of a rate (TVA 19%/9% in DZ). Validate the inputs, and use a role-gated maximum discount (cashier ≤ X%, manager unlimited).
6. **Credit sales.** `amountPaid` can exceed the total, there's no customer record (just free text, so you can't track debts per customer), and `initialPaymentMethod` is hard-coded to `CASH`.
7. **The client sends `unitPrice`.** Make sure the server ignores it and uses its own price. Otherwise a modified client can sell at any price.
8. **Money is `double`.** `0.1+0.2` errors will appear on totals and reports. Use integer centimes (`int`) or `Decimal` end-to-end, and round only for display.
9. **Proforma/BL references are generated client-side** (`FP-yyyyMMdd-HHmmss`), so they aren't sequential and two tills can collide. Algerian invoicing expects a continuous sequence per year, so get the number from the server.
10. **Printing**: there's only A4 PDF through the system dialog. A boutique till needs **80mm/58mm thermal receipts** sent directly with no dialog (ESC/POS over USB/network), a cash-drawer kick, and a reprint option. Invoices also lack legal mentions (NIF, NIS, RC, AI, address), and "Algérie" is hard-coded.
11. **No cashier session / Z-report.** A POS needs open/close shift, an opening float, cash counted vs expected, and a daily Z report. This is the feature store owners ask for most.
12. **No returns/refunds or voids** with reasons and manager approval.
13. **Keyboard workflow.** Cashiers work by keyboard: add shortcuts (F2 search, F4 qty, F12 pay, Del remove line, Esc cancel), and quantity entry like `3*` before a scan.
14. **i18n is half done.** `en/fr/ar.json` exist and `easy_localization` is initialised, but the screens use hard-coded English strings (0 `tr(` calls in `features/`). Arabic RTL hasn't been exercised.
15. **No role gating in the UI.** Every tab (expenses, orders) is shown to every role. Hide them by role, and keep the server as the real enforcement.
16. **Tests**: only `session_store_test` and a default widget test. Add unit tests for cart totals, discount rules, idempotent checkout and token refresh.
17. Housekeeping: the README is the Flutter template, `assets/logos/` is listed twice in pubspec, `intl: any` should be pinned, `shared_preferences` is in dev_dependencies (unused), and `cupertino_icons` is unused.

## 3. Security

### Transport
- HTTPS everywhere (B4). For boutiques with a **local server on the LAN**, ship a self-signed CA and **pin it** in Dio (`IOHttpClientAdapter` → `SecurityContext` / `badCertificateCallback` comparing the SHA-256 fingerprint) instead of falling back to HTTP.
- Changing the server URL must require an admin PIN. Otherwise anyone at the till can point it at a fake server and collect passwords.

### Tokens & session
- The code comment says the access token is "long-lived". Use **short access tokens (15 min)** with a rotating refresh token and server-side revocation per device.
- **Register each terminal as a device.** On first install an admin enrols it (device ID + keypair stored in secure storage), and the server binds tokens to that device. Today `deviceId: 'desktop'` is hard-coded for all tills, so you can't revoke or audit a single till.
- The refresh flow (`api_client.dart:56-139`):
  - the bare Dio used for refresh has no timeouts;
  - when refresh fails, the user isn't logged out, so every call keeps failing with 401. Clear the session and set the auth state to `null`;
  - `refreshing = null` runs after each waiter, so it's racy. Reset it in a `whenComplete` on the shared future instead.
- **Memory fallback**: if the keychain fails, tokens live in RAM silently. That's OK, but show a warning, and never fall back to a plaintext file.
- **Inactivity lock**: lock the till after N minutes and unlock with a 4–6 digit cashier PIN (verified server-side or by a local hash). Quick cashier switching makes every sale traceable to a person.
- On logout, call the server to revoke the refresh token (today it only deletes it locally).

### Data & audit
- Every sensitive action (discount above a threshold, void, refund, drawer open, price override) should be sent with the user ID, device ID and a timestamp, and need a manager PIN.
- Error messages show `METHOD full-URI returned HTTP xxx` to cashiers (`api_client.dart:31-36`). Show that only in debug builds, and log it to a local file.
- Release builds should use `flutter build windows --obfuscate --split-debug-info=build/symbols`, and installers should be code-signed (unsigned Windows executables trigger SmartScreen and antivirus false positives on shop PCs).
- Validate the image URL host before `Image.network`: only your own CDN or API host.
- Any offline database (see §4) must be encrypted: SQLCipher, with the key in secure storage.

## 4. Performance on low-spec machines (2–4 GB RAM, old Celeron/i3, Windows 7/10, HDD)

### Rendering
- **Product grid**: `Image.network` decodes full-resolution images into a 68px box. Add `cacheWidth: 160` (or `ResizeImage`) to cut decoded memory by 10–50×, ask the API for thumbnails (`?w=160`), and add a disk cache. Or offer a "no images" setting, which is the fastest option on weak PCs.
- **`setState` on every keystroke** in discount, tax and amount fields rebuilds the *whole* screen, including the product grid. Split the cart and totals into their own widgets backed by a provider (`ref.watch(cartProvider.select(...))`) so typing only rebuilds the totals.
- `_filteredProducts`, `_familyOptions` and `_categoryOptions` are getters recomputed on every build, which means sorting thousands of items each time. Compute them once when the products or filters change, and memoise.
- `NumberFormat('#,##0.00')` is created in `build`/dialogs. Make it a `static final`.
- Avoid shadows and blur, `ClipRRect` on every tile, and animations. Add a **"Lite mode"** setting that turns off images, elevation and ink ripples (`splashFactory: NoSplash.splashFactory`).
- `DataTable` builds every row up front. For history, stock and expenses, use `ListView.builder` or a paginated table. Stock is capped at `pageSize: 100` and sales at 50 with no paging UI, so you can't see older data.

### Data
- **The catalog loads in full on every search keystroke** (with a 350 ms debounce). Instead, cache the catalog locally once, sync deltas (`?updatedSince=`), and search locally. That removes network calls and gives instant results.
- Parse large JSON with `compute()` / `Isolate.run`, so the UI thread doesn't freeze on old CPUs.
- **Offline-first architecture** (recommended for an Algerian boutique POS):
  1. A local DB (Drift + SQLite/SQLCipher) holds products, prices, stock snapshots and pending sales.
  2. Checkout writes the sale locally with its `clientReference`, prints the receipt immediately, and queues it in an outbox.
  3. A background sync pushes the outbox with retry and backoff. The server dedupes on `clientReference` (B3).
  4. Show an online/offline badge and the pending count in the top bar.

### Startup & footprint
- `EasyLocalization` loads JSON from `lib/locale`. Move those files to `assets/translations/`. Bundling `lib/` paths works but is unusual.
- Bundle a single font, and subset the Arabic font, to keep the installer small and avoid glyph fallback delays.
- Ship a **release** build only (never profile or debug). Test on a real 4 GB Windows 10 machine with an HDD, and set a target such as cold start under 3 s and scan-to-cart under 100 ms.
- Flutter Windows needs Windows 10+ and a GPU that supports ANGLE/D3D11. On very old PCs without that, rendering falls back to software (WARP), so Lite mode becomes essential. Write the minimum spec down for your resellers.

## 5. Suggested order of work

1. **Week 1** — B1 compile fix, B2 cart provider + persistence, B3 idempotent checkout, B4 HTTPS. Add CI with `flutter analyze` + tests.
2. **Week 2** — Local barcode lookup, image `cacheWidth`, split rebuilds, Lite mode, pagination.
3. **Weeks 3–4** — Thermal receipt printing + cash drawer, shift open/close + Z report, finish i18n (FR/AR + RTL).
4. **Weeks 5–6** — Offline-first (Drift + outbox), device enrolment, PIN lock, audit trail, signed + obfuscated installers.
