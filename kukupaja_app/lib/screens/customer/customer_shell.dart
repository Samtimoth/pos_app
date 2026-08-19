import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/local_store.dart';
import '../../models/models.dart';
import '../auth/login_screen.dart';
import 'account_page.dart';
import 'cart_page.dart';
import 'customer_home.dart';
import 'orders_page.dart';

class CustomerShell extends StatefulWidget {
  final Session? session;
  /// A previously-saved Admin/Broker session that isn't auto-resumed on
  /// cold start for safety, but can be offered back as a one-tap "continue"
  /// prompt from the Akaunti tab instead of being silently discarded.
  final Session? pendingElevatedSession;
  const CustomerShell({super.key, this.session, this.pendingElevatedSession});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int index = 0;
  final cart = <Product>[];
  Session? session;
  Session? pendingElevatedSession;

  @override
  void initState() {
    super.initState();
    session = widget.session;
    pendingElevatedSession = widget.pendingElevatedSession;
    languageNotifier.addListener(_refreshLanguage);
    _restoreCart();
  }

  Future<void> _forgetPendingSession() async {
    await SessionStore.clear();
    if (mounted) setState(() => pendingElevatedSession = null);
  }

  Future<void> _restoreCart() async {
    final saved = await CartStore.load();
    if (saved.isNotEmpty && mounted) setState(() => cart.addAll(saved));
  }

  void _refreshLanguage() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    languageNotifier.removeListener(_refreshLanguage);
    super.dispose();
  }

  Future<String?> requireCustomerLogin() async {
    if (session != null) return session!.token;
    final result = await Navigator.push<Session>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(expectedRole: 'customer', returnSession: true),
      ),
    );
    if (result != null && mounted) setState(() => session = result);
    return result?.token;
  }

  void _updateCart(void Function() mutate) {
    setState(mutate);
    CartStore.save(cart);
  }

  Future<void> _logout() async {
    await SessionStore.clear();
    if (mounted) setState(() => session = null);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomerHome(
        onAdd: (p) => _updateCart(() => cart.add(p)),
        onGoToCart: () => setState(() => index = 2),
      ),
      OrdersPage(token: session?.token, onRequireLogin: requireCustomerLogin),
      CartPage(
        cart: cart,
        token: session?.token,
        onRequireLogin: requireCustomerLogin,
        onClear: () => _updateCart(cart.clear),
        onAdd: (product) => _updateCart(() => cart.add(product)),
        onRemove: (product) => _updateCart(() => cart.remove(product)),
        onGoToHome: () => setState(() => index = 0),
      ),
      AccountPage(
        session: session,
        onLogin: requireCustomerLogin,
        onLogout: session == null ? null : _logout,
        pendingElevatedSession: pendingElevatedSession,
        onForgetPendingSession: _forgetPendingSession,
      ),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: tr('Nyumbani', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long),
            label: tr('Oda Zangu', 'My Orders'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.length}'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: tr('Kikapu', 'Cart'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: tr('Akaunti', 'Account'),
          ),
        ],
      ),
    );
  }
}
