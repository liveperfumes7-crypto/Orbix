import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'post_page.dart';
import 'premium_screen.dart';

/// Shared post list used by Explore (all) and Feed (joined channels).
class PostList extends StatefulWidget {
  const PostList({super.key, this.joinedOnly = false, this.category});
  final bool joinedOnly;
  final String? category;
  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final _rows = <Map<String, dynamic>>[];
  bool _loading = true, _more = true;
  static const _page = 20;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(PostList old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) { _rows.clear(); _more = true; }
    setState(() => _loading = true);
    try {
      // Hidden / wrong-audience rows are never returned: that is enforced by RLS, not here.
      List<String>? joined;
      if (widget.joinedOnly) {
        final uid = sb.auth.currentUser?.id;
        final m = uid == null ? [] : await sb.from('channel_members').select('channel_id').eq('user_id', uid);
        joined = [for (final r in m) r['channel_id'] as String];
        if (joined.isEmpty) { _more = false; if (mounted) setState(() => _loading = false); return; }
      }
      var q = sb.from('posts').select('id,title,description,created_at,channel_id,channels(name,category),post_items(thumbnail_key,is_premium,duration_s)');
      if (widget.category != null) q = q.eq('channels.category', widget.category!);
      if (joined != null) q = q.inFilter('channel_id', joined);
      final data = await q.order('created_at', ascending: false).range(_rows.length, _rows.length + _page - 1);
      _rows.addAll(List<Map<String, dynamic>>.from(data));
      _more = data.length == _page;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return ListView.builder(itemCount: 5, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.all(12), child: _Skeleton()));
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _rows.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Nothing here yet.', style: TextStyle(color: Tokens.muted)))])
          : ListView.builder(
              itemCount: _rows.length + (_more ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _rows.length) { _load(); return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())); }
                final r = _rows[i];
                final ch = (r['channels'] as Map?)?['name'] ?? '';
                return ListTile(
                  title: Text(r['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(ch.toString(), style: const TextStyle(color: Tokens.muted)),
                  trailing: ((r['post_items'] as List?) ?? []).any((e) => e['is_premium'] == true)
                      ? const Icon(Icons.workspace_premium, color: Tokens.gold, semanticLabel: 'Premium')
                      : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostPage(postId: r['id'] as String))),
                );
              },
            ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Container(height: 64, decoration: BoxDecoration(color: Tokens.surface, borderRadius: BorderRadius.circular(12)));
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String? _cat;
  static const cats = ['Movies', 'Music', 'Education', 'Gaming', 'Lifestyle', 'Tech', 'Other'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: Tokens.primary, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Text('OB', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          const Expanded(child: Text('Orbix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          if (app.showPremiumEntry)
            IconButton(
              tooltip: 'Premium',
              icon: const Icon(Icons.workspace_premium, color: Tokens.gold),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())),
            ),
        ]),
      ),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final c in [null, ...cats])
            Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(label: Text(c ?? 'All'), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
            ),
        ]),
      ),
      Expanded(child: PostList(category: _cat)),
    ]);
  }
}
