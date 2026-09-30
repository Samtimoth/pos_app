-- ═══════════════════════════════════════════════════════════════════════════
-- Split payment (Cash + M-Pesa + Bank) katika mauzo moja, + chenji.
-- Additive only. Note: create_sale.php pia inatengeneza jedwali hili lenyewe
-- (sale_payments_ensure_table(), muundo uleule wa returns_ensure_tables() /
-- dk_ensure_tables()) — file hii ni documentation/reference tu; kuiendesha
-- kwa mkono si lazima.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS sale_payments (
  sale_payment_id INT AUTO_INCREMENT PRIMARY KEY,
  sale_id      INT NOT NULL,
  business_id  INT NOT NULL,
  method       VARCHAR(20) NOT NULL,          -- cash | mpesa | bank | card | other
  amount       DECIMAL(14,2) NOT NULL,        -- kiasi kilichotumika kwenye mauzo
  tendered     DECIMAL(14,2) NULL,            -- cash tu: kiasi halisi alichotoa mteja
  reference    VARCHAR(120) NOT NULL DEFAULT '', -- namba ya muamala (mpesa/bank)
  user_id      INT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_sp_sale (sale_id),
  KEY idx_sp_biz_date (business_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Muundo wa fedha (create_sale.php):
--   kwa transaction_type='cash'  : jumla ya payments[].amount LAZIMA iendane
--                                  na jumla ya mauzo (tolerance TZS 1) —
--                                  mauzo ya cash daima yamelipwa kikamilifu.
--   kwa transaction_type='slow_payment': paid_amount = min(jumla ya payments, jumla ya mauzo)
--   change_amount = jumla ya (tendered - amount) kwa lines za 'cash' pekee
--   tbl_sales.payment_method = njia pekee ikiwa moja, au 'mixed' ikiwa zaidi ya moja
--
-- HAIBADILISHI trg_sales_ai/trg_sales_au zilizopo (bado zinaandika rekodi
-- MOJA kwenye tbl_loan_payments kutoka payment_method/paid_amount ya
-- muhtasari) — jedwali hili ni ONGEZO la maelezo zaidi (breakdown per
-- method), si mbadala. get_sale_payments.php inarudisha zote mbili:
-- `payments` (historia iliyopo, tbl_loan_payments) na `breakdown` (jedwali
-- hili jipya, sale_payments).
--
-- Reversal: DROP TABLE sale_payments; (haiathiri tbl_sales/tbl_loan_payments)
