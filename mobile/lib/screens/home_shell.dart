import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import 'channels_screen.dart';
import 'cloud_screen.dart';
import 'explore_screen.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _i = 0;

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
    const pages = [ExploreScreen(), FeedScreen(), ChannelsScreen(), CloudScreen(), ProfileScreen()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _i, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.dynamic_feed_outlined), selectedIcon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Channels'),
          NavigationDestination(icon: Icon(Icons.cloud_outlined), selectedIcon: Icon(Icons.cloud), label: 'Cloud'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
