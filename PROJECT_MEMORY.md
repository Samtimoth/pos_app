# 📌 PROJECT MEMORY — Jikoni POS / Duka Kiganjani (donel_pos)

> **Kwa Buffy (AI agent):** Soma file hii MWANZO wa kila session kabla ya kufanya lolote.
> Mwisho wa kila kazi, UPDATE sehemu za "Hali ya sasa", "Kazi inayoendelea" na "Log".
> Mtiririko: `# Summary ya mwisho` → `# Mpango wa phases` → `# Hali ya sasa` → `# Kazi inayoendelea` → `# Maamuzi` → `# Log`.

---

# Summary ya mwisho

Project: **Jikoni POS / Duka Kiganjani** — Flutter app (POS/duka) + PHP backend (focustec.co.tz kupitia ftp.dadcas.com, `/pos/api/`).
Lugha ya mazungumzo: **Kiswahili**. UI ina SW/EN (l10n).
Ukaguzi kamili (audit) ulifanyika 2026-09-14: features 140 zilichunguliwa — app (Flutter, ~33k mistari), backend (PHP 8, endpoints 49), DB (MySQL, tables 22). Mpango wa utekelezaji ni phases 1–7 (tazama chini).

# Mpango wa phases (kutoka audit)

- **Hatua 1 (P0, ~siku 3) — Usalama wa msingi**: DB/FTP password mpya, backup ya usiku, api_tokens + Bearer, bootstrap.php (auth/permissions/audit), require_permission kwenye writes, business_id kutoka token, app ifiche vitufe kwa role.
- **Hatua 2 (P0, ~siku 4) — Wateja + malipo + marejesho**: customers table + backfill + picker POS + statement; sale_payments (split: Cash/M-Pesa/Bank) + change + historia; returns/refund/exchange + credit note; Checkout widget moja (desktop+simu).
- **Hatua 3 (P0, ~siku 3) — Stock ledger**: stock_movements + opening backfill + StockService; adjustments (damaged/lost/count/opening) + approval; stock card; unganisha batches mbili kuwa moja; FEFO.
- **Hatua 4 (P1)**: register/shift (fungua/funga, expected vs actual), VAT settings + risiti, discount ya jumla + approval ya manager (PIN), hold/resume, risiti (logo, cashier, QR, 58/80mm, A4).
- **Hatua 5 (P1)**: suppliers + PO→GRN→invoice→payment→statement, stock transfer kati ya matawi, accounts (Cash/M-Pesa/Tigo/Airtel/Bank) + cash flow + reconciliation.
- **Hatua 6 (P2)**: documents (quotation/proforma/delivery note), receipt template designer (JSON), journal ya automatic + trial balance + balance sheet, ripoti filters + PDF/CSV, slow/dead stock, design system ya Flutter.
- **Hatua 7 (P3)**: online shop + orders + stock reservation + M-Pesa STK, AI assistant, TRA/EFD (kupitia VFD aliyeidhinishwa tu).

# Hali ya sasa (kama ya 2026-09-15)

## Hatua 1 — Usalama: ✅ IMEKAMILIKA na IME-DEPLOY SERVER
- `helpers/bootstrap.php` (auto-include kupitia db.php): api_tokens (SHA-256 hash, 30d, sliding renewal), audit_log, login_throttle (5 fails → lock 15min), require_permission(), auth_check_business_scope(), roles/permissions (Owner/Admin=*, Manager, Accountant, Stockist, Cashier, Supporter, Viewer).
- login.php inatoa `auth_token`; app (api_service.dart) inahifadhi na kutuma `Authorization: Bearer` kila ombi ✅.
- Legacy window: app za zamani bila token zinaruhusiwa hadi **2026-10-31** (`AUTH_LEGACY_UNTIL`); baada ya hapo token PEKEE. Muda huo: source=legacy inapita permission checks (tabia ya zamani).
- Endpoints 19/45 zina `require_permission()` waziwazi (writes muhimu); legacy bypass inafunika tofauti mpaka window ifunge.
- **HAIJAFANYIKA bado**: kubadilisha DB/FTP passwords, backup ya usiku (cron + offsite), HSTS, uploads hardening.

## Hatua 2 — Wateja/Malipo/Marejesho: 🟡 NUSURA
- ✅ `customers` table + `customers.php` (list/get/add/update/delete; get = profile + statement: sales + tbl_loan_payments + summary).
- ✅ App: `lib/services/crm_api.dart` (listCustomers/getCustomer/saveCustomer/deleteCustomer + offline cache/push) + `customers_screen.dart` (list, debtors, VIP, statement).
- ✅ POS: kitufe "Chagua mteja" (`_PickCustomerButton`) — inafungua CustomersScreen(pickMode) na kujaza jina/simu kwenye checkout form.
- ✅ Historia ya malipo: `pay_loan.php` inaandika `tbl_loan_payments` + `get_sale_payments.php` + app `getSalePayments()`.
- ✅ `customer_id` sasa inahifadhiwa kwenye tbl_sales moja kwa moja (`create_sale.php` inathibitisha id dhidi ya business_id kabla ya kuamini); POS (`pos_screen.dart`) inatuma `customerId`/`customerPhone` badala ya string tu, offline queue (`offline_api_service.dart`/`sync_service.dart`) inatatua temp-id→real-id kabla ya sync.
- ✅ **Returns/refunds**: `sale_returns.php` (list/create) — inarudisha stock (trigger iliyopo), inahesabu upya total/paid/balance/payment_status ya mauzo, inaonya cash ya kurudisha mteja pale inapohitajika; `sale_return_sheet.dart` UI (item picker + stepper), kitufe "Rudisha Bidhaa" kwenye `transaction_detail_sheet.dart` kikiwa kimefungwa na `user.canReturnSales` (cashier+). Online-only kwa makusudi (haijawekwa kwenye `OfflineApiService`). Imekwisha-deploy + push kwenye PR #1 (commit 3f9861a, 2026-09-16).
- ❌ **Bado hakuna**: sale_payments table ya split payment ya kweli (Cash+M-Pesa+Bank moja) + change kwenye server, credit notes rasmi (returns zinaonyesha refund lakini hazitoi hati ya "credit note" tofauti), backfill ya sales za zamani → customers, Checkout widget moja (desktop `_CartPanel` + simu `_CartSheet` bado mbili — uamuzi wa makusudi kuahirisha).

## Hatua 3 — Stock ledger: 🟡 ILIANZA
- ✅ `stock_movements.php` (stock card + recent movements) + `adjustStock` kwenye crm_api (adjustment sheet kwenye app).
- ❌ Bado: StockService moja kwa writes ZOTE (sales/void/batch/transfer bado zinabadilisha stock moja kwa moja), opening-balance backfill, kuunganisha `product_batches` na `tbl_product_stock_batch`, FEFO, approval ya adjustments.

## FTP / Deploy
- Credentials: `%USERPROFILE%\.duka_ftp.env` (FTP_HOST=ftp.dadcas.com, API dir `/pos/api`, web dir `/pos/app`) — **nje ya repo, usi-print**.
- Tools: `tools/deploy.py` (check | pull-api | patch-api | push-api | build-web | push-web | web | api), `tools/sync_web.py` (resumable web deploy).
- 2026-09-15: FTP imeunganishwa ✅ — local mirror PHP 53/53 zipo server (0 missing). Server ina pia `.bak_before_sync` backups.
- Windows note: tumia `PYTHONIOENCODING=utf-8` kabla ya python (iziepuke UnicodeEncodeError ya ✓).

# Kazi inayoendelea / zinazofuata (kwa mpangilio)

1. **Kamilisha Hatua 2 (kilichobaki)**: (a) ~~customer_id kwenye tbl_sales~~ ✅ imekamilika; (b) backfill ya sales za zamani → customers; (c) sale_payments table (split + change + historia inayokamilika); (d) ~~returns/refunds~~ ✅ imekamilika (credit note rasmi bado haijafanyika); (e) Checkout widget moja.
2. **Kamilisha Hatua 3**: StockService moja, opening backfill, batches moja, FEFO.
3. **Usalama wa ziada (Hatua 1 residuals)**: badilisha DB/FTP passwords (za sasa zimeonekana kwenye chat — dharura), backup ya usiku cron + offsite.
4. Kabla ya 2026-10-31: hakikisha app zote zimetoka na token auth, kisha weka `AUTH_ALLOW_LEGACY = false`.

# Maamuzi muhimu (yaliyokubaliwa)

- Architecture: "usibomoe" — PHP backend inabaki; tabaka moja la kati (bootstrap.php: auth + permissions + audit + validation); endpoints zinaita helpers.
- Offline-first inabaki: kila feature mpya ya kuandika ipite `OfflineApiService` (online → cache; offline → queue, `client_op_id` idempotency).
- Kila migration inaongeza tu (ADD COLUMN/CREATE TABLE), inabeba data ya zamani, ina script ya kurudi nyuma, inajaribiwa kwenye copy ya DB kwanza.
- Apps ndogo `kukupaja_*` / `kukusoko_*` haziguswi bila ruhusa.

# Log (mfululizo wa kazi)

- 2026-09-16: `customer_id` imeunganishwa kwenye create_sale (offline+online), na feature ya **Returns/Refunds** kamili (`sale_returns.php` + `sale_return_sheet.dart` + `canReturnSales` permission) imejengwa, ime-deploy live, `flutter analyze` 0 issues, `flutter test` 27/27 ✅, imesukumwa (push) kwenye branch `feature/hatua-1-3-security-crm-stock-ledger` (commit 3f9861a) juu ya PR #1 iliyopo.
- 2026-09-15: FTP imeunganishwa (deploy.py check ✅, 0 files missing kwenye server); uthibitisho wa code: Hatua 1 ✅ ime-deploy (bootstrap.php/tokens/audit/throttle), Hatua 2 nusura (customers ✅, malipo historia ✅; split/returns/customer_id-on-sale ❌), Hatua 3 ilianza (stock_movements ✅). Memory + skill `project-memory` zimetengenezwa.
- 2026-09-14: Audit kamili (features 140) + mpango wa phases 1–7; kazi za server endpoints + deploy tools + Jikoni intake ya Excel. (Maelezo ya sessions za kabla ya 2026-09-15 hayapatikani tena; file hii ndiyo kumbukumbu rasmi kuanzia sasa.)

---

# Sheria za kujibu (kwa Buffy)

1. Kiswahili rahisi, mfupi.
2. Usibadilishe apps za `kukupaja_*` / `kukusoko_*` bila ruhusa.
3. Kabla ya deploy (sync_web.py / deploy.py push-api / push-web) — uliza ruhusa.
4. Credentials haziprintwi kamwe; ziko `%USERPROFILE%\.duka_ftp.env`.
5. Typecheck: `flutter analyze` kabla ya kumalizia kazi kubwa.
6. Windows bash: `PYTHONIOENCODING=utf-8` kwa python scripts.
