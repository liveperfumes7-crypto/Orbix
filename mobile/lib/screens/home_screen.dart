import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'post_page.dart';

/// Home: channels row + latest posts grid. Hidden / wrong-audience rows never come back (RLS).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSearch, this.onProfile, this.onSeeAllChannels});
  final VoidCallback? onSearch, onProfile, onSeeAllChannels;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _posts = [];
  final Map<String, String> _thumbs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await sb.from('channels').select('id,name').order('created_at', ascending: false).limit(10);
      _channels = List<Map<String, dynamic>>.from(c);
      final p = await sb.from('posts').select('id,title,post_items(thumbnail_key,position)').order('created_at', ascending: false).limit(12);
      _posts = List<Map<String, dynamic>>.from(p);
      final keys = <String>[
        for (final r in _posts)
          for (final it in ((r['post_items'] as List?) ?? const []))
            if ((it as Map)['thumbnail_key'] != null) it['thumbnail_key'] as String,
      ];
      if (keys.isNotEmpty) {
        try {
          final res = await sb.storage.from('media').createSignedUrls(keys, 3600);
          for (final r in res) {
            final String? path = r.path;
            if (path != null) _thumbs[path] = r.signedUrl;
          }
        } catch (_) {/* thumbnails are optional */}
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String? _thumbFor(Map<String, dynamic> post) {
    for (final it in ((post['post_items'] as List?) ?? const [])) {
      final k = (it as Map)['thumbnail_key'] as String?;
      if (k != null && _thumbs[k] != null) return _thumbs[k];
    }
    return null;
  }

  String _initial(AppState app) {
    String? mail;
    try {
      mail = sb.auth.currentUser?.email;
    } catch (_) {}
    return (mail != null && mail.isNotEmpty ? mail[0] : (app.status.isGuest ? 'G' : 'U')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Row(children: [
          const Expanded(child: Text('Home', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
          _SquareButton(key: const Key('home_search'), onTap: widget.onSearch, child: const Icon(Icons.search)),
          const SizedBox(width: 10),
          _SquareButton(key: const Key('home_avatar'), onTap: widget.onProfile, child: Text(_initial(app), style: const TextStyle(color: Tokens.primary, fontWeight: FontWeight.w700, fontSize: 18))),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(child: Text('Channels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
          TextButton(onPressed: widget.onSeeAllChannels, child: const Text('See all', style: TextStyle(color: Tokens.accent))),
        ]),
        SizedBox(
          height: 108,
          child: _channels.isEmpty
              ? Center(child: Text(_loading ? '' : 'No channels yet', style: const TextStyle(color: Tokens.muted)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _channels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final name = (_channels[i]['name'] as String?) ?? '';
                    return GestureDetector(
                      onTap: widget.onSeeAllChannels,
                      child: SizedBox(width: 76, child: Column(children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(color: Tokens.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Tokens.border)),
                          alignment: Alignment.center,
                          child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Tokens.primary)),
                        ),
                        const SizedBox(height: 6),
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tokens.muted, fontSize: 12)),
                      ])),
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),
        const Text('New shows', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (_posts.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nothing here yet.', style: TextStyle(color: Tokens.muted))))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 14, childAspectRatio: .58),
            itemBuilder: (_, i) {
              final r = _posts[i];
              final url = _thumbFor(r);
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostPage(postId: r['id'] as String))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox.expand(
                        child: url == null
                            ? Container(decoration: const BoxDecoration(gradient: Tokens.gradient), alignment: Alignment.center, child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white70))
                            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Tokens.surface)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text((r['title'] as String?) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tokens.muted, fontWeight: FontWeight.w500)),
                ]),
              );
            },
          ),
      ]),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(width: 52, height: 52, decoration: BoxDecoration(color: Tokens.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Tokens.border)), alignment: Alignment.center, child: child),
      );
}
