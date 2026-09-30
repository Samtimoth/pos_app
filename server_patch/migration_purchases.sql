-- ═══════════════════════════════════════════════════════════════════════════
-- Hatua 5: Manunuzi (purchases) — kurekodi ununuzi kutoka kwa msambazaji,
-- na deni rahisi kwa msambazaji (accounts payable ya msingi).
-- Additive only. Note: purchases.php pia inatengeneza majedwali yenyewe
-- (purchases_ensure_tables()) — file hii ni documentation/reference tu.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS purchases (
  purchase_id     INT AUTO_INCREMENT PRIMARY KEY,
  business_id     INT NOT NULL,
  supplier_id     INT NULL,
  purchase_no     VARCHAR(40) NOT NULL,
  subtotal_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  paid_amount     DECIMAL(14,2) NOT NULL DEFAULT 0,
  balance_amount  DECIMAL(14,2) NOT NULL DEFAULT 0,
  payment_status  VARCHAR(20) NOT NULL DEFAULT 'unpaid',  -- paid|partial|unpaid
  notes           VARCHAR(255) NOT NULL DEFAULT '',
  client_op_id    VARCHAR(64) NULL,
  created_by      INT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_pur_biz_date (business_id, created_at),
  KEY idx_pur_supplier (supplier_id),
  UNIQUE KEY uq_pur_client_op (client_op_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS purchase_items (
  purchase_item_id INT AUTO_INCREMENT PRIMARY KEY,
  purchase_id      INT NOT NULL,
  product_id       INT NOT NULL,
  product_name     VARCHAR(200) NOT NULL DEFAULT '',
  quantity         DECIMAL(14,3) NOT NULL,
  unit_cost        DECIMAL(14,2) NOT NULL,
  line_total       DECIMAL(14,2) NOT NULL,
  KEY idx_pi_purchase (purchase_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS purchase_payments (
  payment_id  INT AUTO_INCREMENT PRIMARY KEY,
  purchase_id INT NOT NULL,
  business_id INT NOT NULL,
  amount      DECIMAL(14,2) NOT NULL,
  method      VARCHAR(20) NOT NULL DEFAULT 'cash',
  note        VARCHAR(255) NOT NULL DEFAULT '',
  user_id     INT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_pp_purchase (purchase_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Muundo (purchases.php action='create'):
--   Kila item huongeza stock kupitia product_batch_add() ile ile ya
--   add_product_batch.php (FIFO-tracked, imeungwa na supplier_id) + UPDATE
--   tbl_product.stock moja kwa moja. Hivyo manunuzi na "add batch" ya
--   moja-kwa-moja zinatumia njia moja ya kuongeza stock, hakuna mgongano.
--   paid_amount < subtotal_amount → balance inabaki kama deni (payment_status
--   'partial'/'unpaid'); purchases.php action='record_payment' inapunguza
--   deni hilo taratibu, kila malipo yanaandikwa kwenye purchase_payments.
--
-- suppliers.php's 'list'/'get' zinajumuisha `total_owed` (SUM ya
-- purchases.balance_amount) sasa — self-healing kama jedwali la purchases
-- halijaundwa bado (linarudi 0 badala ya kushindwa).
--
-- Kimakusudi HAIJAJUMUISHWA: Purchase Orders (kuagiza kabla ya kupokea),
-- GRN rasmi tofauti na "purchase" (hapa create=kupokea+kuandikisha kwa
-- pamoja, kama sales duka nyingi ndogo zinavyofanya kazi), invoice ya
-- msambazaji kama hati tofauti, supplier statement (angalia purchases kwa
-- supplier_id badala yake kwa sasa).
--
-- Reversal: DROP TABLE purchase_payments; DROP TABLE purchase_items;
-- DROP TABLE purchases; (haiathiri product_batches/tbl_product — stock
-- iliyoongezwa na manunuzi yaliyopo tayari inabaki, hii inaondoa tu rekodi
-- ya deni/malipo.)
