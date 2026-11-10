import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/app_state.dart';
import '../theme.dart';
import 'explore_screen.dart';
import 'login_sheet.dart';

/// One channel: details, join/leave, its posts. The channel's creator can add posts once it is approved.
class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key, required this.channelId, this.name = ''});
  final String channelId;
  final String name;
  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  Map<String, dynamic>? _ch;
  bool _joined = false, _loading = true, _busy = false;
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await sb.from('channels').select('id,name,description,members_count,review_status,created_by').eq('id', widget.channelId).maybeSingle();
      final uid = sb.auth.currentUser?.id;
      var joined = false;
      if (uid != null && c != null) {
        final m = await sb.from('channel_members').select('channel_id').eq('channel_id', widget.channelId).eq('user_id', uid);
        joined = m.isNotEmpty;
      }
      _ch = c;
      _joined = joined;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool get _mine => _ch != null && _ch!['created_by'] != null && _ch!['created_by'] == sb.auth.currentUser?.id;
  bool get _approved => _ch?['review_status'] == 'approved';

  Future<void> _toggle() async {
    if (_busy || !await requireAccount(context) || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final uid = sb.auth.currentUser!.id;
      if (_joined) {
        await sb.from('channel_members').delete().eq('channel_id', widget.channelId).eq('user_id', uid);
      } else {
        await sb.from('channel_members').insert({'channel_id': widget.channelId, 'user_id': uid});
      }
      await _load();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not update. Please try again.')));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _newPost() async {
    final done = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NewPostScreen(channelId: widget.channelId)));
    if (done == true && mounted) setState(() => _rev++);
  }

  @override
  Widget build(BuildContext context) {
    final c = _ch;
    final name = (c?['name'] as String?) ?? widget.name;
    return Scaffold(
      appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      floatingActionButton: _mine && _approved ? FloatingActionButton.extended(key: const Key('new_post'), onPressed: _newPost, icon: const Icon(Icons.add), label: const Text('New post')) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : c == null
              ? const Center(child: Text('This channel is not available.', style: TextStyle(color: Tokens.muted)))
              : Column(children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Tokens.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Tokens.border)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: Tokens.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Tokens.primary, fontWeight: FontWeight.w700, fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(_approved ? '${c['members_count'] ?? 0} members' : (c['review_status'] == 'rejected' ? 'Not approved' : 'Waiting for approval'), style: const TextStyle(color: Tokens.muted, fontSize: 12)),
                          if (((c['description'] as String?) ?? '').isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(c['description'] as String, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tokens.muted, fontSize: 13))),
                        ]),
                      ),
                      if (_approved && !_mine)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 14)),
                          onPressed: _busy ? null : _toggle,
                          child: Text(_joined ? 'Leave' : 'Join'),
                        ),
                    ]),
                  ),
                  if (_mine && !_approved)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('You can add posts after this channel is approved.', style: TextStyle(color: Tokens.muted, fontSize: 13)),
                    ),
                  Expanded(child: PostList(key: ValueKey(_rev), channelId: widget.channelId)),
                ]),
    );
  }
}

String _mimeOf(String ext) => const {
      'mp4': 'video/mp4', 'm4v': 'video/mp4', 'mov': 'video/quicktime', 'mkv': 'video/x-matroska', 'webm': 'video/webm',
      '3gp': 'video/3gpp', 'avi': 'video/x-msvideo',
    }[ext] ?? 'video/mp4';

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, required this.channelId});
  final String channelId;
  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  PlatformFile? _file;
  bool _premium = false, _busy = false;
  String? _err;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.video, withData: false);
      final f = r?.files.single;
      if (f != null && f.path != null && mounted) setState(() { _file = f; _err = null; });
    } catch (_) {
      if (mounted) setState(() => _err = 'Could not open the file picker.');
    }
  }

  Future<void> _publish() async {
    final f = _file;
    if (_title.text.trim().isEmpty) return setState(() => _err = 'Add a title.');
    if (f == null || f.path == null) return setState(() => _err = 'Choose a video.');
    setState(() { _busy = true; _err = null; });
    final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'mp4';
    final key = '${widget.channelId}/${const Uuid().v4()}.$ext';
    var uploaded = false;
    try {
      await sb.rpc('accept_consent', params: {'p_policy': 'v1'});
      await sb.storage.from('media').upload(key, File(f.path!), fileOptions: FileOptions(contentType: _mimeOf(ext)));
      uploaded = true;
      final post = await sb.from('posts').insert({
        'channel_id': widget.channelId,
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'status': 'published',
      }).select('id').single();
      try {
        await sb.from('post_items').insert({'post_id': post['id'], 'media_key': key, 'mime': _mimeOf(ext), 'is_premium': _premium, 'size_bytes': f.size});
      } catch (_) {
        await sb.from('posts').delete().eq('id', post['id'] as String);
        rethrow;
      }
      if (mounted) Navigator.pop(context, true);
      return;
    } on StorageException catch (e) {
      _err = e.statusCode == '413' || e.message.toLowerCase().contains('size') ? 'This video is too large to upload.' : 'Upload failed. Please try again.';
    } on PostgrestException catch (e) {
      _err = e.message;
    } catch (_) {
      _err = 'Could not publish. Check your connection and try again.';
    }
    if (uploaded) {
      try { await sb.storage.from('media').remove([key]); } catch (_) {}
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(key: const Key('post_title'), controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 4),
        TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.video_library_outlined),
          label: Text(f == null ? 'Choose video' : '${f.name} · ${(f.size / (1 << 20)).toStringAsFixed(1)} MB', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _premium,
          onChanged: _busy ? null : (v) => setState(() => _premium = v),
          title: const Text('Premium video'),
          subtitle: const Text('Only members with a plan can watch', style: TextStyle(color: Tokens.muted, fontSize: 12)),
        ),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_err!, style: const TextStyle(color: Tokens.danger, fontSize: 13))),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        const SizedBox(height: 16),
        GradientButton(label: _busy ? 'Uploading…' : 'Publish', onPressed: _busy ? null : _publish),
        const SizedBox(height: 10),
        const Text('Posts must follow the Community Guidelines. Content that breaks them is removed.', textAlign: TextAlign.center, style: TextStyle(color: Tokens.muted, fontSize: 12)),
      ]),
    );
  }
}
