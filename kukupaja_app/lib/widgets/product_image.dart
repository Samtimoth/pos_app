import 'package:flutter/material.dart';

import '../models/models.dart';

class ProductImage extends StatelessWidget {
  final Product product;
  const ProductImage({super.key, required this.product});

  @override
  Widget build(BuildContext context) => Image.network(
    product.image,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Container(
      color: const Color(0xFFFFF2C7),
      child: const Center(child: Text('🐔', style: TextStyle(fontSize: 58))),
    ),
  );
}
