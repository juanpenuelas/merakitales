import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth/auth_gate.dart';
import 'login/login_page.dart';
import 'drafts/drafts_list_page.dart';
import 'drafts/draft_detail_page.dart';
import 'drafts/draft_create_page.dart';
import 'published/published_list_page.dart';

class MerakiAdminApp extends StatelessWidget {
  const MerakiAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final authed = snapshot.data != null;
        final router = _buildRouter(authed);
        return MaterialApp.router(
          title: 'Meraki Tales Admin',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1D2428)),
          routerConfig: router,
        );
      },
    );
  }

  GoRouter _buildRouter(bool authed) {
    return GoRouter(
      initialLocation: '/drafts',
      redirect: (context, state) {
        final onLogin = state.matchedLocation == '/login';
        if (!authed && !onLogin) return '/login';
        if (authed && onLogin) return '/drafts';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
        GoRoute(
          path: '/drafts',
          builder: (c, s) => const DraftsListPage(),
          routes: [
            GoRoute(path: 'new', builder: (c, s) => const DraftCreatePage()),
            GoRoute(path: ':id', builder: (c, s) => DraftDetailPage(draftId: s.pathParameters['id']!)),
          ],
        ),
        GoRoute(path: '/published', builder: (c, s) => const PublishedListPage()),
      ],
    );
  }
}
