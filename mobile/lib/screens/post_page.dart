import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';
import '../services/app_scope.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
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
  String? _error, _poster;
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
      final items = await sb.from('post_items').select('id,media_key,trailer_key,thumbnail_key,mime,is_premium,duration_s').eq('post_id', widget.postId).order('position');
      final tk = items.isEmpty ? null : items.first['thumbnail_key'] as String?;
      final poster = tk == null ? null : await _signed(tk);
      if (!mounted) return;
      setState(() {
        _poster = poster;
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
                    _Player(controller: _vc!, title: (p['title'] as String?) ?? ''),
                    if (_trailer)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Tokens.gold.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
                        child: const Row(children: [
                          Icon(Icons.workspace_premium, color: Tokens.gold, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('This is the trailer. Go Premium to watch the full video.', style: TextStyle(color: Tokens.gold, fontSize: 12))),
                        ]),
                      ),
                  ] else if (_items.isNotEmpty)
                    GestureDetector(
                      onTap: _opening ? null : () => _play(_items.first),
                      child: Stack(alignment: Alignment.center, children: [
                        VideoThumb(url: _poster, premium: _items.first['is_premium'] == true, seconds: _items.first['duration_s'] as int?),
                        if (_opening)
                          const CircularProgressIndicator()
                        else
                          Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(Icons.play_arrow_rounded, size: 42, color: Colors.white, semanticLabel: 'Play'),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  Text((p['title'] as String?) ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  if (((p['description'] as String?) ?? '').isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(p['description'] as String, style: const TextStyle(color: Tokens.muted, fontSize: 13, height: 1.4))),
                  const SizedBox(height: 14),
                  if (_items.isEmpty) const EmptyState(icon: Icons.hourglass_empty_rounded, title: 'No video yet', message: 'The creator has not added a video to this post.'),
                  if (_items.length > 1) ...[
                    const Text('In this post', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _items.length; i++)
                      Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                        leading: Icon((_items[i]['mime'] as String? ?? '').startsWith('video') ? Icons.play_circle_outline : Icons.image_outlined, color: Tokens.primary),
                        title: Text('Part ${i + 1}${_items[i]['is_premium'] == true ? ' · Premium' : ''}'),
                        trailing: _items[i]['is_premium'] == true && !AppScope.of(context).status.canPlayPremium
                            ? const Icon(Icons.lock, color: Tokens.gold, semanticLabel: 'Locked')
                            : null,
                        onTap: () => _play(_items[i]),
                      )),
                  ],
                ]),
    );
  }
}

/// Video player: tap to show or hide controls, play/pause, 10-second skips, scrub bar, times, speed and full screen.
class _Player extends StatefulWidget {
  const _Player({required this.controller, this.title = '', this.fullscreen = false});
  final VideoPlayerController controller;
  final String title;
  final bool fullscreen;
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  bool _show = true;
  Timer? _hide;
  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  VideoPlayerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _arm() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && c.value.isPlaying) setState(() => _show = false);
    });
  }

  void _toggleControls() {
    setState(() => _show = !_show);
    if (_show) _arm();
  }

  void _playPause() {
    c.value.isPlaying ? c.pause() : c.play();
    setState(() => _show = true);
    _arm();
  }

  Future<void> _skip(int seconds) async {
    final v = c.value;
    var t = v.position + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (t > v.duration) t = v.duration;
    await c.seekTo(t);
    _arm();
  }

  Future<void> _speed() async {
    final i = _speeds.indexOf(c.value.playbackSpeed);
    await c.setPlaybackSpeed(_speeds[(i + 1) % _speeds.length]);
    _arm();
  }

  Future<void> _fullscreen() async {
    if (widget.fullscreen) {
      Navigator.pop(context);
      return;
    }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _FullscreenPlayer(controller: c, title: widget.title)));
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Widget _btn(IconData icon, VoidCallback onTap, {double size = 26, String? label}) => IconButton(
        onPressed: onTap,
        tooltip: label,
        iconSize: size,
        color: Colors.white,
        icon: Icon(icon, semanticLabel: label),
      );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (context, v, _) {
          final ended = v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying;
          final controls = Stack(fit: StackFit.expand, children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.black87], stops: const [0, .45, 1]))),
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _btn(Icons.replay_10_rounded, () => _skip(-10), size: 34, label: 'Back 10 seconds'),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: _btn(ended ? Icons.replay_rounded : (v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded), ended ? () { c.seekTo(Duration.zero); c.play(); } : _playPause, size: 44, label: v.isPlaying ? 'Pause' : 'Play'),
                ),
                const SizedBox(width: 12),
                _btn(Icons.forward_10_rounded, () => _skip(10), size: 34, label: 'Forward 10 seconds'),
              ]),
            ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 0,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const SizedBox(width: 8),
                  Text('${fmtDuration(v.position)} / ${fmtDuration(v.duration)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton(
                    onPressed: _speed,
                    style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(44, 32), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: Text('${v.playbackSpeed == v.playbackSpeed.roundToDouble() ? v.playbackSpeed.toInt() : v.playbackSpeed}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  _btn(widget.fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, _fullscreen, size: 24, label: 'Full screen'),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 6), colors: const VideoProgressColors(playedColor: Tokens.primary, bufferedColor: Colors.white24, backgroundColor: Colors.white12)),
                ),
              ]),
            ),
          ]);
          final surface = GestureDetector(
            onTap: _toggleControls,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(fit: StackFit.expand, children: [
                Center(child: AspectRatio(aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio, child: VideoPlayer(c))),
                if (v.isBuffering) const Center(child: CircularProgressIndicator()),
                AnimatedOpacity(
                  opacity: _show || !v.isPlaying ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(ignoring: !(_show || !v.isPlaying), child: controls),
                ),
              ]),
            ),
          );
          if (widget.fullscreen) return surface;
          // Inline: 16:9 box for landscape clips, taller (up to 70% of the width) for portrait clips.
          final double ratio = v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio.clamp(0.7, 2.4).toDouble();
          return ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: ratio < 1.2 ? 1.2 : ratio, child: surface));
        },
      );
}

class _FullscreenPlayer extends StatelessWidget {
  const _FullscreenPlayer({required this.controller, required this.title});
  final VideoPlayerController controller;
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(top: false, bottom: false, child: SizedBox.expand(child: _Player(controller: controller, title: title, fullscreen: true))),
      );
}
