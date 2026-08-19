USE kukusoko;

-- Kila broker anapata payout moja tu kwa oda moja.
ALTER TABLE payouts
  ADD UNIQUE KEY unique_order_broker (order_id, broker_id);
