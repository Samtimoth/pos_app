import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../admin/admin_shell.dart';
import '../broker/broker_shell.dart';
import 'support_page.dart';

class AccountPage extends StatelessWidget {
  final Session? session;
  final Future<String?> Function() onLogin;
  final VoidCallback? onLogout;
  final Session? pendingElevatedSession;
  final VoidCallback? onForgetPendingSession;
  const AccountPage({
    super.key,
    required this.session,
    required this.onLogin,
    this.onLogout,
    this.pendingElevatedSession,
    this.onForgetPendingSession,
  });

  @override
  Widget build(BuildContext context) {
    final elevated = pendingElevatedSession;
    final displayName = session?.name ?? elevated?.name ?? 'Karibu KukuPaja';
    final displaySubtitle = session != null
        ? 'Akaunti ya mteja'
        : elevated != null
        ? tr(
            'Umeingia kama ${elevated.role == 'admin' ? 'Admin' : 'Broker'}',
            'Signed in as ${elevated.role == 'admin' ? 'Admin' : 'Broker'}',
          )
        : 'Ingia wakati wa kuweka oda';
    return Scaffold(
    appBar: AppBar(title: Text(tr('Akaunti', 'Account'))),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7A1F04), Color(0xFFF57A22)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: yellow,
                child: session == null && elevated == null
                    ? const Icon(Icons.person, color: green, size: 34)
                    : Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      displaySubtitle,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (session == null && elevated == null)
                IconButton.filledTonal(
                  onPressed: onLogin,
                  icon: const Icon(Icons.login),
                )
              else if (session != null && onLogout != null)
                IconButton.filledTonal(
                  tooltip: tr('Toka', 'Log out'),
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                )
              else if (elevated != null && onForgetPendingSession != null)
                IconButton.filledTonal(
                  tooltip: tr('Toka', 'Log out'),
                  onPressed: onForgetPendingSession,
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE0B2),
                  child: Icon(Icons.support_agent, color: green),
                ),
                title: Text(tr('Msaada wa KukuPaja', 'KukuPaja Support')),
                subtitle: Text(
                  tr(
                    'Ongea na admin moja kwa moja',
                    'Chat directly with our admin',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final token = session?.token ?? await onLogin();
                  if (token == null || !context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupportPage(token: token),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3CD),
                  child: Icon(Icons.agriculture, color: Color(0xFF9A6700)),
                ),
                title: Text(
                  tr('Wewe ni Broker/Mfugaji?', 'Are you a broker/farmer?'),
                ),
                subtitle: Text(
                  tr(
                    'Post kuku na simamia stock yako',
                    'Post poultry and manage your stock',
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrokerShell()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(tr('Lugha', 'Language')),
                subtitle: Text(
                  languageNotifier.value == 'sw' ? 'Kiswahili' : 'English',
                ),
                trailing: DropdownButton<String>(
                  value: languageNotifier.value,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
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
                  secondary: Icon(dark ? Icons.dark_mode : Icons.light_mode),
                  title: Text(tr('Muonekano', 'Appearance')),
                  subtitle: Text(
                    dark
                        ? tr('Dark mode', 'Dark mode')
                        : tr('Light mode', 'Light mode'),
                  ),
                  value: dark,
                  onChanged: (value) => darkModeNotifier.value = value,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(tr('Usalama na Faragha', 'Safety & Privacy')),
                trailing: const Icon(Icons.chevron_right),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(tr('Kuhusu KukuPaja', 'About KukuPaja')),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(tr('Server ya Backend', 'Backend server')),
                subtitle: Text(ApiConfig.baseUrl),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editServerUrl(context),
              ),
            ],
          ),
        ),
        if (elevated != null) ...[
          const SizedBox(height: 18),
          _PendingSessionCard(session: elevated),
        ],
      ],
    ),
  );
  }

  Future<void> _editServerUrl(BuildContext context) async {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Server URL', 'Server URL')),
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
            child: Text(tr('Ghairi', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(tr('Hifadhi', 'Save')),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await ApiConfig.setOverride(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Server URL imebadilishwa. Rudi Home kuonyesha upya.',
            'Server URL updated. Go back to Home to refresh data.',
          ),
        ),
      ),
    );
  }
}

class _PendingSessionCard extends StatelessWidget {
  final Session session;
  const _PendingSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isAdmin = session.role == 'admin';
    final roleLabel = isAdmin ? 'Admin' : 'Broker';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFFE8EAF6) : const Color(0xFFFBE7E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAdmin ? const Color(0xFF303F9F) : const Color(0xFFC24010),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isAdmin
                    ? const Color(0xFF303F9F)
                    : const Color(0xFFC24010),
                child: Icon(
                  isAdmin ? Icons.shield_outlined : Icons.agriculture_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Umeingia kama $roleLabel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      session.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: isAdmin
                  ? const Color(0xFF303F9F)
                  : const Color(0xFFC24010),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => isAdmin
                    ? AdminShell(session: session)
                    : BrokerShell(session: session),
              ),
              (route) => false,
            ),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Fungua Dashboard'),
          ),
        ],
      ),
    );
  }
}
