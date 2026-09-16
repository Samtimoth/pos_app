# Server patch — offline sync (Duka Kiganjani)

Files hapa zinaenda kwenye folder ya API (`/pos/api/`) kwenye focustec.co.tz.

## 1. Database
Endesha `migration.sql` kwenye phpMyAdmin (database ya POS).
Inaunda table `sync_ops` na kuongeza column `client_op_id` kwenye `sales`.
*(Kama `sales` tayari ina column hiyo, ruka mistari ya ALTER.)*

## 2. Upload files
- `ping.php`         → `/pos/api/ping.php`  (app inaitumia kujua kama server inapatikana)
- `sync_helper.php`  → `/pos/api/sync_helper.php`

## 3. Weka `sync_begin()` kwenye endpoints hizi
Ongeza mistari miwili **mara tu baada ya DB connection kuundwa** (kabla ya logic yoyote):

```php
require_once __DIR__ . '/sync_helper.php';
sync_begin($conn);   // au $pdo / $db — chochote kinachoshikilia mysqli/PDO
```

Endpoints:

| File                        | Kwa nini                          |
|-----------------------------|-----------------------------------|
| `create_sale.php`           | mauzo ya offline (MUHIMU ZAIDI)   |
| `sale_action.php`           | malipo ya deni / void / collect   |
| `add_product.php`           | bidhaa mpya offline               |
| `update_product.php`        | edit offline                      |
| `delete_product.php`        |                                   |
| `add_product_batch.php`     | stock in offline                  |
| `manage_product_units.php`  |                                   |
| `manage_categories.php`     |                                   |
| `manage_units.php`          |                                   |
| `import_products.php`       |                                   |

Hakuna kitu kingine kinachobadilika kwenye files hizo — zinaendelea ku-`echo json_encode(...)` kama kawaida.
Request za kawaida (bila `client_op_id`) hazigusiwi kabisa.

## 4. `create_sale.php` — muda halisi wa mauzo (inapendekezwa sana)
Mauzo ya offline yanatumwa baadaye; app inatuma `created_at` (muda ambao mauzo
yalifanyika kweli, format `YYYY-MM-DD HH:MM:SS`). Kwenye INSERT ya `sales` tumia:

```php
$createdAt = (!empty($input['created_at']) && strtotime($input['created_at']) !== false)
    ? date('Y-m-d H:i:s', strtotime($input['created_at']))
    : date('Y-m-d H:i:s');
$clientOpId = $input['client_op_id'] ?? null;
// ... INSERT INTO sales (..., created_at, client_op_id) VALUES (..., ?, ?)
```

Bila hii, mauzo ya offline yataonekana yamefanyika saa yaliyo-sync, si saa yaliyouzwa —
ripoti za "leo" zitakuwa na makosa.

## 5. `sale_action.php` — note ya malipo (bug fix)
App sasa inatuma `note` pamoja na `record_payment`. Kama table ya payments ina
column ya note/notes, ihifadhi: `$input['note'] ?? ''`.

## Jinsi ya kujaribu
1. Zima data/WiFi kwenye simu → uza bidhaa → risiti inatoka na namba `OFF-...`
2. Washa data → banner "Inatuma data…" → sale inapata `sale_no` halisi
3. Rudia hatua 1, lakini kata mtandao katikati ya sync — sale haitarudiwa
   mara mbili (angalia `sync_ops` table: row moja kwa kila `client_op_id`).
