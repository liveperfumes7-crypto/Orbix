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
  bool _opening = false, _trailer = false;

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
      if (!mounted) return;
      setState(() {
        _post = p;
        _items = List<Map<String, dynamic>>.from(items);
        if (p == null) _error = 'This post is not available.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this post.');
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
    // Organic visitors must log in before playing anything; ads visitors can watch free content and trailers as guests.
    if (app.status.isGuest && app.status.source == 'organic' && !app.status.isPremium) {
      if (!await requireAccount(context) || !mounted) return;
    }
    final premium = it['is_premium'] == true;
    final allowed = !premium || app.status.canPlayPremium;
    // Ads users who are not premium get the trailer; everyone else without access sees the lock.
    final key = (allowed ? it['media_key'] : it['trailer_key']) as String?;
    if (key == null) {
      _lockedMessage(app);
      return;
    }
    if (_opening) return;
    setState(() => _opening = true);
    final url = await _signed(key);
    if (!mounted) return;
    if (url == null) {
      setState(() => _opening = false);
      _lockedMessage(app);
      return;
    }
    final old = _vc;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      if (mounted) {
        setState(() => _opening = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play this video. Please try again.')));
      }
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    c.play();
    setState(() { _vc = c; _opening = false; _trailer = premium && !allowed; });
    await old?.dispose();
  }

  void _lockedMessage(AppState app) {
    if (!mounted) return;
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
    if (!await requireAccount(context) || _post == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sb.from('blocked_channels').upsert({'user_id': sb.auth.currentUser!.id, 'channel_id': _post!['channel_id']});
      messenger.showSnackBar(const SnackBar(content: Text('Channel blocked. You will not see its posts.')));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not block this channel. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    return Scaffold(
      appBar: AppBar(title: Text(p?['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis), actions: [
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
                  if (_vc != null && _vc!.value.isInitialized) ...[
                    _Player(controller: _vc!),
                    if (_trailer)
                      const Padding(padding: EdgeInsets.only(top: 6), child: Text('Trailer — go Premium to watch the full video', style: TextStyle(color: Tokens.gold, fontSize: 12))),
                    const SizedBox(height: 12),
                  ] else if (_opening)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
                  Text((p['title'] as String?) ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  if (((p['description'] as String?) ?? '').isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(p['description'] as String, style: const TextStyle(color: Tokens.muted, fontSize: 13))),
                  const SizedBox(height: 12),
                  if (_items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No media in this post yet.', style: TextStyle(color: Tokens.muted)))),
                  for (final it in _items)
                    Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                      leading: Icon((it['mime'] as String? ?? '').startsWith('video') ? Icons.play_circle_outline : Icons.image_outlined, color: Tokens.primary),
                      title: Text(it['is_premium'] == true ? 'Premium video' : 'Play video'),
                      trailing: it['is_premium'] == true && !AppScope.of(context).status.canPlayPremium
                          ? const Icon(Icons.lock, color: Tokens.gold, semanticLabel: 'Locked')
                          : null,
                      onTap: () => _play(it),
                    )),
                ]),
    );
  }
}

/// Video with tap-to-pause and a scrub bar.
class _Player extends StatelessWidget {
  const _Player({required this.controller});
  final VideoPlayerController controller;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, v, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => v.isPlaying ? controller.pause() : controller.play(),
              child: AspectRatio(
                aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(child: ColoredBox(color: Colors.black, child: VideoPlayer(controller))),
                  if (v.isBuffering) const CircularProgressIndicator(),
                  if (!v.isPlaying && !v.isBuffering)
                    Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.play_arrow_rounded, size: 40, color: Colors.white, semanticLabel: 'Play'),
                    ),
                ]),
              ),
            ),
            VideoProgressIndicator(controller, allowScrubbing: true, padding: EdgeInsets.zero, colors: const VideoProgressColors(playedColor: Tokens.primary, bufferedColor: Tokens.border, backgroundColor: Tokens.surface)),
          ]),
        ),
      );
}
