import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Error al iniciar sesión'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Left panel: brand ────────────────────────────────────────
          if (MediaQuery.sizeOf(context).width >= 800)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2D1065), Color(0xFF4C1D95), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(top: -80, left: -80, child: _Circle(size: 280, opacity: 0.08)),
                    Positioned(bottom: -60, right: -60, child: _Circle(size: 320, opacity: 0.06)),
                    Positioned(top: 180, right: 40, child: _Circle(size: 120, opacity: 0.10)),
                    // Content
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.auto_stories_rounded, size: 36, color: Colors.white),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Meraki Tales',
                              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Panel de Administración',
                              style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w400),
                            ),
                            const SizedBox(height: 48),
                            _FeatureRow(icon: Icons.auto_awesome_rounded, text: 'Crea cuentos con inteligencia artificial'),
                            const SizedBox(height: 16),
                            _FeatureRow(icon: Icons.image_rounded, text: 'Genera imágenes y audio automáticamente'),
                            const SizedBox(height: 16),
                            _FeatureRow(icon: Icons.public_rounded, text: 'Publica en la app con un solo toque'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Right panel: form ────────────────────────────────────────
          SizedBox(
            width: MediaQuery.sizeOf(context).width >= 800 ? 440 : MediaQuery.sizeOf(context).width,
            child: Container(
              color: AppColors.background,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo (only on mobile, left panel hidden)
                      if (MediaQuery.sizeOf(context).width < 800) ...[
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF9F67FF), Color(0xFF7C3AED)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_stories_rounded, size: 28, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text('Meraki Tales', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const Text('Iniciar sesión', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      const Text('Accede al panel de administración', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 32),

                      // Email field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) => _signIn(),
                            decoration: const InputDecoration(
                              hintText: 'admin@meraki.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            onSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.destructiveSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.destructive),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.destructive, fontSize: 13))),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _signIn,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Iniciar sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
      ],
    );
  }
}
