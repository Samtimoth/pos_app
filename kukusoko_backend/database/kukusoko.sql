CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role ENUM('customer','broker','admin') NOT NULL,
  name VARCHAR(120) NOT NULL,
  phone VARCHAR(20) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  location VARCHAR(160),
  is_verified TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE auth_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  broker_id BIGINT UNSIGNED NOT NULL,
  category ENUM('kienyeji','broiler','mayai','vifaranga','kuku_wakisasa','vingine') NOT NULL DEFAULT 'vingine',
  name VARCHAR(160) NOT NULL,
  description TEXT,
  supplier_price DECIMAL(12,2) NOT NULL,
  customer_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_stock INT UNSIGNED NOT NULL,
  available_stock INT UNSIGNED NOT NULL,
  reserved_stock INT UNSIGNED NOT NULL DEFAULT 0,
  sold_stock INT UNSIGNED NOT NULL DEFAULT 0,
  location VARCHAR(160) NOT NULL,
  weight VARCHAR(60),
  age VARCHAR(60),
  vaccination VARCHAR(255),
  image_url VARCHAR(500),
  status ENUM('pending','approved','rejected','expired') DEFAULT 'pending',
  rejection_reason VARCHAR(255),
  approved_by BIGINT UNSIGNED,
  approved_at DATETIME,
  expires_at DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (broker_id) REFERENCES users(id),
  FOREIGN KEY (approved_by) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_number VARCHAR(40) NOT NULL UNIQUE,
  customer_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending','confirmed','assigned','accepted','preparing','in_transit','delivered','completed','cancelled','refunded') DEFAULT 'pending',
  total_amount DECIMAL(12,2) NOT NULL,
  delivery_fee DECIMAL(12,2) NOT NULL DEFAULT 0,
  delivery_address TEXT NOT NULL,
  payment_method VARCHAR(50) NOT NULL,
  payment_status ENUM('pending','paid','refunded') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE order_items (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB;

CREATE TABLE order_assignments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  broker_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  status ENUM('pending','accepted','rejected','fulfilled','cancelled') DEFAULT 'pending',
  deadline DATETIME,
  responded_at DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (broker_id) REFERENCES users(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB;

CREATE TABLE messages (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sender_id BIGINT UNSIGNED NOT NULL,
  receiver_id BIGINT UNSIGNED NOT NULL,
  order_id BIGINT UNSIGNED,
  message TEXT NOT NULL,
  read_at DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sender_id) REFERENCES users(id),
  FOREIGN KEY (receiver_id) REFERENCES users(id),
  FOREIGN KEY (order_id) REFERENCES orders(id)
) ENGINE=InnoDB;

CREATE TABLE payouts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  broker_id BIGINT UNSIGNED NOT NULL,
  order_id BIGINT UNSIGNED NOT NULL,
  supplier_amount DECIMAL(12,2) NOT NULL,
  status ENUM('pending','paid','failed') DEFAULT 'pending',
  reference VARCHAR(120),
  paid_at DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_order_broker (order_id, broker_id),
  FOREIGN KEY (broker_id) REFERENCES users(id),
  FOREIGN KEY (order_id) REFERENCES orders(id)
) ENGINE=InnoDB;

CREATE TABLE advertisements (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  advertiser_name VARCHAR(160) NOT NULL,
  title VARCHAR(160) NOT NULL,
  subtitle VARCHAR(255),
  image_url VARCHAR(500),
  button_text VARCHAR(60) DEFAULT 'Angalia Sasa',
  target_category VARCHAR(60),
  amount_paid DECIMAL(12,2) NOT NULL DEFAULT 0,
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB;

-- Password ya demo zote ni: password
INSERT INTO users(role,name,phone,password_hash,location,is_verified) VALUES
('admin','Mtwesa Admin','255700000001','$2y$10$HpPU0MKcDXKjsnwKgvfQr.UgaLmGPhi2mWci3tLF3lHiBm7rUASsC','Dar es Salaam',1),
('broker','Ally Mfugaji','255700000002','$2y$10$HpPU0MKcDXKjsnwKgvfQr.UgaLmGPhi2mWci3tLF3lHiBm7rUASsC','Morogoro',1),
('customer','Asha Mteja','255700000003','$2y$10$HpPU0MKcDXKjsnwKgvfQr.UgaLmGPhi2mWci3tLF3lHiBm7rUASsC','Dar es Salaam',1);

INSERT INTO products(broker_id,category,name,description,supplier_price,customer_price,total_stock,available_stock,location,weight,age,vaccination,image_url,status,approved_by,approved_at) VALUES
(2,'kienyeji','Kuku wa Kienyeji','Kuku mzima mwenye afya',12000,15000,28,28,'Morogoro','1.5 - 2.0 kg','Miezi 6+','Newcastle, Gumboro',NULL,'approved',1,NOW()),
(2,'broiler','Kuku wa Broiler','Broiler aliyekomaa',9000,12000,50,50,'Dar es Salaam','2.0 - 2.5 kg','Wiki 6','Newcastle, Gumboro',NULL,'approved',1,NOW());

INSERT INTO advertisements(advertiser_name,title,subtitle,image_url,button_text,target_category,amount_paid,starts_at,ends_at,is_active,created_by) VALUES
('Mtwesa Poultry','Kuku wa Kienyeji Wamefika!','Nunua kuku wenye afya kwa bei maalum wiki hii.','https://images.unsplash.com/photo-1548550023-2bdb3c5beed7','Angalia Sasa','kienyeji',25000,NOW(),DATE_ADD(NOW(),INTERVAL 30 DAY),1,1);
