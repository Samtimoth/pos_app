import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── World Countries ──────────────────────────────────────────────────────────
const kCountries = [
  'Afghanistan','Albania','Algeria','Angola','Argentina','Armenia','Australia',
  'Austria','Azerbaijan','Bahrain','Bangladesh','Belarus','Belgium','Bolivia',
  'Bosnia and Herzegovina','Botswana','Brazil','Bulgaria','Burkina Faso',
  'Burundi','Cambodia','Cameroon','Canada','Chad','Chile','China','Colombia',
  'Congo (DRC)','Congo (Republic)','Costa Rica','Croatia','Cuba','Czech Republic',
  'Denmark','Dominican Republic','Ecuador','Egypt','El Salvador','Eritrea',
  'Ethiopia','Finland','France','Georgia','Germany','Ghana','Greece','Guatemala',
  'Guinea','Haiti','Honduras','Hungary','India','Indonesia','Iran','Iraq',
  'Ireland','Israel','Italy','Ivory Coast','Jamaica','Japan','Jordan','Kazakhstan',
  'Kenya','Kosovo','Kuwait','Kyrgyzstan','Laos','Latvia','Lebanon','Libya',
  'Lithuania','Madagascar','Malawi','Malaysia','Mali','Mauritania','Mexico',
  'Moldova','Mongolia','Morocco','Mozambique','Myanmar','Namibia','Nepal',
  'Netherlands','New Zealand','Nicaragua','Niger','Nigeria','North Korea',
  'Norway','Oman','Pakistan','Palestine','Panama','Paraguay','Peru','Philippines',
  'Poland','Portugal','Qatar','Romania','Russia','Rwanda','Saudi Arabia',
  'Senegal','Serbia','Sierra Leone','Singapore','Somalia','South Africa',
  'South Korea','South Sudan','Spain','Sri Lanka','Sudan','Sweden','Switzerland',
  'Syria','Taiwan','Tajikistan','Tanzania','Thailand','Togo','Tunisia','Turkey',
  'Turkmenistan','Uganda','Ukraine','United Arab Emirates','United Kingdom',
  'United States','Uruguay','Uzbekistan','Venezuela','Vietnam','Yemen',
  'Zambia','Zimbabwe',
];

// ── World Currencies ──────────────────────────────────────────────────────────
const kCurrencies = [
  ('TZS', 'Tanzanian Shilling'),    ('KES', 'Kenyan Shilling'),
  ('UGX', 'Ugandan Shilling'),      ('RWF', 'Rwandan Franc'),
  ('ETB', 'Ethiopian Birr'),        ('ZMW', 'Zambian Kwacha'),
  ('MWK', 'Malawian Kwacha'),       ('ZWL', 'Zimbabwean Dollar'),
  ('BIF', 'Burundian Franc'),       ('SOS', 'Somali Shilling'),
  ('USD', 'US Dollar'),             ('EUR', 'Euro'),
  ('GBP', 'British Pound'),         ('JPY', 'Japanese Yen'),
  ('CNY', 'Chinese Yuan'),          ('CAD', 'Canadian Dollar'),
  ('AUD', 'Australian Dollar'),     ('CHF', 'Swiss Franc'),
  ('INR', 'Indian Rupee'),          ('SGD', 'Singapore Dollar'),
  ('NGN', 'Nigerian Naira'),        ('GHS', 'Ghanaian Cedi'),
  ('ZAR', 'South African Rand'),    ('EGP', 'Egyptian Pound'),
  ('MAD', 'Moroccan Dirham'),       ('XOF', 'West African CFA'),
  ('XAF', 'Central African CFA'),   ('DZD', 'Algerian Dinar'),
  ('AED', 'UAE Dirham'),            ('SAR', 'Saudi Riyal'),
  ('QAR', 'Qatari Riyal'),          ('KWD', 'Kuwaiti Dinar'),
  ('BHD', 'Bahraini Dinar'),        ('OMR', 'Omani Rial'),
  ('PKR', 'Pakistani Rupee'),       ('BDT', 'Bangladeshi Taka'),
  ('LKR', 'Sri Lankan Rupee'),      ('MYR', 'Malaysian Ringgit'),
  ('IDR', 'Indonesian Rupiah'),     ('PHP', 'Philippine Peso'),
  ('THB', 'Thai Baht'),             ('VND', 'Vietnamese Dong'),
  ('BRL', 'Brazilian Real'),        ('ARS', 'Argentine Peso'),
  ('CLP', 'Chilean Peso'),          ('COP', 'Colombian Peso'),
  ('MXN', 'Mexican Peso'),          ('PEN', 'Peruvian Sol'),
  ('RUB', 'Russian Ruble'),         ('TRY', 'Turkish Lira'),
  ('PLN', 'Polish Zloty'),          ('SEK', 'Swedish Krona'),
  ('NOK', 'Norwegian Krone'),       ('DKK', 'Danish Krone'),
  ('HUF', 'Hungarian Forint'),      ('CZK', 'Czech Koruna'),
  ('ILS', 'Israeli Shekel'),        ('KRW', 'South Korean Won'),
];

/// Label for a currency code, e.g. "TZS — Tanzanian Shilling".
String currencyLabel(String code) {
  final m = kCurrencies.firstWhere((c) => c.$1 == code, orElse: () => (code, ''));
  return m.$2.isNotEmpty ? '$code — ${m.$2}' : code;
}

// ── Tappable field that opens a searchable picker ────────────────────────────
class GeoPickerTile extends StatelessWidget {
  final String value;
  final IconData icon;
  final String placeholder;
  final VoidCallback onTap;

  const GeoPickerTile({
    super.key,
    required this.value,
    required this.icon,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : placeholder,
            style: TextStyle(
              color: value.isNotEmpty ? AppColors.textWhite : AppColors.textMuted,
              fontSize: 14,
            ),
          ),
        ),
        Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 22),
      ]),
    ),
  );
}

// ── Searchable picker dialog (countries/currencies/etc.) ─────────────────────
class SearchPickerDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final String Function(String) labelOf;
  final String current;

  const SearchPickerDialog({
    super.key,
    required this.title,
    required this.items,
    required this.labelOf,
    required this.current,
  });

  @override
  State<SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<SearchPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items
              .where((v) => widget.labelOf(v).toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(widget.title,
                    style: TextStyle(
                        color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text('${_filtered.length} matokeo',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final v        = _filtered[i];
                  final label    = widget.labelOf(v);
                  final selected = v == widget.current;
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    title: Text(label,
                        style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textLight,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18)
                        : null,
                    tileColor: selected ? AppColors.primary.withAlpha(20) : null,
                    onTap: () => Navigator.pop(context, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
