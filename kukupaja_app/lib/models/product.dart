class Product {
  final int id;
  final String name;
  final String location;
  final int price;
  final int stock;
  final String image;
  final String category;

  const Product(
    this.id,
    this.name,
    this.location,
    this.price,
    this.stock,
    this.image,
    this.category,
  );

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    int.parse('${j['id']}'),
    '${j['name']}',
    '${j['location']}',
    (num.tryParse('${j['customer_price']}') ?? 0).round(),
    (num.tryParse('${j['available_stock']}') ?? 0).round(),
    '${j['image_url'] ?? ''}',
    '${j['category'] ?? 'vingine'}',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'price': price,
    'stock': stock,
    'image': image,
    'category': category,
  };

  factory Product.fromCacheJson(Map<String, dynamic> j) => Product(
    j['id'] as int,
    '${j['name']}',
    '${j['location']}',
    j['price'] as int,
    j['stock'] as int,
    '${j['image']}',
    '${j['category']}',
  );
}

const demoProducts = [
  Product(
    1,
    'Kuku wa Kienyeji',
    'Morogoro',
    15000,
    28,
    'https://images.unsplash.com/photo-1548550023-2bdb3c5beed7',
    'kienyeji',
  ),
  Product(
    2,
    'Kuku wa Broiler',
    'Dar es Salaam',
    12000,
    50,
    'https://images.unsplash.com/photo-1569396116180-210c182bedb8',
    'broiler',
  ),
  Product(
    3,
    'Kuku wa Mayai',
    'Pwani',
    18000,
    35,
    'https://images.unsplash.com/photo-1563281577-a7be47e20db9',
    'mayai',
  ),
];
