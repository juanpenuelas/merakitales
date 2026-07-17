import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Error'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final form = AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bienvenido de nuevo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Inicia sesión para continuar la historia.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            obscureText: true,
            onSubmitted: (_) => _signIn(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _loading ? null : _signIn,
            child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Text('Entrar'),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 700;
        if (wide) {
          return Row(children: [
            Expanded(child: _illustration(context)),
            Expanded(child: Center(child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: SizedBox(width: 400, child: form),
            ))),
          ]);
        }
        return Column(children: [
          SizedBox(height: 180, width: double.infinity, child: _illustration(context)),
          Expanded(child: Center(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: 400, child: form),
          ))),
        ]);
      }),
    );
  }

  Widget _illustration(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Image.asset('assets/images/meraki_tales_image01.png', fit: BoxFit.cover),
      // Subtle brand overlay so the logo/tagline stay legible over the artwork.
      DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.55)],
        ),
      )),
      Positioned(
        left: 32,
        right: 32,
        bottom: 40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/app_launcher_icon.png', width: 48, height: 48),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Meraki Tales',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Donde cada cuento cobra vida.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    ]);
  }
}
