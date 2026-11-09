import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import 'channels_screen.dart';
import 'cloud_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../widgets/orbix_nav_bar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _i = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Retry queued payment results on every resume.
    if (s == AppLifecycleState.resumed) {
      final app = AppScope.of(context);
      app.flushPending();
      app.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // Plans-first users see a crown "Premium" tab; plan holders / hidden-plans users see "Profile".
    final premiumTab = app.showPremiumEntry && !app.status.isPremium;
    final pages = [
      const CloudScreen(),
      HomeScreen(onSearch: () => setState(() => _i = 2), onProfile: () => setState(() => _i = 4), onSeeAllChannels: () => setState(() => _i = 3)),
      const ExploreScreen(),
      const ChannelsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _i, children: pages)),
      bottomNavigationBar: OrbixNavBar(
        index: _i,
        onTap: (v) => setState(() => _i = v),
        items: [
          const NavItem(Icons.cloud_outlined, 'Cloud', Icons.cloud),
          const NavItem(Icons.grid_view_outlined, 'Home', Icons.grid_view_rounded),
          const NavItem(Icons.explore_outlined, 'Explore', Icons.explore),
          const NavItem(Icons.live_tv_outlined, 'Channel', Icons.live_tv),
          premiumTab ? const NavItem(Icons.workspace_premium_outlined, 'Premium', Icons.workspace_premium) : const NavItem(Icons.person_outline, 'Profile', Icons.person),
        ],
      ),
    );
  }
}
