class Advertisement {
  final int id;
  final String advertiser;
  final String title;
  final String subtitle;
  final String image;
  final String buttonText;
  final String category;

  const Advertisement({
    required this.id,
    required this.advertiser,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.buttonText,
    required this.category,
  });

  factory Advertisement.fromJson(Map<String, dynamic> j) => Advertisement(
    id: int.parse('${j['id']}'),
    advertiser: '${j['advertiser_name']}',
    title: '${j['title']}',
    subtitle: '${j['subtitle'] ?? ''}',
    image: '${j['image_url'] ?? ''}',
    buttonText: '${j['button_text'] ?? 'Angalia Sasa'}',
    category: '${j['target_category'] ?? 'wote'}',
  );
}
