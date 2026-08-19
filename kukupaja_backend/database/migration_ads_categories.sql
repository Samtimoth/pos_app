-- (KukuPaja) tables live in the connected database; USE removed.

ALTER TABLE kukupaja_products
  ADD COLUMN IF NOT EXISTS category ENUM(
    'kienyeji','broiler','mayai','vifaranga','kuku_wakisasa','vingine'
  ) NOT NULL DEFAULT 'vingine' AFTER broker_id;

UPDATE kukupaja_products SET category='kienyeji' WHERE LOWER(name) LIKE '%kienyeji%';
UPDATE kukupaja_products SET category='broiler' WHERE LOWER(name) LIKE '%broiler%';
UPDATE kukupaja_products SET category='mayai' WHERE LOWER(name) LIKE '%mayai%';
UPDATE kukupaja_products SET category='vifaranga' WHERE LOWER(name) LIKE '%vifaranga%';

CREATE TABLE IF NOT EXISTS kukupaja_advertisements (
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
  FOREIGN KEY (created_by) REFERENCES kukupaja_users(id)
) ENGINE=InnoDB;

INSERT INTO kukupaja_advertisements(
  advertiser_name,title,subtitle,image_url,button_text,target_category,
  amount_paid,starts_at,ends_at,is_active,created_by
)
SELECT
  'KukuPaja Poultry','Kuku wa Kienyeji Wamefika!',
  'Nunua kuku wenye afya kwa bei maalum wiki hii.',
  'https://images.unsplash.com/photo-1548550023-2bdb3c5beed7',
  'Angalia Sasa','kienyeji',25000,NOW(),DATE_ADD(NOW(),INTERVAL 30 DAY),1,1
WHERE NOT EXISTS (SELECT 1 FROM kukupaja_advertisements);

UPDATE kukupaja_advertisements
SET image_url='https://images.unsplash.com/photo-1548550023-2bdb3c5beed7'
WHERE image_url IS NULL OR image_url='';

INSERT INTO kukupaja_advertisements(
  advertiser_name,title,subtitle,image_url,button_text,target_category,
  amount_paid,starts_at,ends_at,is_active,created_by
)
SELECT
  'KukuPaja Broiler Farm','Broiler Tayari kwa Oda',
  'Stock mpya kwa migahawa, familia na wauzaji.',
  'https://images.unsplash.com/photo-1569396116180-210c182bedb8',
  'Nunua Sasa','broiler',30000,NOW(),DATE_ADD(NOW(),INTERVAL 21 DAY),1,1
WHERE NOT EXISTS (
  SELECT 1 FROM kukupaja_advertisements WHERE title='Broiler Tayari kwa Oda'
);
