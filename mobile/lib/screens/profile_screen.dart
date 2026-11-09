import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'login_sheet.dart';
import 'payment_status_screen.dart';
import 'premium_screen.dart';

/// Profile tab: users without an active plan (when plans are visible to them) land on the
/// plans page directly; everyone else gets the account view. Reacts live to status changes.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.webViewBuilder});
  final Widget Function(BuildContext, Uri)? webViewBuilder;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (app.showPremiumEntry && !app.status.isPremium) {
          return PremiumScreen(
            webViewBuilder: webViewBuilder,
            actions: [
              IconButton(
                key: const Key('account_button'),
                tooltip: 'Account',
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Account')), body: AccountView(key: Key('account_view'))))),
              ),
            ],
          );
        }
        return const AccountView(key: Key('account_view'));
      },
    );
  }
}

class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.status;
        final d = s.planEndsAt;
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (app.showPremiumEntry && s.isPremium)
            Card(child: ListTile(
              leading: const Icon(Icons.workspace_premium, color: Tokens.gold),
              title: const Text('Upgrade / Renew'),
              subtitle: const Text('Renewing extends your end date'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())),
            )),
          Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(s.isGuest ? 'Guest' : (sb.auth.currentUser?.email ?? 'Account')),
            subtitle: Text(_planLine(s, d)),
            trailing: s.isGuest ? TextButton(onPressed: () => requireAccount(context), child: const Text('Log in')) : null,
          )),
          if (s.isPremium || app.showPrices)
            ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Payment history'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()))),
          const ListTile(leading: Icon(Icons.groups), title: Text('My channels')),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy policy'), onTap: () => launchUrl(Uri.parse('${Config.websiteUrl}/privacy'), mode: LaunchMode.externalApplication)),
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Terms'), onTap: () => launchUrl(Uri.parse('${Config.websiteUrl}/terms'), mode: LaunchMode.externalApplication)),
          if (!s.isGuest) ...[
            ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () async { await sb.auth.signOut(); await sb.auth.signInAnonymously(); await app.refresh(); }),
            ListTile(leading: const Icon(Icons.delete_forever, color: Tokens.danger), title: const Text('Delete account'), onTap: () => _deleteAccount(context, app)),
          ],
          const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: Text('Version ${Config.versionLabel}', key: Key('version_label'), style: TextStyle(color: Tokens.muted)))),
        ]);
      },
    );
  }

  String _planLine(dynamic s, DateTime? d) {
    if (s.isGuest) return 'Log in for 15 GB free cloud storage';
    if (s.isPremium) return '${s.planName ?? 'Premium'} active${d == null ? '' : ' until ${d.day}/${d.month}/${d.year}'}';
    return 'Free account';
  }

  Future<void> _deleteAccount(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('Your profile, files and posts will be permanently deleted. Payment records are kept anonymised for legal reasons.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (ok != true) return;
    try {
      await sb.functions.invoke('delete-account');
      await sb.auth.signOut();
      await sb.auth.signInAnonymously();
      await app.refresh();
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete. Please try again.')));
    }
  }
}
