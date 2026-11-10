import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared building blocks so every screen looks the same.

/// A friendly "nothing here" block: icon, title, one line of help and an optional button.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: Tokens.primary.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(icon, color: Tokens.primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: Tokens.muted, fontSize: 13, height: 1.4)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add, size: 18), label: Text(actionLabel!)),
          ],
        ]),
      );
}

/// The small grey bar at the top of a bottom sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) =>
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Tokens.border, borderRadius: BorderRadius.circular(2))));
}

/// Square avatar with the first letter of a name on the brand gradient.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 44});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: Tokens.gradient, borderRadius: BorderRadius.circular(size * .3)),
        child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .42)),
      );
}

/// A tappable row for choosing a file: icon, label, what is chosen, and a clear button.
class PickTile extends StatelessWidget {
  const PickTile({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.onClear, this.chosen = false, this.badge});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool chosen;
  final String? badge;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: Tokens.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: chosen ? Tokens.primary.withValues(alpha: .6) : Tokens.border),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Tokens.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: Icon(chosen ? Icons.check_rounded : icon, color: chosen ? Tokens.success : Tokens.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    if (badge != null)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: Tokens.border, borderRadius: BorderRadius.circular(8)),
                        child: Text(badge!, style: const TextStyle(color: Tokens.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tokens.muted, fontSize: 12)),
                ]),
              ),
              if (chosen && onClear != null)
                IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18, color: Tokens.muted), tooltip: 'Remove')
              else
                const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right_rounded, color: Tokens.muted)),
            ]),
          ),
        ),
      );
}

String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// 16:9 video card image: thumbnail (or a placeholder), duration chip and a Premium badge.
class VideoThumb extends StatelessWidget {
  const VideoThumb({super.key, this.url, this.seconds, this.premium = false, this.radius = 14});
  final String? url;
  final int? seconds;
  final bool premium;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1B1B30), Color(0xFF2A2145)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white38, size: 44)),
            ),
            if (url != null) Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            if (premium)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.workspace_premium, color: Tokens.gold, size: 14),
                    SizedBox(width: 4),
                    Text('Premium', style: TextStyle(color: Tokens.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            if (seconds != null && seconds! > 0)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .7), borderRadius: BorderRadius.circular(6)),
                  child: Text(fmtDuration(Duration(seconds: seconds!)), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      );
}
