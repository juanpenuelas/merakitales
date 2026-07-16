import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class AdminScaffold extends StatelessWidget {
  final Widget child;

  const AdminScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    
    int selectedIndex = 0;
    if (location.startsWith('/dashboard')) selectedIndex = 0;
    else if (location.startsWith('/drafts')) selectedIndex = 1;
    else if (location.startsWith('/published')) selectedIndex = 2;
    else if (location.startsWith('/categories')) selectedIndex = 3;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/dashboard');
                  break;
                case 1:
                  context.go('/drafts');
                  break;
                case 2:
                  context.go('/published');
                  break;
                case 3:
                  context.go('/categories');
                  break;
              }
            },
            extended: MediaQuery.of(context).size.width > 800,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withOpacity(0.1),
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.edit_document),
                selectedIcon: Icon(Icons.edit_document),
                label: Text('Borradores'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: Text('Publicados'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Categorías'),
              ),
            ],
            trailing: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: IconButton(
                icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
