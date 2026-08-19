import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/local_store.dart';
import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final String role;
  const RegisterScreen({super.key, this.role = 'customer'});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final location = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  String? error;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    location.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().length < 2 ||
        phone.text.trim().isEmpty ||
        password.text.length < 6) {
      setState(
        () => error = tr(
          'Jaza jina, namba sahihi na password ya angalau herufi 6.',
          'Enter your name, phone and a password of at least 6 characters.',
        ),
      );
      return;
    }
    if (password.text != confirmPassword.text) {
      setState(
        () => error = tr('Password hazifanani.', 'Passwords do not match.'),
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = await ApiService.register(
        name.text.trim(),
        phone.text.trim(),
        password.text,
        location.text.trim(),
        role: widget.role,
      );
      await SessionStore.save(session);
      if (!mounted) return;
      Navigator.pop(context, session);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get isBroker => widget.role == 'broker';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        isBroker
            ? tr('Jisajili kama Broker', 'Register as Broker')
            : tr('Fungua Akaunti', 'Create Account'),
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: yellow,
                child: Icon(
                  isBroker
                      ? Icons.agriculture_outlined
                      : Icons.person_add_alt_1_rounded,
                  size: 38,
                  color: green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isBroker
                    ? tr('Jisajili kama Broker/Mfugaji', 'Join as a Broker')
                    : tr('Jisajili KukuPaja', 'Join KukuPaja'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              if (isBroker) ...[
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Baada ya kujisajili, admin atapitia na kukuthibitisha kabla ya kuweka kuku sokoni.',
                    'After registering, an admin will review and verify you before you can list poultry.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 22),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Jina kamili', 'Full name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: tr('Namba ya simu', 'Phone number'),
                  hintText: '07XXXXXXXX',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: location,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Eneo unaloishi', 'Your location'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: tr(
                    'Password (angalau 6)',
                    'Password (at least 6)',
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => hidePassword = !hidePassword),
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassword,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: tr('Rudia password', 'Confirm password'),
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : submit,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(tr('Tengeneza Akaunti', 'Create Account')),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  'Ukisajiliwa utaingia moja kwa moja.',
                  'You will be signed in automatically.',
                ),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
