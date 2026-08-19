import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/product_image.dart';

class ProductPage extends StatefulWidget {
  final Product product;
  final ValueChanged<Product> onAdd;
  final VoidCallback onGoToCart;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  const ProductPage({
    super.key,
    required this.product,
    required this.onAdd,
    required this.onGoToCart,
    this.isFavorite = false,
    this.onFavorite,
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: false,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'product-${product.id}',
                child: ProductImage(product: product),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        money(product.price),
                        style: const TextStyle(
                          fontSize: 20,
                          color: green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.location,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tr('Zimebaki', 'Available')}: ${product.stock}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withValues(
                        alpha: .55,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Chagua idadi', 'Choose quantity'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                money(product.price * quantity),
                                style: const TextStyle(color: green),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: quantity > 1
                              ? () => setState(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: quantity < product.stock
                              ? () => setState(() => quantity++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.verified, color: green),
                    title: Text('Bidhaa imethibitishwa na Admin'),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.vaccines, color: green),
                    title: Text('Chanjo: Newcastle na Gumboro'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: _FloatingCircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),
          if (widget.onFavorite != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 12,
              child: _FloatingCircleButton(
                icon: widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                iconColor: widget.isFavorite ? Colors.red : green,
                onTap: widget.onFavorite,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                for (var i = 0; i < quantity; i++) {
                  widget.onAdd(product);
                }
                widget.onGoToCart();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.bolt),
              label: Text(
                '${tr('Nunua Sasa', 'Buy Now')} • ${money(product.price * quantity)}',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  const _FloatingCircleButton({
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 3,
    shadowColor: Colors.black38,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: iconColor ?? Colors.black87, size: 22),
      ),
    ),
  );
}
