import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The romantic hero on Home: couple's names, wedding date, and countdown,
/// dressed as a small invitation rather than a plain stat card -- a blush/
/// wine gradient ground, a hand-drawn floral-heart flourish, and a serif
/// display face for the names and countdown digits.
class WeddingHeroCard extends StatelessWidget {
  final String brideName;
  final String groomName;
  final bool isOwner;
  final DateTime? weddingDate;
  final VoidCallback onEditNames;
  final VoidCallback onEditDate;

  const WeddingHeroCard({
    super.key,
    required this.brideName,
    required this.groomName,
    required this.isOwner,
    required this.weddingDate,
    required this.onEditNames,
    required this.onEditDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDate = weddingDate != null;
    final now = DateTime.now();
    final diff = hasDate ? weddingDate!.difference(now) : Duration.zero;
    final isPast = diff.isNegative;
    final absDiff = diff.abs();
    final days = absDiff.inDays;
    final hours = absDiff.inHours % 24;
    final minutes = absDiff.inMinutes % 60;
    final seconds = absDiff.inSeconds % 60;

    final blush = isDark ? const Color(0xFF2A1420) : const Color(0xFFFDF2F5);
    final wine = isDark ? const Color(0xFF190B12) : const Color(0xFFFBE3E9);
    final gold = isDark ? const Color(0xFFE3B77D) : const Color(0xFFB6743F);
    final ink = isDark ? const Color(0xFFF3E4E9) : const Color(0xFF3A2230);
    final inkSoft = ink.withValues(alpha: 0.68);

    final displayFace = GoogleFonts.playfairDisplay(color: ink);
    final hasNames = brideName.isNotEmpty || groomName.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [blush, wine],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : gold).withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(painter: _SprigCornerPainter(color: gold.withValues(alpha: isDark ? 0.22 : 0.28))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
            child: Column(
              children: [
                GestureDetector(
                  onTap: isOwner ? onEditNames : null,
                  child: hasNames
                      ? RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: displayFace.copyWith(fontSize: 30, fontWeight: FontWeight.w600, height: 1.15),
                            children: [
                              TextSpan(text: brideName.isEmpty ? '?' : brideName),
                              TextSpan(
                                text: '  &  ',
                                style: displayFace.copyWith(
                                  fontSize: 22,
                                  fontStyle: FontStyle.italic,
                                  color: gold,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(text: groomName.isEmpty ? '?' : groomName),
                            ],
                          ),
                        )
                      : Text(
                          isOwner ? 'Tap to name your day' : 'Names not set yet',
                          textAlign: TextAlign.center,
                          style: displayFace.copyWith(fontSize: 22, fontStyle: FontStyle.italic, color: inkSoft),
                        ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 96,
                  height: 20,
                  child: CustomPaint(painter: _HeartDividerPainter(color: gold)),
                ),
                const SizedBox(height: 14),
                if (hasDate)
                  GestureDetector(
                    onTap: isOwner ? onEditDate : null,
                    child: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(weddingDate!),
                      style: TextStyle(
                        color: inkSoft,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  )
                else if (isOwner)
                  TextButton(
                    onPressed: onEditDate,
                    style: TextButton.styleFrom(foregroundColor: gold),
                    child: const Text('Set your wedding date'),
                  ),
                if (hasDate) ...[
                  const SizedBox(height: 22),
                  Text(
                    (isPast ? 'MARRIED FOR' : 'COUNTING DOWN').toUpperCase(),
                    style: TextStyle(
                      color: inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TimeUnit(value: days, label: 'Days', ink: ink, gold: gold, displayFace: displayFace),
                      _Dot(color: gold),
                      _TimeUnit(value: hours, label: 'Hrs', ink: ink, gold: gold, displayFace: displayFace),
                      _Dot(color: gold),
                      _TimeUnit(value: minutes, label: 'Min', ink: ink, gold: gold, displayFace: displayFace),
                      _Dot(color: gold),
                      _TimeUnit(value: seconds, label: 'Sec', ink: ink, gold: gold, displayFace: displayFace),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;
  final Color ink;
  final Color gold;
  final TextStyle displayFace;

  const _TimeUnit({
    required this.value,
    required this.label,
    required this.ink,
    required this.gold,
    required this.displayFace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: displayFace.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.55), shape: BoxShape.circle),
      ),
    );
  }
}

/// A single small flourish: two overlapping heart lobes joined by a thin
/// stem, standing in for a wax-seal motif between the names and the date.
class _HeartDividerPainter extends CustomPainter {
  final Color color;
  const _HeartDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width / 2 - 10, midY), linePaint);
    canvas.drawLine(Offset(size.width / 2 + 10, midY), Offset(size.width, midY), linePaint);

    final heartPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final path = Path();
    const r = 4.2;
    path.moveTo(cx, midY + r * 1.1);
    path.cubicTo(cx - r * 1.6, midY - r * 0.6, cx - r * 0.6, midY - r * 1.7, cx, midY - r * 0.5);
    path.cubicTo(cx + r * 0.6, midY - r * 1.7, cx + r * 1.6, midY - r * 0.6, cx, midY + r * 1.1);
    path.close();
    canvas.drawPath(path, heartPaint);
  }

  @override
  bool shouldRepaint(covariant _HeartDividerPainter oldDelegate) => oldDelegate.color != color;
}

/// Faint sprig flourishes tucked into the top-left and bottom-right corners
/// of the hero card, echoing hand-drawn botanical line art on an invitation
/// without importing any image assets.
class _SprigCornerPainter extends CustomPainter {
  final Color color;
  const _SprigCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    _drawSprig(canvas, paint, Offset(6, 6), math.pi * 0.68, 46);
    canvas.save();
    canvas.translate(size.width, size.height);
    canvas.rotate(math.pi);
    _drawSprig(canvas, paint, const Offset(6, 6), math.pi * 0.68, 46);
    canvas.restore();
  }

  void _drawSprig(Canvas canvas, Paint paint, Offset origin, double angle, double length) {
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    final tip = origin + Offset(dx, dy) * length;
    canvas.drawLine(origin, tip, paint);
    for (var i = 1; i <= 3; i++) {
      final t = i / 4;
      final base = Offset(origin.dx + (tip.dx - origin.dx) * t, origin.dy + (tip.dy - origin.dy) * t);
      final leafAngle = angle - math.pi / 2.4;
      final leafAngle2 = angle + math.pi / 2.4;
      canvas.drawLine(base, base + Offset(math.cos(leafAngle), math.sin(leafAngle)) * 9, paint);
      canvas.drawLine(base, base + Offset(math.cos(leafAngle2), math.sin(leafAngle2)) * 9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SprigCornerPainter oldDelegate) => oldDelegate.color != color;
}
