import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/video_segment.dart';
import '../controllers/segments_controller.dart';
import '../providers.dart';

/// Barra de segmentação do vídeo.
///
/// - Toque ou arraste em área livre: move o cursor de reprodução (scrub).
/// - Arraste sobre uma fronteira: reposiciona o corte.
class TimelineEditor extends ConsumerStatefulWidget {
  const TimelineEditor({super.key, required this.player});

  final VideoPlayerController player;

  /// Altura total do widget, incluindo a folga para as alças.
  static const double height = 88;

  @override
  ConsumerState<TimelineEditor> createState() => _TimelineEditorState();
}

class _TimelineEditorState extends ConsumerState<TimelineEditor> {
  /// Distância máxima (px) para "agarrar" uma fronteira ao arrastar.
  static const _grabRadius = 18.0;

  int? _dragBoundary;

  @override
  Widget build(BuildContext context) {
    final segmentsState = ref.watch(segmentsControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.player,
        builder: (context, value, _) {
          final totalMs = segmentsState.duration.inMilliseconds;
          final playhead = totalMs == 0
              ? 0.0
              : (value.position.inMilliseconds / totalMs).clamp(0.0, 1.0);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final dx = details.localPosition.dx;
              if (_hitBoundary(dx, width, segmentsState) == null) {
                widget.player.seekTo(_positionAt(dx, width, segmentsState));
              }
            },
            onHorizontalDragStart: (details) {
              final dx = details.localPosition.dx;
              final hit = _hitBoundary(dx, width, segmentsState);
              setState(() => _dragBoundary = hit);
              if (hit == null) {
                widget.player.seekTo(_positionAt(dx, width, segmentsState));
              }
            },
            onHorizontalDragUpdate: (details) {
              final position =
                  _positionAt(details.localPosition.dx, width, segmentsState);
              final boundary = _dragBoundary;
              if (boundary != null) {
                ref
                    .read(segmentsControllerProvider.notifier)
                    .moveBoundary(boundary, position);
              } else {
                widget.player.seekTo(position);
              }
            },
            onHorizontalDragEnd: (_) => setState(() => _dragBoundary = null),
            onHorizontalDragCancel: () =>
                setState(() => _dragBoundary = null),
            child: CustomPaint(
              size: Size(width, TimelineEditor.height),
              painter: _TimelinePainter(
                segments: segmentsState.segments,
                duration: segmentsState.duration,
                playhead: playhead,
                activeBoundary: _dragBoundary,
                scheme: scheme,
              ),
            ),
          );
        },
      );
    });
  }

  /// Índice da fronteira mais próxima de [dx], ou `null` se nenhuma estiver
  /// ao alcance de [_grabRadius].
  int? _hitBoundary(double dx, double width, SegmentsState state) {
    final totalMs = state.duration.inMilliseconds;
    if (totalMs == 0) return null;

    int? nearest;
    var nearestDistance = _grabRadius;
    for (var i = 0; i < state.segments.length - 1; i++) {
      final x = width * state.segments[i].end.inMilliseconds / totalMs;
      final distance = (dx - x).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = i;
      }
    }
    return nearest;
  }

  Duration _positionAt(double dx, double width, SegmentsState state) {
    final fraction = width == 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);
    return Duration(
      milliseconds: (state.duration.inMilliseconds * fraction).round(),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.segments,
    required this.duration,
    required this.playhead,
    required this.activeBoundary,
    required this.scheme,
  });

  final List<VideoSegment> segments;
  final Duration duration;

  /// Posição do cursor de reprodução, de 0 a 1.
  final double playhead;

  final int? activeBoundary;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration == Duration.zero || segments.isEmpty) return;

    final track = Rect.fromLTWH(0, 14, size.width, size.height - 28);
    final trackRRect = RRect.fromRectAndRadius(track, const Radius.circular(10));

    canvas.save();
    canvas.clipRRect(trackRRect);
    canvas.drawRect(track, Paint()..color = scheme.surfaceContainerHighest);

    for (final (index, segment) in segments.indexed) {
      final rect = Rect.fromLTRB(
        _x(segment.start, size.width),
        track.top,
        _x(segment.end, size.width),
        track.bottom,
      );
      final color = !segment.enabled
          ? scheme.onSurface.withValues(alpha: 0.10)
          : (index.isEven ? scheme.primary : scheme.tertiary)
              .withValues(alpha: 0.80);
      canvas.drawRect(rect, Paint()..color = color);

      if (rect.width > 26) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${index + 1}',
            style: TextStyle(
              color: segment.enabled
                  ? scheme.onPrimary
                  : scheme.onSurface.withValues(alpha: 0.45),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
    canvas.restore();

    // Alças das fronteiras entre segmentos.
    for (var i = 0; i < segments.length - 1; i++) {
      final x = _x(segments[i].end, size.width);
      final active = i == activeBoundary;
      final paint = Paint()
        ..color = active ? Colors.white : scheme.onSurface.withValues(alpha: 0.85)
        ..strokeWidth = active ? 4 : 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, track.top - 5),
        Offset(x, track.bottom + 5),
        paint,
      );
      canvas.drawCircle(
        Offset(x, track.bottom + 7),
        active ? 7 : 5,
        Paint()..color = paint.color,
      );
    }

    // Cursor de reprodução.
    final px = (playhead * size.width).clamp(1.0, size.width - 1.0);
    final playheadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(Offset(px, 2), Offset(px, size.height - 2), playheadPaint);
    final marker = Path()
      ..moveTo(px - 5, 0)
      ..lineTo(px + 5, 0)
      ..lineTo(px, 8)
      ..close();
    canvas.drawPath(marker, Paint()..color = Colors.white);
  }

  double _x(Duration position, double width) =>
      width * position.inMilliseconds / duration.inMilliseconds;

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.duration != duration ||
      oldDelegate.playhead != playhead ||
      oldDelegate.activeBoundary != activeBoundary;
}
