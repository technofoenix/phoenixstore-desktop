# PhoenixStore Desktop: before / after

Every screen, dialog and state was rendered by the UI inspector (`test/inspector/screens_test.dart`) with the same fake data, at 4 window sizes and in 3 languages. The **before** set comes from an untouched copy of the previous code; the **after** set from the redesign. Screenshots are in `before/` and `after/` (`<screen>_<lang>_<size>.png`); raw results in `before/report.json` and `after/report.json`.

> Note: in the before shots, a few labels (selected tab, the main button) show as blocks. The old theme gave those styles no font, so the test renderer had none to use; on macOS they fell back to the system font. Everything else is rendered as the app draws it.

## Summary

| Check | Before | After |
|---|---|---|
| Renders with a layout error (overflow) | 96 of 396 | **0 of 396** |
| Arabic screens laid out right to left | 0 of 132 | **132 of 132** |
| Screens that change language | 0 (always English) | **all** (AR / FR / EN) |
| Hard-coded visible strings found by `test/i18n_test.dart` | 153 | **0** |
| Translation keys used | 0 (8 unused keys) | **229** per language, same set in all 3 |
| Settings page / language switcher | none | **Settings → Language**, applied at once, kept after restart |
| `flutter analyze` | No issues found | **No issues found** |
| Tests | 2 files | **5 files** (+ i18n, language switch, inspector: 396 renders) |

## What changed, screen by screen

| Screen | Before | After |
|---|---|---|
| Shell | Light icon rail with tiny labels; top bar repeated the page title, the boutique dropdown and user. Sign out was an unlabeled icon. | Dark sidebar with full labels (icons with tooltips below 1180 px), boutique switcher at the top, **Settings** and the user card with Sign out at the bottom, ⌘/Ctrl + 1…6 shortcuts. Each page has one header with its one main action. |
| Sign in | English only; one error box for every problem. | Language picker before sign-in, errors under the field they concern, Enter moves from phone to password, brand panel with three plain feature lines. |
| Sell | Two equal search fields; payment in a dropdown; discount/tax always open; a plain "TOTAL"; print button without a label. | Scanner first and focused; family/category menus and a stock segmented control on one line; product cards show what is already on the ticket; payment is **one click** (4 large toggles); credit fields only for Credit; discount and tax folded away; the main button reads **"Complete sale · 1 800,00 DA"**; the print menu has a tooltip; scan results appear as a timed message. |
| Sale completed | Small alert with raw codes (CASH). | Clear confirmation: amount, payment method in words, what is left to pay, **Print invoice** as the main action. |
| Sales history | Data table with raw status codes (PARTIAL), columns overflowed below 1024 px. | Status pills in words and colour, columns that drop away on narrow windows instead of overflowing, a payment action only where something is left to pay, empty state with **Start a sale**. |
| Record a payment | Bare form. | Balance shown first, **Whole balance** shortcut, payment method as one click, error under the amount. |
| Stock | Card grid; print button labelled "Stock statement". | Three summary tiles (products, low stock, value), a table with coloured stock pills, **Print stock statement** as the one main action. |
| Orders / new order | Raw status codes; composer ignored catalogue errors. | Status pills in words, two-pane composer with the order count and total always visible, catalogue errors shown with Retry. |
| Charges / record a charge | Fixed-width summary cards overflowed at 1024 and 900 px; one error line for the whole form. | Responsive tiles, period as one-click segments, errors under each field, labels for every category and payment method. |
| States | Spinner, or a sentence and a Retry button. | Skeleton loading, empty states that say what will appear and how, error states with a readable message and **Try again**. |
| Settings | — | New: language cards (العربية / Français / English, each in its own script) and an "About this till" panel. |

## Side by side (1440 × 900)

### Sign in

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/login_en_1440x900.png) | ![](after/login_fr_1440x900.png) | ![](after/login_ar_1440x900.png) |

### Sell, ticket filled

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/sell_ticket_en_1440x900.png) | ![](after/sell_ticket_fr_1440x900.png) | ![](after/sell_ticket_ar_1440x900.png) |

### Sell, credit sale

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/sell_credit_en_1440x900.png) | ![](after/sell_credit_fr_1440x900.png) | ![](after/sell_credit_ar_1440x900.png) |

### Dialog: sale completed

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/dialog_sale_completed_en_1440x900.png) | ![](after/dialog_sale_completed_fr_1440x900.png) | ![](after/dialog_sale_completed_ar_1440x900.png) |

### Sales history

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/history_loaded_en_1440x900.png) | ![](after/history_loaded_fr_1440x900.png) | ![](after/history_loaded_ar_1440x900.png) |

### Dialog: record a payment

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/dialog_record_payment_en_1440x900.png) | ![](after/dialog_record_payment_fr_1440x900.png) | ![](after/dialog_record_payment_ar_1440x900.png) |

### Stock

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/stock_loaded_en_1440x900.png) | ![](after/stock_loaded_fr_1440x900.png) | ![](after/stock_loaded_ar_1440x900.png) |

### Orders

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/orders_loaded_en_1440x900.png) | ![](after/orders_loaded_fr_1440x900.png) | ![](after/orders_loaded_ar_1440x900.png) |

### Dialog: new order

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/dialog_new_order_en_1440x900.png) | ![](after/dialog_new_order_fr_1440x900.png) | ![](after/dialog_new_order_ar_1440x900.png) |

### Charges

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/charges_loaded_en_1440x900.png) | ![](after/charges_loaded_fr_1440x900.png) | ![](after/charges_loaded_ar_1440x900.png) |

### Dialog: record a charge

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/dialog_record_charge_en_1440x900.png) | ![](after/dialog_record_charge_fr_1440x900.png) | ![](after/dialog_record_charge_ar_1440x900.png) |

### Sales history, empty

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/history_empty_en_1440x900.png) | ![](after/history_empty_fr_1440x900.png) | ![](after/history_empty_ar_1440x900.png) |

### Orders, error

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| ![](before/orders_error_en_1440x900.png) | ![](after/orders_error_fr_1440x900.png) | ![](after/orders_error_ar_1440x900.png) |

### Settings (new)

| Before (en) | After (fr) | After (ar) |
|---|---|---|
| did not exist | ![](after/settings_fr_1440x900.png) | ![](after/settings_ar_1440x900.png) |

## Inspector results at every width

Each cell covers the three languages. **pass** = rendered with no layout error, the screen was reached, and the direction is right (RTL for Arabic, LTR otherwise). Before: `overflow ×n` counts layout errors across the three languages; `missing` = the screen did not exist.

| Screen / state | Before 1440x900 | Before 1280x800 | Before 1024x768 | Before 900x640 | After 1440x900 | After 1280x800 | After 1024x768 | After 900x640 |
|---|---|---|---|---|---|---|---|---|
| Boot (starting) | ok | ok | ok | ok | pass | pass | pass | pass |
| Sign in | ok | ok | ok | ok | pass | pass | pass | pass |
| Sign in, field errors | ok | ok | ok | ok | pass | pass | pass | pass |
| Choose a new password | ok | ok | ok | ok | pass | pass | pass | pass |
| Account unavailable | ok | ok | ok | ok | pass | pass | pass | pass |
| Boutique could not open | ok | ok | ok | ok | pass | pass | pass | pass |
| Sell, catalogue | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sell, empty catalogue | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sell, server error | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sell, loading | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sales history | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sales history, empty | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sales history, error | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sales history, loading | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Stock | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Stock, empty | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Stock, error | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Stock, loading | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Orders | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Orders, empty | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Orders, error | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Orders, loading | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Charges | ok | ok | overflow ×3 | overflow ×6 | pass | pass | pass | pass |
| Charges, empty | ok | ok | overflow ×3 | overflow ×6 | pass | pass | pass | pass |
| Charges, error | ok | ok | overflow ×3 | overflow ×6 | pass | pass | pass | pass |
| Charges, loading | ok | ok | overflow ×3 | overflow ×6 | pass | pass | pass | pass |
| Sell, ticket filled | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Sell, credit sale | ok | ok | ok | overflow ×6 | pass | pass | pass | pass |
| Dialog: sale completed | ok | ok | ok | overflow ×6 | pass | pass | pass | pass |
| Dialog: record a payment | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Dialog: new order | ok | ok | ok | overflow ×3 | pass | pass | pass | pass |
| Dialog: record a charge | ok | ok | overflow ×3 | overflow ×6 | pass | pass | pass | pass |
| Settings (new) | missing | missing | missing | missing | pass | pass | pass | pass |

## Checklist: every screen in all 3 languages

Verified by the inspector (text from the language file, direction, no overflow at 4 widths) and by `test/i18n_test.dart` (no hard-coded text, same keys and placeholders in the 3 files). The main action of each screen was exercised in the inspector run (tapping into tickets, dialogs, tabs).

| Screen | Main action | العربية (RTL) | Français | English |
|---|---|---|---|---|
| Boot | — | ✅ | ✅ | ✅ |
| Sign in | Sign in | ✅ | ✅ | ✅ |
| Choose a new password | Save password | ✅ | ✅ | ✅ |
| Account unavailable | Sign out | ✅ | ✅ | ✅ |
| Boutique could not open | Try again | ✅ | ✅ | ✅ |
| Sell (catalogue, ticket, credit, empty, error, loading) | Complete sale | ✅ | ✅ | ✅ |
| Sale completed dialog | Print invoice | ✅ | ✅ | ✅ |
| Sales history (all states) | Record a payment | ✅ | ✅ | ✅ |
| Record a payment dialog | Record payment | ✅ | ✅ | ✅ |
| Stock (all states) | Print stock statement | ✅ | ✅ | ✅ |
| Orders (all states) | New order | ✅ | ✅ | ✅ |
| New order dialog | Send order | ✅ | ✅ | ✅ |
| Charges (all states) | Record a charge | ✅ | ✅ | ✅ |
| Record a charge dialog | Save charge | ✅ | ✅ | ✅ |
| Settings | Change language | ✅ | ✅ | ✅ |

Language switching: `test/language_switch_test.dart` opens Settings in French, picks العربية, checks the screen is Arabic and right-to-left at once, checks the choice is saved, restarts the app and checks it opens in Arabic. ✅

## Not covered by these checks

- The inspector uses a fake API. Real sales, payments, orders and printing were not run against your server in this session. Run through them once with `flutter run -d macos` before shipping.
- Printed PDFs stay in French by decision. Their wording now lives in `lib/locale/documents.json`.
- Messages written by the server (validation errors, account-blocked reason) are shown as the server sends them.

## Round 2: quantities, clients, details, list PDFs, stock filters

Inspector after round 2: **516 renders, 0 with errors**, every Arabic render RTL.

| New screen / state | 1440x900 | 1280x800 | 1024x768 | 900x640 |
|---|---|---|---|---|
| Clients | pass | pass | pass | pass |
| Clients, empty | pass | pass | pass | pass |
| Clients, error | pass | pass | pass | pass |
| Clients, loading | pass | pass | pass | pass |
| Dialog: client and their sales | pass | pass | pass | pass |
| Dialog: sale details | pass | pass | pass | pass |
| Dialog: order details | pass | pass | pass | pass |
| Sell, quantity typed (7) | pass | pass | pass | pass |
| New order, quantity typed (48) | pass | pass | pass | pass |
| Stock filtered Famille › Catégorie | pass | pass | pass | pass |

| Screen | AR | FR | EN |
|---|---|---|---|
| Clients | ✅ | ✅ | ✅ |
| Clients, empty | ✅ | ✅ | ✅ |
| Clients, error | ✅ | ✅ | ✅ |
| Clients, loading | ✅ | ✅ | ✅ |
| Dialog: client and their sales | ✅ | ✅ | ✅ |
| Dialog: sale details | ✅ | ✅ | ✅ |
| Dialog: order details | ✅ | ✅ | ✅ |
| Sell, quantity typed (7) | ✅ | ✅ | ✅ |
| New order, quantity typed (48) | ✅ | ✅ | ✅ |
| Stock filtered Famille › Catégorie | ✅ | ✅ | ✅ |

Screenshots: `after/<scenario>_<lang>_<size>.png` (for example `after/dialog_sale_details_fr_1440x900.png`). List PDFs (sales, clients, stock, orders, charges) are checked by `test/widget_test.dart` ("every list kind builds a French PDF").
