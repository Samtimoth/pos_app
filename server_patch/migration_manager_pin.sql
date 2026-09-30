-- ═══════════════════════════════════════════════════════════════════════════
-- Manager PIN — idhini ya meneja kwa marekebisho ya hasara ya stock.
-- Additive only. Note: helpers/manager_pin.php pia inaongeza column hii
-- lenyewe (manager_pin_ensure_column(), muundo uleule wa
-- returns_ensure_tables()/sale_payments_ensure_table()) — file hii ni
-- documentation/reference tu.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE tbl_user ADD COLUMN pin_hash VARCHAR(64) NULL;

-- Muundo (helpers/manager_pin.php):
--   PIN (tarakimu 4-6) inahifadhiwa kama SHA-256 hash (mtindo uleule wa
--   api_tokens — si password_hash, kwa sababu PIN si credential ya
--   kuingia, ni uthibitisho wa dakika moja mbele ya cashier).
--   manager_pin_set($pdo, $userId, $pin)  — meneja anaweka/kubadilisha PIN yake.
--   manager_pin_verify($pdo, $businessId, $pin) — inaangalia PIN dhidi ya
--     WATU WOTE wenye role Owner/Admin/Manager/SuperAdmin waliopo active
--     kwenye biashara hiyo (user_business) — meneja YEYOTE aliyepo anaweza
--     kuidhinisha, si mtu mmoja maalum.
--
-- Wapi inatumika: stock_movements.php action='adjust' — adjust_type
-- 'damaged'/'lost' (au 'correction' yenye direction='minus') zinahitaji
-- `manager_pin` sahihi kwenye request ISIPOKUWA mtumaji mwenyewe tayari ni
-- Owner/Admin/Manager/SuperAdmin (auth_context()['role_best']). Jina la
-- aliyeidhinisha linaongezwa kwenye `reason` ya stock_movements ledger row
-- moja kwa moja — hakuna column mpya ya "approved_by" iliyoongezwa.
--
-- Reversal: ALTER TABLE tbl_user DROP COLUMN pin_hash;
-- (haiathiri PINs zilizopo tayari kwenye matumizi — ni column ya hiari tu,
-- manager_pin_verify() inarudi null ikiwa haipo, sawa na table isiyokuwepo.)
