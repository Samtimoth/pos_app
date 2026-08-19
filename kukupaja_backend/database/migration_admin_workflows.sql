-- (KukuPaja) tables live in the connected database; USE removed.

-- Kila broker anapata payout moja tu kwa oda moja.
ALTER TABLE kukupaja_payouts
  ADD UNIQUE KEY unique_order_broker (order_id, broker_id);
