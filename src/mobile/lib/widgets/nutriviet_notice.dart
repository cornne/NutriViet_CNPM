import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

enum NutriVietNoticeTone { success, error, warning, info }

/// Displays a refined, floating frosted-pill toast notification instead of
/// Material's boxy edge-to-edge solid green/red SnackBar rectangle.
void showNutriVietNotice(
  BuildContext context,
  String message, {
  NutriVietNoticeTone tone = NutriVietNoticeTone.success,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final style = _NoticeStyle.fromTone(tone);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      duration: duration,
      dismissDirection: DismissDirection.horizontal,
      content: _NutriVietNoticeCard(
        message: message,
        style: style,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                messenger.hideCurrentSnackBar();
                onAction();
              },
      ),
    ),
  );
}

class _NoticeStyle {
  final Color accent;
  final Color badgeBg;
  final Color borderColor;
  final Color tintBg;
  final IconData icon;

  const _NoticeStyle({
    required this.accent,
    required this.badgeBg,
    required this.borderColor,
    required this.tintBg,
    required this.icon,
  });

  factory _NoticeStyle.fromTone(NutriVietNoticeTone tone) {
    switch (tone) {
      case NutriVietNoticeTone.success:
        return const _NoticeStyle(
          accent: Color(0xFF14803C),
          badgeBg: Color(0xFFE6F6EC),
          borderColor: Color(0x4D14803C),
          tintBg: Color(0xF6FFFFFF),
          icon: PhosphorIconsFill.checkCircle,
        );
      case NutriVietNoticeTone.error:
        return const _NoticeStyle(
          accent: Color(0xFFDC2626),
          badgeBg: Color(0xFFFEECEC),
          borderColor: Color(0x4DDC2626),
          tintBg: Color(0xF7FFFDFD),
          icon: PhosphorIconsFill.xCircle,
        );
      case NutriVietNoticeTone.warning:
        return const _NoticeStyle(
          accent: Color(0xFFD97706),
          badgeBg: Color(0xFFFEF4E2),
          borderColor: Color(0x52D97706),
          tintBg: Color(0xF7FFFEFA),
          icon: PhosphorIconsFill.warningCircle,
        );
      case NutriVietNoticeTone.info:
        return const _NoticeStyle(
          accent: Color(0xFF4F37C8),
          badgeBg: Color(0xFFEEEBFC),
          borderColor: Color(0x474F37C8),
          tintBg: Color(0xF6FFFFFF),
          icon: PhosphorIconsFill.info,
        );
    }
  }
}

class _NutriVietNoticeCard extends StatelessWidget {
  final String message;
  final _NoticeStyle style;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _NutriVietNoticeCard({
    required this.message,
    required this.style,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.11),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: style.accent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: style.tintBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: style.borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: style.badgeBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: PhosphorIcon(
                  style.icon,
                  color: style.accent,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.36,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: style.badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      color: style.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

