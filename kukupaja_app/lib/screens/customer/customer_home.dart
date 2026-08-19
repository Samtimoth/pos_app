import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/product_image.dart';
import 'notifications_page.dart';
import 'product_page.dart';

class CustomerHome extends StatefulWidget {
  final ValueChanged<Product> onAdd;
  final VoidCallback onGoToCart;
  const CustomerHome({super.key, required this.onAdd, required this.onGoToCart});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String selectedCategory = 'wote';
  String searchQuery = '';
  bool gridLayout = true;
  final favoriteIds = <int>{};
  late Future<List<Product>> productsFuture;
  final adController = PageController(viewportFraction: .91);
  Timer? adTimer;
  int adCount = 0;
  int currentAd = 0;

  @override
  void initState() {
    super.initState();
    productsFuture = ApiService.products();
    adTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !adController.hasClients || adCount < 2) return;
      currentAd = (currentAd + 1) % adCount;
      adController.animateToPage(
        currentAd,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    adTimer?.cancel();
    adController.dispose();
    super.dispose();
  }

  void selectCategory(String category) {
    setState(() {
      selectedCategory = category;
      productsFuture = ApiService.products(category: category);
    });
  }

  void toggleFavorite(int productId) {
    setState(() {
      favoriteIds.contains(productId)
          ? favoriteIds.remove(productId)
          : favoriteIds.add(productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Product>>(
        future: productsFuture,
        builder: (context, snapshot) {
          final products = snapshot.data ?? demoProducts;
          final visibleProducts = products.where((product) {
            final query = searchQuery.trim().toLowerCase();
            return query.isEmpty ||
                product.name.toLowerCase().contains(query) ||
                product.location.toLowerCase().contains(query);
          }).toList();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _AnimatedGradientHeader(
                padding: EdgeInsets.fromLTRB(
                  18,
                  MediaQuery.paddingOf(context).top + 14,
                  18,
                  24,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: yellow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/kukupaja_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KukuPaja',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Tunauza ladha ya kuku',
                                style: TextStyle(color: yellow, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: green,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          ),
                          icon: const Icon(Icons.notifications_none),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tr(
                          'Kuku bora, bei nzuri.',
                          'Quality poultry, better prices.',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tr(
                          'Agiza kwa urahisi, admin tunashughulikia mengine.',
                          'Order easily, our admin handles the rest.',
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: (value) => setState(() => searchQuery = value),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        hintText: tr(
                          'Tafuta kuku, mayai au vifaranga',
                          'Search poultry, eggs or chicks',
                        ),
                        suffixIcon: const Icon(Icons.tune),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Advertisement>>(
                future: ApiService.advertisements(),
                builder: (context, adSnapshot) {
                  final ads = adSnapshot.data ?? const <Advertisement>[];
                  if (ads.isEmpty) return const SizedBox.shrink();
                  adCount = ads.length;
                  return SizedBox(
                    height: 210,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          bottom: 18,
                          child: PageView.builder(
                            controller: adController,
                            onPageChanged: (value) =>
                                setState(() => currentAd = value),
                            itemCount: ads.length,
                            itemBuilder: (context, index) => _AdvertisementCard(
                              ad: ads[index],
                              onOpen: () => selectCategory(ads[index].category),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              ads.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: currentAd == index ? 20 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: currentAd == index
                                      ? green
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 92,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryTile(
                      '🐔',
                      tr('Wote', 'All'),
                      'wote',
                      const Color(0xFFFFF3CD),
                      selected: selectedCategory == 'wote',
                      onTap: selectCategory,
                    ),
                    _CategoryTile(
                      '🐓',
                      tr('Kienyeji', 'Local'),
                      'kienyeji',
                      const Color(0xFFFFE0B2),
                      selected: selectedCategory == 'kienyeji',
                      onTap: selectCategory,
                    ),
                    _CategoryTile(
                      '🍗',
                      'Broiler',
                      'broiler',
                      const Color(0xFFFBE7E0),
                      selected: selectedCategory == 'broiler',
                      onTap: selectCategory,
                    ),
                    _CategoryTile(
                      '🐔',
                      tr('Kuku wa Kisasa', 'Modern breeds'),
                      'kuku_wakisasa',
                      const Color(0xFFE8EAF6),
                      selected: selectedCategory == 'kuku_wakisasa',
                      onTap: selectCategory,
                    ),
                    _CategoryTile(
                      '🥚',
                      tr('Mayai', 'Eggs'),
                      'mayai',
                      const Color(0xFFFFF3CD),
                      selected: selectedCategory == 'mayai',
                      onTap: selectCategory,
                    ),
                    _CategoryTile(
                      '🐣',
                      tr('Vifaranga', 'Chicks'),
                      'vifaranga',
                      const Color(0xFFFFE0B2),
                      selected: selectedCategory == 'vifaranga',
                      onTap: selectCategory,
                    ),
                    _CategoryTile(
                      '📦',
                      tr('Vingine', 'Other'),
                      'vingine',
                      const Color(0xFFECEFF1),
                      selected: selectedCategory == 'vingine',
                      onTap: selectCategory,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('Bidhaa Maarufu', 'Popular Products'),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: gridLayout
                          ? 'Panga kama orodha'
                          : 'Panga kama grid',
                      onPressed: () => setState(() => gridLayout = !gridLayout),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          gridLayout ? Icons.view_list : Icons.grid_view,
                          key: ValueKey(gridLayout),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(minHeight: 2),
              if (visibleProducts.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                _EmptyProducts(query: searchQuery),
              if (!gridLayout)
                ...visibleProducts.asMap().entries.map((entry) {
                  final p = entry.value;
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 350 + entry.key * 120),
                    tween: Tween(begin: 0, end: 1),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Card(
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFFEBE3DB)),
                        ),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductPage(
                                product: p,
                                onAdd: widget.onAdd,
                                onGoToCart: widget.onGoToCart,
                                isFavorite: favoriteIds.contains(p.id),
                                onFavorite: () => toggleFavorite(p.id),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'product-${p.id}',
                                child: SizedBox(
                                  width: 108,
                                  height: 112,
                                  child: ProductImage(product: p),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => toggleFavorite(p.id),
                                            child: Icon(
                                              favoriteIds.contains(p.id)
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: 20,
                                              color: favoriteIds.contains(p.id)
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 15,
                                            color: Colors.grey,
                                          ),
                                          Expanded(
                                            child: Text(
                                              p.location,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        money(p.price),
                                        style: const TextStyle(
                                          color: green,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${p.stock} wanapatikana',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              if (gridLayout)
                GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: .82,
                      ),
                  itemCount: visibleProducts.length,
                  itemBuilder: (context, index) {
                    final p = visibleProducts[index];
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + index * 80),
                      tween: Tween(begin: 0, end: 1),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: _ProductGridCard(
                        product: p,
                        onAdd: widget.onAdd,
                        onGoToCart: widget.onGoToCart,
                        isFavorite: favoriteIds.contains(p.id),
                        onFavorite: () => toggleFavorite(p.id),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedGradientHeader extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  const _AnimatedGradientHeader({required this.padding, required this.child});

  @override
  State<_AnimatedGradientHeader> createState() =>
      _AnimatedGradientHeaderState();
}

class _AnimatedGradientHeaderState extends State<_AnimatedGradientHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) {
      final value = Curves.easeInOut.transform(controller.value);
      return Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(
                const Color(0xFF7A1F04),
                const Color(0xFFE85319),
                value,
              )!,
              Color.lerp(
                const Color(0xFFC24010),
                const Color(0xFFF57A22),
                value,
              )!,
              Color.lerp(
                const Color(0xFFE85319),
                const Color(0xFF7A1F04),
                value,
              )!,
            ],
            begin: Alignment(-1 + value, -1),
            end: Alignment(1 - value, 1),
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33004325),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: child,
      );
    },
  );
}

class _CategoryTile extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  final bool selected;
  final ValueChanged<String> onTap;
  const _CategoryTile(
    this.emoji,
    this.label,
    this.value,
    this.color, {
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap(value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: selected ? green : color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: green.withValues(alpha: .35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? green : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyProducts extends StatelessWidget {
  final String query;
  const _EmptyProducts({required this.query});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 38,
          backgroundColor: Color(0xFFFFF3CD),
          child: Icon(Icons.search_off, size: 40, color: green),
        ),
        const SizedBox(height: 14),
        Text(
          query.isEmpty
              ? tr(
                  'Hakuna bidhaa kwenye category hii',
                  'No products in this category',
                )
              : tr('Hakuna matokeo ya “$query”', 'No results for “$query”'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          tr(
            'Jaribu category au neno lingine.',
            'Try another category or search term.',
          ),
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );
}

class _AdvertisementCard extends StatelessWidget {
  final Advertisement ad;
  final VoidCallback onOpen;
  const _AdvertisementCard({required this.ad, required this.onOpen});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFFD95A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -24,
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white24,
              child: ad.image.isEmpty
                  ? const Text('🐔', style: TextStyle(fontSize: 70))
                  : ClipOval(
                      child: Image.network(
                        ad.image,
                        width: 138,
                        height: 138,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * .56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Tangazo • ${ad.advertiser}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5A2310),
                      fontSize: 20,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    ad.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: onOpen,
                    child: Text(ad.buttonText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProductGridCard extends StatelessWidget {
  final Product product;
  final ValueChanged<Product> onAdd;
  final VoidCallback onGoToCart;
  final bool isFavorite;
  final VoidCallback onFavorite;
  const _ProductGridCard({
    required this.product,
    required this.onAdd,
    required this.onGoToCart,
    required this.isFavorite,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductPage(
            product: product,
            onAdd: onAdd,
            onGoToCart: onGoToCart,
            isFavorite: isFavorite,
            onFavorite: onFavorite,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'grid-product-${product.id}',
                  child: ProductImage(product: product),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onFavorite,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : green,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${product.stock} ${tr('zimebaki', 'left')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        product.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  money(product.price),
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
