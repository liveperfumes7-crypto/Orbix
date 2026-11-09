import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'login_sheet.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<Map<String, dynamic>> _rows = [];
  Set<String> _joined = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // RLS returns only approved, visible, audience-matching channels (plus the user's own pending ones).
      final data = await sb.from('channels').select('id,name,description,category,members_count,review_status,created_by').order('members_count', ascending: false);
      _rows = List<Map<String, dynamic>>.from(data);
      final uid = sb.auth.currentUser?.id;
      if (uid != null) {
        final m = await sb.from('channel_members').select('channel_id').eq('user_id', uid);
        _joined = {for (final r in m) r['channel_id'] as String};
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String id) async {
    if (!await requireAccount(context)) return;
    final uid = sb.auth.currentUser!.id;
    if (_joined.contains(id)) {
      await sb.from('channel_members').delete().eq('channel_id', id).eq('user_id', uid);
    } else {
      await sb.from('channel_members').insert({'channel_id': id, 'user_id': uid});
    }
    await _load();
  }

  Future<void> _create() async {
    if (!await requireAccount(context) || !mounted) return;
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Create channel'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await sb.from('channels').insert({'name': name.text.trim(), 'description': desc.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waiting for approval')));
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Create')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No channels yet.', style: TextStyle(color: Tokens.muted)))])
                  : ListView(children: [
                      for (final r in _rows)
                        ListTile(
                          title: Text(r['name'] ?? ''),
                          subtitle: Text(r['review_status'] == 'pending' ? 'Waiting for approval' : '${r['members_count'] ?? 0} members', style: const TextStyle(color: Tokens.muted)),
                          trailing: r['review_status'] == 'pending'
                              ? null
                              : OutlinedButton(onPressed: () => _toggle(r['id'] as String), child: Text(_joined.contains(r['id']) ? 'Leave' : 'Join')),
                        ),
                    ]),
            ),
    );
  }
}
