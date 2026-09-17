-- Expenses (matumizi) — one row per expense
CREATE TABLE IF NOT EXISTS tbl_expenses (
  expense_id    INT AUTO_INCREMENT PRIMARY KEY,
  business_id   INT NOT NULL,
  branch_id     INT NULL,
  category      VARCHAR(60)  NOT NULL DEFAULT 'Nyingine',
  description   VARCHAR(255) NOT NULL DEFAULT '',
  amount        DECIMAL(14,2) NOT NULL DEFAULT 0,
  expense_date  DATE NOT NULL,
  created_by    INT NULL,
  client_op_id  VARCHAR(64) NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NULL,
  is_deleted    TINYINT(1) NOT NULL DEFAULT 0,
  KEY idx_exp_biz_date (business_id, expense_date),
  UNIQUE KEY uq_exp_client_op (client_op_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cost at time of sale (for accurate COGS in P&L). Older rows fall back to
-- the product's current purchase_price.
ALTER TABLE tbl_sale_items ADD COLUMN cost_price DECIMAL(14,2) NULL AFTER unit_price;
