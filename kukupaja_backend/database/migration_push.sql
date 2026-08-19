-- Push notifications: stores each user's FCM device token(s).
CREATE TABLE IF NOT EXISTS kukupaja_device_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token VARCHAR(512) NOT NULL,
  platform VARCHAR(20) NOT NULL DEFAULT 'android',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_token (token),
  KEY idx_user (user_id),
  CONSTRAINT fk_devtok_user FOREIGN KEY (user_id) REFERENCES kukupaja_users(id) ON DELETE CASCADE
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;
