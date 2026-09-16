-- ═══════════════════════════════════════════════════════════════════════════
-- Hatua 2 + 3: customers · payment history · stock ledger
-- Additive only. Reversal notes at the bottom.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Customers ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  customer_id   INT AUTO_INCREMENT PRIMARY KEY,
  business_id   INT NOT NULL,
  name          VARCHAR(120) NOT NULL,
  phone         VARCHAR(30)  NOT NULL DEFAULT '',
  email         VARCHAR(120) NOT NULL DEFAULT '',
  address       VARCHAR(255) NOT NULL DEFAULT '',
  customer_type VARCHAR(20)  NOT NULL DEFAULT 'retail',   -- retail | wholesale | vip
  credit_limit  DECIMAL(14,2) NOT NULL DEFAULT 0,
  notes         VARCHAR(255) NOT NULL DEFAULT '',
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NULL,
  UNIQUE KEY uq_cust_biz_phone (business_id, phone),
  KEY idx_cust_biz_name (business_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE tbl_sales ADD COLUMN customer_id INT NULL AFTER customer_phone;
ALTER TABLE tbl_sales ADD KEY idx_sales_customer (customer_id);
ALTER TABLE tbl_sales ADD KEY idx_sales_biz_created (business_id, created_at);

-- backfill: one customer per (business, phone) from past sales
INSERT INTO customers (business_id, name, phone, created_at)
SELECT s.business_id,
       SUBSTRING_INDEX(MAX(s.customer_name), ' | ', 1),
       s.customer_phone,
       MIN(s.created_at)
FROM tbl_sales s
WHERE s.customer_phone <> ''
GROUP BY s.business_id, s.customer_phone
ON DUPLICATE KEY UPDATE name = name;

UPDATE tbl_sales s
JOIN customers c ON c.business_id = s.business_id AND c.phone = s.customer_phone AND s.customer_phone <> ''
SET s.customer_id = c.customer_id
WHERE s.customer_id IS NULL;

-- ── Payment history (reuse existing tbl_loan_payments) ──────────────────────
ALTER TABLE tbl_loan_payments ADD COLUMN received_by INT NULL;
ALTER TABLE tbl_loan_payments ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'app';
ALTER TABLE tbl_loan_payments ADD KEY idx_lp_sale (sale_id);

-- opening rows: sales already paid (fully/partly) before this migration
INSERT INTO tbl_loan_payments (sale_id, business_id, amount, payment_method, notes, created_at, source)
SELECT s.sale_id, s.business_id, s.paid_amount, COALESCE(s.payment_method,'cash'), 'opening (kabla ya historia)', s.created_at, 'backfill'
FROM tbl_sales s
WHERE s.paid_amount > 0 AND s.payment_status <> 'voided'
  AND NOT EXISTS (SELECT 1 FROM tbl_loan_payments lp WHERE lp.sale_id = s.sale_id);

-- ── Stock ledger ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stock_movements (
  movement_id   INT AUTO_INCREMENT PRIMARY KEY,
  business_id   INT NOT NULL,
  branch_id     INT NULL,
  product_id    INT NOT NULL,
  movement_type VARCHAR(20) NOT NULL,   -- opening|sale|void|batch|adjustment|return|transfer_in|transfer_out|edit
  qty_delta     DECIMAL(14,3) NOT NULL,
  stock_after   DECIMAL(14,3) NOT NULL,
  cost_price    DECIMAL(14,2) NULL,
  ref_type      VARCHAR(20) NULL,
  ref_id        INT NULL,
  reason        VARCHAR(255) NOT NULL DEFAULT '',
  user_id       INT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_sm_prod (business_id, product_id, created_at),
  KEY idx_sm_ref (ref_type, ref_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- opening balance = stock ya sasa
INSERT INTO stock_movements (business_id, branch_id, product_id, movement_type, qty_delta, stock_after, cost_price, reason)
SELECT business_id, branch_id, product_id, 'opening', stock, stock, purchase_price, 'Opening balance (ledger ilianza)'
FROM tbl_product p
WHERE NOT EXISTS (SELECT 1 FROM stock_movements m WHERE m.product_id = p.product_id);

-- ── Triggers ────────────────────────────────────────────────────────────────
-- Session variables carry context between the row that "causes" a movement
-- (sale item, void, batch) and the tbl_product update that follows it, all in
-- the same request/connection. Endpoints need no changes.

DROP TRIGGER IF EXISTS trg_sale_items_ai;
CREATE TRIGGER trg_sale_items_ai AFTER INSERT ON tbl_sale_items FOR EACH ROW
  SET @stock_move_type = 'sale', @stock_ref_type = 'sale', @stock_ref_id = NEW.sale_id;

DROP TRIGGER IF EXISTS trg_batches_ai;
CREATE TRIGGER trg_batches_ai AFTER INSERT ON product_batches FOR EACH ROW
  SET @stock_move_type = 'batch', @stock_ref_type = 'batch', @stock_ref_id = NEW.batch_id;

DROP TRIGGER IF EXISTS trg_sales_bi;
CREATE TRIGGER trg_sales_bi BEFORE INSERT ON tbl_sales FOR EACH ROW
BEGIN
  -- link / create customer by phone
  IF NEW.customer_phone <> '' AND NEW.customer_id IS NULL THEN
    INSERT INTO customers (business_id, name, phone)
      VALUES (NEW.business_id, SUBSTRING_INDEX(NEW.customer_name, ' | ', 1), NEW.customer_phone)
      ON DUPLICATE KEY UPDATE customer_id = LAST_INSERT_ID(customer_id);
    SET NEW.customer_id = LAST_INSERT_ID();
  END IF;
END;

DROP TRIGGER IF EXISTS trg_sales_ai;
CREATE TRIGGER trg_sales_ai AFTER INSERT ON tbl_sales FOR EACH ROW
BEGIN
  IF NEW.paid_amount > 0 THEN
    INSERT INTO tbl_loan_payments (sale_id, business_id, amount, payment_method, notes, created_at, source)
      VALUES (NEW.sale_id, NEW.business_id, NEW.paid_amount, COALESCE(NEW.payment_method,'cash'), 'Malipo wakati wa mauzo', NEW.created_at, 'sale');
  END IF;
END;

DROP TRIGGER IF EXISTS trg_sales_au;
CREATE TRIGGER trg_sales_au AFTER UPDATE ON tbl_sales FOR EACH ROW
BEGIN
  -- payment history: every increase of paid_amount
  IF NEW.paid_amount > OLD.paid_amount THEN
    IF NOT EXISTS (SELECT 1 FROM tbl_loan_payments lp
                   WHERE lp.sale_id = NEW.sale_id AND lp.amount = NEW.paid_amount - OLD.paid_amount
                     AND lp.created_at >= NOW() - INTERVAL 5 SECOND) THEN
      INSERT INTO tbl_loan_payments (sale_id, business_id, amount, payment_method, notes, created_at, source)
        VALUES (NEW.sale_id, NEW.business_id, NEW.paid_amount - OLD.paid_amount,
                COALESCE(NEW.payment_method,'cash'), '', NOW(), 'update');
    END IF;
  END IF;
  -- void → stock coming back is labelled
  IF NEW.payment_status = 'voided' AND OLD.payment_status <> 'voided' THEN
    SET @stock_move_type = 'void', @stock_ref_type = 'sale', @stock_ref_id = NEW.sale_id;
  END IF;
END;

DROP TRIGGER IF EXISTS trg_product_au;
CREATE TRIGGER trg_product_au AFTER UPDATE ON tbl_product FOR EACH ROW
BEGIN
  IF NEW.stock <> OLD.stock THEN
    INSERT INTO stock_movements
      (business_id, branch_id, product_id, movement_type, qty_delta, stock_after, cost_price,
       ref_type, ref_id, reason, user_id)
    VALUES
      (NEW.business_id, NEW.branch_id, NEW.product_id,
       COALESCE(@stock_move_type, 'edit'), NEW.stock - OLD.stock, NEW.stock, NEW.purchase_price,
       @stock_ref_type, @stock_ref_id, COALESCE(@stock_reason, ''), @stock_user_id);
  END IF;
END;

DROP TRIGGER IF EXISTS trg_product_ai;
CREATE TRIGGER trg_product_ai AFTER INSERT ON tbl_product FOR EACH ROW
BEGIN
  IF NEW.stock <> 0 THEN
    INSERT INTO stock_movements
      (business_id, branch_id, product_id, movement_type, qty_delta, stock_after, cost_price, reason, user_id)
    VALUES (NEW.business_id, NEW.branch_id, NEW.product_id, 'opening', NEW.stock, NEW.stock, NEW.purchase_price,
            'Stock ya kwanza (bidhaa mpya)', @stock_user_id);
  END IF;
END;

-- ── Reversal (if ever needed) ──────────────────────────────────────────────
-- DROP TRIGGER trg_sale_items_ai; DROP TRIGGER trg_batches_ai; DROP TRIGGER trg_sales_bi;
-- DROP TRIGGER trg_sales_ai; DROP TRIGGER trg_sales_au; DROP TRIGGER trg_product_au; DROP TRIGGER trg_product_ai;
-- DROP TABLE stock_movements;  -- customers/tbl_sales.customer_id/tbl_loan_payments rows can stay (harmless)
