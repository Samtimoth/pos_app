-- ═══════════════════════════════════════════════════════════════════════════
-- Hatua 5: Wasambazaji (suppliers) — msingi wa kwanza.
-- Additive only. Note: suppliers.php pia inatengeneza jedwali lenyewe
-- (suppliers_ensure_table()) — file hii ni documentation/reference tu.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS suppliers (
  supplier_id INT AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  name        VARCHAR(150) NOT NULL,
  phone       VARCHAR(30)  NOT NULL DEFAULT '',
  email       VARCHAR(120) NOT NULL DEFAULT '',
  address     VARCHAR(255) NOT NULL DEFAULT '',
  notes       VARCHAR(255) NOT NULL DEFAULT '',
  is_active   TINYINT(1) NOT NULL DEFAULT 1,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NULL,
  UNIQUE KEY uq_sup_biz_phone (business_id, phone),
  KEY idx_sup_biz_name (business_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Kiungo na batches: product_batches.supplier_id (nullable, self-added na
-- helpers/batches.php's product_batches_ensure_table()) — batches za zamani
-- (kabla ya feature hii) zina supplier_id = NULL, hazikuguswa.

-- Ruhusa: Manager na Stockist wana `suppliers.*`; Accountant ana `suppliers.view`
-- pekee (angalia helpers/bootstrap.php auth_permissions_for()).

-- Skopu ya toleo hili (kimakusudi HAIJAJUMUISHWA — mradi mkubwa zaidi kwa
-- baadaye): Purchase Orders (PO), GRN (Goods Received Note), invoice ya
-- msambazaji, malipo/deni kwa msambazaji (accounts payable), statement ya
-- msambazaji. Hii ni "wasambazaji" tu — anwani/mawasiliano + kuunganisha
-- batch za stock kwa msambazaji husika.

-- Reversal: DROP TABLE suppliers; ALTER TABLE product_batches DROP COLUMN supplier_id;
-- (haiathiri product_batches nyingine — safu zilizounganishwa na msambazaji
-- zitakuwa tu hazina uhusiano tena, stock/FIFO haziathiriki.)
