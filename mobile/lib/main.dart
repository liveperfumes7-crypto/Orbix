import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/consent_gate.dart';
import 'screens/home_shell.dart';
import 'services/app_scope.dart';
import 'services/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  final state = AppState();
  runApp(OrbixApp(state: state));
  state.start();
}

class OrbixApp extends StatelessWidget {
  const OrbixApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: Config.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ConsentGate(child: AppScope(state: state, child: const HomeShell())),
      );
}
