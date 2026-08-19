import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import 'admin_web_portal.dart';

class AdminProfilePage extends StatefulWidget {
  final Session session;
  final Future<Map<String, dynamic>> Function() loadProfile;
  final VoidCallback onLogout;
  const AdminProfilePage({
    super.key,
    required this.session,
    required this.loadProfile,
    required this.onLogout,
  });

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late Future<Map<String, dynamic>> profileFuture;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    profileFuture = widget.loadProfile();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Animation<double> _fade(double start, double end) => CurvedAnimation(
    parent: controller,
    curve: Interval(start, end, curve: Curves.easeOutCubic),
  );

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final anim = _fade(start, (start + 0.4).clamp(0.0, 1.0));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Profile Yangu'),
      backgroundColor: green,
      foregroundColor: Colors.white,
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: profileFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _staggered(
              0,
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7A1F04), green, Color(0xFFF57A22)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33004325),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Hero(
                      tag: 'admin-avatar',
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: yellow,
                        child: Text(
                          widget.session.name.isNotEmpty
                              ? widget.session.name[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: green,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.session.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Msimamizi (Admin)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      )
                    else if (user != null) ...[
                      const SizedBox(height: 16),
                      _infoRow(Icons.phone_outlined, '${user['phone'] ?? ''}'),
                      if ('${user['location'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _infoRow(
                          Icons.location_on_outlined,
                          '${user['location']}',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _staggered(
              1,
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.translate),
                      title: const Text('Lugha'),
                      subtitle: Text(
                        languageNotifier.value == 'sw'
                            ? 'Kiswahili'
                            : 'English',
                      ),
                      trailing: DropdownButton<String>(
                        value: languageNotifier.value,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: 'sw',
                            child: Text('Kiswahili'),
                          ),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (value) {
                          if (value != null) languageNotifier.value = value;
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ValueListenableBuilder<bool>(
                      valueListenable: darkModeNotifier,
                      builder: (context, dark, child) => SwitchListTile(
                        secondary: Icon(
                          dark ? Icons.dark_mode : Icons.light_mode,
                        ),
                        title: const Text('Muonekano'),
                        subtitle: Text(dark ? 'Dark mode' : 'Light mode'),
                        value: dark,
                        onChanged: (value) => darkModeNotifier.value = value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _staggered(
              2,
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: const Text('Server ya Backend'),
                      subtitle: Text(ApiConfig.baseUrl),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editServerUrl(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.grey,
                      ),
                      title: const Text('Fungua Web Portal (Advanced)'),
                      subtitle: const Text(
                        'Kwa mipangilio ya ziada isiyo ndani ya app bado',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminWebPortal(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _staggered(
              3,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Toka kwenye Akaunti'),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _infoRow(IconData icon, String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 15, color: Colors.white70),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ],
  );

  Future<void> _editServerUrl(BuildContext context) async {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.20/kukupaja_backend/api',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Hifadhi'),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await ApiConfig.setOverride(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server URL imebadilishwa. Rudi Home kuonyesha upya.'),
      ),
    );
  }
}
