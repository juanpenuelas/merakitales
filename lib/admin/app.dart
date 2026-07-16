import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme/app_theme.dart';
import 'auth/auth_gate.dart';
import 'login/login_page.dart';
import 'drafts/drafts_list_page.dart';
import 'drafts/draft_detail_page.dart';
import 'drafts/draft_create_page.dart';
import 'drafts/draft_create_manual_page.dart';
import 'published/published_list_page.dart';
import 'published/published_tale_detail_page.dart';
import 'categories/categories_page.dart';

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
          theme: AppTheme.light(),
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
            GoRoute(
              path: 'manual',
              builder: (c, s) => const DraftCreateManualPage(),
              routes: [
                GoRoute(path: ':id', builder: (c, s) => DraftCreateManualPage(draftId: s.pathParameters['id'])),
              ],
            ),
            GoRoute(path: ':id', builder: (c, s) => DraftDetailPage(draftId: s.pathParameters['id']!)),
          ],
        ),
        GoRoute(
          path: '/published',
          builder: (c, s) => const PublishedListPage(),
          routes: [
            GoRoute(
              path: ':taleId',
              builder: (c, s) {
                final taleId = int.tryParse(s.pathParameters['taleId']!);
                if (taleId == null) {
                  return Scaffold(
                    appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => c.go('/published'))),
                    body: const Center(child: Text('ID de cuento inválido')),
                  );
                }
                return PublishedTaleDetailPage(taleId: taleId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/categories',
          builder: (c, s) => const CategoriesPage(),
        ),
      ],
    );
  }
}
