// Simple bilingual translation system — Swahili ↔ English
// Usage: L.of(context).dashboard  OR  L.t('Dashibodi','Dashboard')
import 'package:flutter/widgets.dart';

enum AppLang { sw, en }

class L {
  final AppLang lang;
  const L(this.lang);

  bool get isSw => lang == AppLang.sw;
  String t(String sw, String en) => isSw ? sw : en;

  static L of(BuildContext context) => _current;
  static L _current = const L(AppLang.sw);
  static void setLang(AppLang l) => _current = L(l);

  // ── Navigation ──────────────────────────────────────────
  String get dashboard   => t('Dashibodi',    'Dashboard');
  String get pos         => t('POS — Uza',    'POS — Sell');
  String get sales       => t('Mauzo',        'Sales');
  String get products    => t('Bidhaa',       'Products');

  // ── Dashboard ────────────────────────────────────────────
  String get hello          => t('Habari',          'Hello');
  String get todayRevenue   => t('Mapato Leo',       'Today\'s Revenue');
  String get totalRevenue   => t('Mapato Jumla',     'Total Revenue');
  String get sellNow        => t('Uza Sasa',         'Sell Now');
  String get viewSales      => t('Tazama Mauzo',     'View Sales');
  String get weeklyChart    => t('Mauzo — Wiki Hii', 'This Week\'s Sales');
  String get summary        => t('Muhtasari',        'Summary');
  String get quickActions   => t('Vitendo vya Haraka','Quick Actions');
  String get recentSales    => t('Mauzo ya Hivi Karibuni','Recent Sales');
  String get seeAll         => t('Angalia Zote',     'See All');
  String get switchBiz      => t('Badilisha Biashara','Switch Business');
  String get logout         => t('Toka',             'Logout');
  String get refresh        => t('Onyesha Upya',     'Refresh');
  String get live           => t('MOJA KWA MOJA',    'LIVE');
  String get noSales        => t('Hakuna mauzo',     'No sales yet');
  String get loading        => t('Inapakia...',      'Loading...');
  String get tryAgain       => t('Jaribu Tena',      'Try Again');

  // ── KPI labels ───────────────────────────────────────────
  String get kpiProducts    => t('Bidhaa',           'Products');
  String get kpiLowStock    => t('Stock Chini',      'Low Stock');
  String get kpiDebts       => t('Madeni',           'Debts');
  String get kpiStaff       => t('Wafanyikazi',      'Staff');
  String get kpiDevices     => t('Vifaa',            'Devices');
  String get kpiOutStock    => t('Imeisha',          'Out of Stock');
  String get kpiTodayCount  => t('Mauzo Leo',        'Today\'s Sales');

  // ── POS ──────────────────────────────────────────────────
  String get searchProduct  => t('Tafuta bidhaa au barcode...','Search product or barcode...');
  String get allCategories  => t('Zote',             'All');
  String get cart           => t('Mkoba wa Ununuzi', 'Shopping Cart');
  String get cartEmpty      => t('Mkoba uko wazi',   'Cart is empty');
  String get cartEmptySub   => t('Bonyeza bidhaa kuongeza','Tap a product to add');
  String get clearCart      => t('Futa mkoba?',      'Clear cart?');
  String get clearCartSub   => t('Bidhaa zote zitafutwa.','All items will be removed.');
  String get customer       => t('Jina la mteja (lazima)', 'Customer name (required)');
  String get payType        => t('Aina ya Malipo',   'Payment Type');
  String get saveSale       => t('HIFADHI MAUZO',    'SAVE SALE');
  String get saving         => t('Inahifadhi...',    'Saving...');
  String get cash           => t('💵 Taslimu',       '💵 Cash');
  String get loan           => t('📋 Mkopo',         '📋 Credit');
  String get slowPay        => t('⏳ Malipo Polepole','⏳ Installment');
  String get noProducts     => t('Hakuna bidhaa',    'No products');
  String get total          => t('JUMLA',            'TOTAL');
  String get outOfStock     => t('Imeisha',          'Out of Stock');
  String get inCart         => t('kwenye mkoba',     'in cart');
  String get stockLabel     => t('Stock',            'Stock');
  String get saleSuccess    => t('✅ Mauzo yamehifadhiwa!','✅ Sale saved!');
  String get enterCustomer  => t('Ingiza jina la mteja','Enter customer name');
  String get clearYes       => t('Futa',             'Clear');
  String get no             => t('Hapana',           'No');
  String get yes            => t('Ndio',             'Yes');
  String get items          => t('bidhaa',           'items');

  // ── Sales ─────────────────────────────────────────────────
  String get salesHistory   => t('Historia ya Mauzo','Sales History');
  String get search         => t('Tafuta mteja, no. ya muamala...','Search customer, receipt no...');
  String get filterAll      => t('Zote',             'All');
  String get filterCash     => t('Taslimu',          'Cash');
  String get filterLoan     => t('Mkopo',            'Credit');
  String get filterPartial  => t('Sehemu',           'Partial');
  String get salePaid       => t('Imekamilika',      'Completed');
  String get saleUnpaid     => t('Mkopo',            'On Credit');
  String get salePartial    => t('Sehemu',           'Partial');
  String get totalLabel     => t('Jumla',            'Total');
  String get debt           => t('Deni',             'Balance Due');
  String get allSales       => t('Jumla',            'Total');
  String get income         => t('Mapato',           'Revenue');
  String get debts          => t('Madeni',           'Debts');

  // ── Products ──────────────────────────────────────────────
  String get productList    => t('Orodha ya Bidhaa', 'Product List');
  String get searchProd     => t('Tafuta bidhaa, kategoria, barcode...','Search product, category, barcode...');
  String get filterInStock  => t('Zina Stock',       'In Stock');
  String get filterLow      => t('Stock Chini',      'Low Stock');
  String get filterOut      => t('Imeisha',          'Out of Stock');
  String get buyPrice       => t('Ununuzi',          'Buy Price');
  String get sellPrice      => t('Uuzaji',           'Sell Price');
  String get profit         => t('Faida',            'Profit');
  String get category       => t('Kategoria',        'Category');
  String get unit           => t('Kitengo',          'Unit');
  String get stock          => t('Stock',            'Stock');
  String get noCategory     => t('Hakuna kategoria', 'No category');

  // ── Add / Import Products ─────────────────────────────────
  String get addProductTitle   => t('Ongeza Bidhaa',         'Add Product');
  String get productName       => t('Jina la Bidhaa',        'Product Name');
  String get minStock          => t('Stock ya Chini',        'Min Stock');
  String get barcode_          => t('Barcode / Kod',         'Barcode / Code');
  String get description_      => t('Maelezo (hiari)',       'Description (optional)');
  String get wholesalePrice    => t('Bei ya Jumla (hiari)',  'Wholesale Price (optional)');
  String get productCode       => t('Kodi ya Bidhaa (hiari)','Product Code (optional)');
  String get expiryDate        => t('Tarehe ya Mwisho',      'Expiry Date');
  String get typeOrSelect      => t('Chagua au andika...',   'Select or type...');
  String get addingProduct     => t('Inaongeza...',          'Adding...');
  String get productAdded      => t('✅ Bidhaa imeongezwa!', '✅ Product added!');
  String get productExists     => t('Bidhaa ipo tayari.',    'Product already exists.');
  String get requiredField     => t('(lazima)',              '(required)');
  // ── Excel Import ──────────────────────────────────────────
  String get importExcel       => t('Ingiza Excel',          'Import Excel');
  String get pickFile          => t('Chagua Faili',          'Pick File (.xlsx / .csv)');
  String get importNow         => t('Ingiza Bidhaa',         'Import Products');
  String get importing         => t('Inaingizia...',         'Importing...');
  String get importSuccess     => t('Bidhaa zimeingiziwa!',  'Products imported!');
  String get selectAll         => t('Chagua Zote',           'Select All');
  String get deselectAll       => t('Acha Zote',             'Deselect All');
  String get preview           => t('Angalia',               'Preview');
  String get validRows         => t('safu sawa',             'valid rows');
  String get invalidRows       => t('safu zenye hitilafu',   'rows with errors');
  String get formatGuide       => t('Muundo wa Faili',       'File Format');
  String get changeFile        => t('Badilisha Faili',       'Change File');
  String get noFileSelected    => t('Hakuna faili',          'No file selected');
  String get parseError        => t('Imeshindwa kusoma faili','Could not read file');
  String get importSummary     => t('Matokeo ya Uingizaji',  'Import Summary');
  String get rowsFound         => t('safu zimepatikana',     'rows found');
  String get colHint           => t('Safu za lazima: jina la bidhaa, kategoria, kitengo, bei ya uuzaji',
                                     'Required columns: product_name, category, unit, sell_price');

  // ── New Sale ──────────────────────────────────────────────
  String get newSale        => t('Mauzo Mapya',      'New Sale');
  String get addProduct     => t('Ongeza Bidhaa',    'Add Product');
  String get searchProducts => t('Tafuta bidhaa...', 'Search products...');
  String get amountPaid     => t('Kiasi Kilicholipwa','Amount Paid');
  String get cartItems      => t('Bidhaa kwenye mauzo','Items in sale');
  String get noItemsAdded   => t('Bonyeza bidhaa kuongeza kwenye mauzo',
                                  'Tap a product to add to this sale');
  String get qty            => t('Idadi',            'Qty');
  String get remove         => t('Ondoa',            'Remove');
  String get selectProducts => t('Chagua Bidhaa',   'Select Products');
  String get checkout       => t('Malipo',           'Checkout');
  String get cartNotEmpty   => t('Ongeza bidhaa kwanza','Add products first');
  String get partialPay     => t('Malipo ya Sehemu', 'Partial Payment');

  // ── New Transaction Types ─────────────────────────────────────────────────────
  String get cashNotCollected  => t('Pesa Hazijakusanywa',  'Cash Not Collected');
  String get bankTransfer      => t('Uhamisho wa Benki',    'Bank Transfer');
  String get filterCashNC      => t('Cash NC',              'Cash NC');
  String get filterBankTrf     => t('Benki',                'Bank Transfer');
  String get filterVoided      => t('Imefutwa',             'Voided');
  String get salePending       => t('Inasubiri',            'Pending');
  String get saleVoided        => t('Imefutwa',             'Voided');

  // ── Sale Actions ─────────────────────────────────────────────────────────────
  String get recordPayment     => t('Rekodi Malipo',         'Record Payment');
  String get collectCash       => t('Kusanya Pesa',          'Collect Cash');
  String get confirmTransfer   => t('Thibitisha Uhamisho',   'Confirm Transfer');
  String get voidSale          => t('Futa Mauzo',            'Void Sale');
  String get returnSale        => t('Rudisha Bidhaa',        'Return Items');
  String get voidConfirmMsg    => t('Una uhakika unataka kufuta mauzo haya? Hifadhi itarudishwa.',
                                     'Are you sure you want to void this sale? Stock will be restored.');
  String get saleDetail        => t('Maelezo ya Mauzo',      'Sale Details');
  String get saleItemsLabel    => t('Bidhaa za Mauzo',       'Sale Items');
  String get enterPayAmt       => t('Ingiza kiasi cha malipo','Enter payment amount');
  String get balanceLabel      => t('Baki ya Deni',          'Balance Due');
  String get amountPaidLabel   => t('Kilicholipwa',          'Amount Paid');
  String get noItems           => t('Hakuna bidhaa',         'No items');

  // ── Manage (Categories & Units) ───────────────────────────────────────────────
  String get manage            => t('Simamia',               'Manage');
  String get categoriesTab     => t('Kategoria',             'Categories');
  String get unitsTab          => t('Vipimo',                'Units');
  String get staffTab          => t('Wafanyakazi',           'Staff');
  String get addCategory       => t('Ongeza Kategoria',      'Add Category');
  String get editCategory      => t('Hariri Kategoria',      'Edit Category');
  String get addUnit           => t('Ongeza Kipimo',         'Add Unit');
  String get editUnit          => t('Hariri Kipimo',         'Edit Unit');
  String get catNameHint       => t('Jina la kategoria...',  'Category name...');
  String get unitNameHint      => t('Jina la kipimo...',     'Unit name...');
  String get shortNameHint     => t('Jina fupi (k.m. Ltr, Kg)...', 'Short name (e.g. Ltr, Kg)...');
  String get noCats            => t('Hakuna kategoria',      'No categories');
  String get noUnitsData       => t('Hakuna vipimo',         'No units');
  String get deleteConfirm     => t('Una uhakika unataka kufuta?','Are you sure you want to delete?');
  String get tapToEdit         => t('Gusa kuhariri',         'Tap to edit');

  // ── Barcode Scanner ───────────────────────────────────────────────────────────
  String get scanBarcode    => t('Scan Barcode',                  'Scan Barcode');
  String get autoGenerate   => t('Tengeneza Kiotomatiki',         'Auto-Generate');
  String get pointCamera    => t('Elekeza kamera kwenye barcode', 'Point camera at barcode');
  String get barcodeHint    => t('Barcode imepatikana!',          'Barcode found!');

  // ── Expiry ────────────────────────────────────────────────────────────────────
  String get expired        => t('IMEISHA MUDA',           'EXPIRED');
  String get expiringSoon   => t('KARIBU KUISHA',          'EXPIRING SOON');
  String get expiryOptional => t('Tarehe ya Mwisho (hiari)','Expiry Date (optional)');
  String get tapToPickDate  => t('Gusa kuchagua tarehe',   'Tap to pick date');

  // ── Common ────────────────────────────────────────────────
  String get save           => t('Hifadhi',          'Save');
  String get cancel         => t('Ghairi',           'Cancel');
  String get delete         => t('Futa',             'Delete');
  String get done           => t('Imekamilika',      'Done');
  String get error          => t('Hitilafu',         'Error');
  String get noData         => t('Hakuna data',      'No data');
  String get mainBranch     => t('Tawi Kuu',         'Main Branch');
  String get logoutConfirm  => t('Una uhakika unataka kutoka?','Are you sure you want to logout?');
  String get language       => t('Lugha',            'Language');
}
