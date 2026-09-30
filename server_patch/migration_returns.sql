-- ═══════════════════════════════════════════════════════════════════════════
-- Sales returns / refunds (marejesho ya bidhaa)
-- Additive only. Note: sale_returns.php also creates these tables itself on
-- first use (returns_ensure_tables(), same self-healing pattern bootstrap.php
-- uses for api_tokens/audit_log) — this file exists purely as documentation
-- of the schema; running it by hand is optional.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS sale_returns (
  return_id    INT AUTO_INCREMENT PRIMARY KEY,
  sale_id      INT NOT NULL,
  business_id  INT NOT NULL,
  user_id      INT NULL,
  reason       VARCHAR(255) NOT NULL DEFAULT '',
  total_amount DECIMAL(14,2) NOT NULL DEFAULT 0,   -- value of the returned items
  cash_refund  DECIMAL(14,2) NOT NULL DEFAULT 0,   -- portion that must be handed back in cash
  client_op_id VARCHAR(64) NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ret_sale (sale_id),
  KEY idx_ret_biz_date (business_id, created_at),
  UNIQUE KEY uq_ret_client_op (client_op_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sale_return_items (
  return_item_id INT AUTO_INCREMENT PRIMARY KEY,
  return_id      INT NOT NULL,
  product_id     INT NOT NULL,
  product_name   VARCHAR(255) NOT NULL DEFAULT '',
  quantity       DECIMAL(14,3) NOT NULL,
  unit_price     DECIMAL(14,2) NOT NULL,
  line_total     DECIMAL(14,2) NOT NULL,
  KEY idx_reti_return (return_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Money model (sale_returns.php):
--   refund_amount     = sum(returned line totals)
--   balance_reduction = min(sale.balance_amount, refund_amount)
--   new_balance       = sale.balance_amount - balance_reduction
--   cash_refund       = refund_amount - balance_reduction   (owed back in cash if > 0)
--   new_paid          = sale.paid_amount - cash_refund
--   new_total         = sale.total_amount - refund_amount
-- i.e. a return first cancels out any unpaid balance; only the part that was
-- genuinely already paid for becomes cash the cashier hands back.
--
-- Stock: restocked via UPDATE tbl_product SET stock = stock + qty, tagged
-- movement_type='return', ref_type='return', ref_id=<return_id> through the
-- same @stock_move_type/@stock_ref_type/@stock_ref_id session-variable
-- mechanism the stock_movements 'adjust' action and the void_sale/trg_sales_au
-- trigger already use — no new trigger needed, trg_product_au picks it up.
--
-- Reversal: DROP TABLE sale_return_items; DROP TABLE sale_returns;
-- (does not touch tbl_sales/tbl_product — those were already mutated by any
-- returns already processed; this only removes the return audit trail.)
