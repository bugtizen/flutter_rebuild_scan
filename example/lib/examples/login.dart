import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

/// Login form with field-level marks and local-only validation.
class LoginExample extends StatefulWidget {
  const LoginExample({super.key});
  @override
  State<LoginExample> createState() => _LoginExampleState();
}

class _LoginExampleState extends State<LoginExample> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscurePassword = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void signIn() {
    FocusScope.of(context).unfocus();
    final valid = email.text.contains('@') && password.text.length >= 6;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          valid
              ? 'Signed in locally as ${email.text}'
              : 'Enter an email and a password of at least 6 characters',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text('Demo only · credentials stay in this screen.'),
          const SizedBox(height: 12),
          _TrackedField(
            name: 'Login email',
            label: 'Email',
            controller: email,
            keyboard: TextInputType.emailAddress,
          ),
          _TrackedField(
            name: 'Login password',
            label: 'Password',
            controller: password,
            obscure: obscurePassword,
            suffix: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: signIn, child: const Text('Sign in')),
        ],
      ),
    ),
  );
}

/// Tracks the field value builder so typing only marks that input.
class _TrackedField extends StatelessWidget {
  const _TrackedField({
    required this.name,
    required this.label,
    required this.controller,
    this.keyboard,
    this.obscure = false,
    this.suffix,
  });
  final String name, label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, _, child) {
          RebuildScan.mark(context, name: name, tag: 'login-form');
          return TextField(
            key: ValueKey('${name.toLowerCase().replaceAll(' ', '-')}-input'),
            controller: controller,
            keyboardType: keyboard,
            obscureText: obscure,
            decoration: InputDecoration(labelText: label, suffixIcon: suffix),
          );
        },
      );
}
