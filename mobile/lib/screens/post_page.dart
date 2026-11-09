import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';
import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'login_sheet.dart';

const reportReasons = ['Sexual/nude', 'Violence', 'Hate/harassment', 'Copyright', 'Spam/scam', 'Other'];

class PostPage extends StatefulWidget {
  const PostPage({super.key, required this.postId});
  final String postId;
  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _items = [];
  VideoPlayerController? _vc;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await sb.from('posts').select('id,title,description,channel_id').eq('id', widget.postId).maybeSingle();
      final items = await sb.from('post_items').select('id,media_key,trailer_key,mime,is_premium,duration_s').eq('post_id', widget.postId).order('position');
      setState(() { _post = p; _items = List<Map<String, dynamic>>.from(items); });
    } catch (_) {
      setState(() => _error = 'Could not load this post.');
    }
  }

  /// Signed URL, short-lived. The storage policy decides whether the full file is allowed.
  Future<String?> _signed(String key) async {
    try {
      return await sb.storage.from('media').createSignedUrl(key, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> _play(Map<String, dynamic> it) async {
    final app = AppScope.of(context);
    final premium = it['is_premium'] == true;
    final allowed = !premium || app.status.canPlayPremium;
    // Ads users who are not premium get the trailer; everyone else without access sees the lock.
    final key = (allowed ? it['media_key'] : it['trailer_key']) as String?;
    if (key == null) {
      _lockedMessage(app);
      return;
    }
    final url = await _signed(key);
    if (url == null) { _lockedMessage(app); return; }
    _vc?.dispose();
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    await c.initialize();
    final pos = await _savedPosition(key);
    if (pos != null) await c.seekTo(pos);
    c.play();
    setState(() => _vc = c);
  }

  Future<Duration?> _savedPosition(String key) async => null; // resume position stored per user in a follow-up

  void _lockedMessage(AppState app) {
    final msg = app.showPrices ? 'Premium video — go Premium to watch the full version' : 'For Premium members';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _report() async {
    if (!await requireAccount(context) || !mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Report'), children: [
        for (final r in reportReasons) SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r)),
      ]),
    );
    if (reason == null) return;
    try {
      await sb.rpc('report_content', params: {'p_target_type': 'post', 'p_target_id': widget.postId, 'p_reason': reason, 'p_details': ''});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks, we will review it.')));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _block() async {
    if (!await requireAccount(context) || _post == null) return;
    await sb.from('blocked_channels').insert({'user_id': sb.auth.currentUser!.id, 'channel_id': _post!['channel_id']});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    return Scaffold(
      appBar: AppBar(title: Text(p?['title'] ?? ''), actions: [
        IconButton(tooltip: 'Share', icon: const Icon(Icons.share), onPressed: () => Share.share('${Config.websiteUrl}/p/${widget.postId}')),
        PopupMenuButton<String>(
          onSelected: (v) => v == 'report' ? _report() : _block(),
          itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report')), PopupMenuItem(value: 'block', child: Text('Block channel'))],
        ),
      ]),
      body: _error != null
          ? Center(child: Text(_error!))
          : p == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (_vc != null && _vc!.value.isInitialized) AspectRatio(aspectRatio: _vc!.value.aspectRatio, child: VideoPlayer(_vc!)),
                  Text(p['description'] ?? '', style: const TextStyle(color: Tokens.muted)),
                  const SizedBox(height: 12),
                  for (final it in _items)
                    Card(child: ListTile(
                      leading: Icon((it['mime'] as String? ?? '').startsWith('video') ? Icons.play_circle : Icons.image),
                      title: Text(it['is_premium'] == true ? 'Premium video' : 'Media'),
                      trailing: it['is_premium'] == true && !AppScope.of(context).status.canPlayPremium
                          ? const Icon(Icons.lock, color: Tokens.gold, semanticLabel: 'Locked')
                          : null,
                      onTap: () => _play(it),
                    )),
                ]),
    );
  }
}
