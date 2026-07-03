import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme/app_theme.dart';
import 'login/login_page.dart';
import 'dashboard/dashboard_page.dart';
import 'drafts/drafts_list_page.dart';
import 'drafts/draft_workspace_page.dart';
import 'published/published_list_page.dart';
import 'published/published_tale_detail_page.dart';

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
      initialLocation: '/dashboard',
      redirect: (context, state) {
        final onLogin = state.matchedLocation == '/login';
        if (!authed && !onLogin) return '/login';
        if (authed && onLogin) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (c, s) => const LoginPage()),

        // Dashboard hub
        GoRoute(path: '/dashboard', builder: (c, s) => const DashboardPage()),

        // Drafts
        GoRoute(
          path: '/drafts',
          builder: (c, s) => const DraftsListPage(),
          routes: [
            GoRoute(
              path: 'workspace/:id',
              builder: (c, s) => DraftWorkspacePage(draftId: s.pathParameters['id']!),
            ),
          ],
        ),

        // Published
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
                    appBar: AppBar(
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => c.go('/published'),
                      ),
                    ),
                    body: const Center(child: Text('ID de cuento inválido')),
                  );
                }
                return PublishedTaleDetailPage(taleId: taleId);
              },
            ),
          ],
        ),
      ],
    );
  }
}
