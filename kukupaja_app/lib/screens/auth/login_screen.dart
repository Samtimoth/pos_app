import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/local_store.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../admin/admin_shell.dart';
import '../broker/broker_shell.dart';
import '../customer/customer_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String expectedRole;
  final bool returnSession;
  const LoginScreen({
    super.key,
    required this.expectedRole,
    this.returnSession = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController phone;
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    phone = TextEditingController(
      text: widget.expectedRole == 'broker'
          ? '255700000002'
          : widget.expectedRole == 'admin'
          ? '0695390690'
          : '',
    );
  }

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = await ApiService.login(phone.text.trim(), password.text);
      await SessionStore.save(session);
      if (!mounted) return;
      if (session.role != widget.expectedRole) {
        // Any account can sign in from any entry point (customer, broker or
        // admin) — if this account's real role differs from where they
        // logged in, send them straight to their actual home instead of
        // blocking them with a "wrong role" error.
        final page = switch (session.role) {
          'broker' => BrokerShell(session: session),
          'admin' => AdminShell(session: session),
          _ => CustomerShell(session: session),
        };
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => page),
          (route) => false,
        );
        return;
      }
      if (widget.returnSession) {
        Navigator.pop(context, session);
        return;
      }
      final page = switch (session.role) {
        'broker' => BrokerShell(session: session),
        'admin' => AdminShell(session: session),
        _ => CustomerShell(session: session),
      };
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.expectedRole) {
      'broker' => 'Broker',
      'admin' => 'Admin',
      _ => 'Mteja',
    };
    return Scaffold(
      appBar: AppBar(title: Text('Ingia kama $title')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: yellow,
                  child: Text('🐔', style: TextStyle(fontSize: 42)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Namba ya simu',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ingia'),
                  ),
                ),
                if (widget.expectedRole != 'admin') ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tr('Huna akaunti?', 'No account yet?')),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () async {
                                final session = await Navigator.push<Session>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(
                                      role: widget.expectedRole,
                                    ),
                                  ),
                                );
                                if (session == null || !context.mounted) return;
                                if (widget.returnSession) {
                                  Navigator.pop(context, session);
                                } else {
                                  final page = switch (session.role) {
                                    'broker' => BrokerShell(session: session),
                                    _ => CustomerShell(session: session),
                                  };
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => page),
                                  );
                                }
                              },
                        child: Text(
                          widget.expectedRole == 'broker'
                              ? tr(
                                  'Jisajili kama Broker',
                                  'Register as Broker',
                                )
                              : tr('Jisajili sasa', 'Create account'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Washa XAMPP Apache na MySQL kabla ya kuingia.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
