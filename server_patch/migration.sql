-- Idempotency store for offline sync (one row per client operation).
CREATE TABLE IF NOT EXISTS sync_ops (
  client_op_id  VARCHAR(64)  NOT NULL PRIMARY KEY,
  endpoint      VARCHAR(64)  NOT NULL,
  response_json MEDIUMTEXT   NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

