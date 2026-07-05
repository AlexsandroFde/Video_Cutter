import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/cutter_colors.dart';
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

  /// Altura total do widget, incluindo a folga para as alças e o coração.
  static const double height = 92;

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
    final cutter = Theme.of(context).extension<CutterColors>()!;

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
              } else {
                HapticFeedback.selectionClick();
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
                colors: cutter,
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
    required this.colors,
  });

  final List<VideoSegment> segments;
  final Duration duration;

  /// Posição do cursor de reprodução, de 0 a 1.
  final double playhead;

  final int? activeBoundary;
  final CutterColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration == Duration.zero || segments.isEmpty) return;

    final track = Rect.fromLTWH(0, 18, size.width, size.height - 32);
    final trackRRect =
        RRect.fromRectAndRadius(track, const Radius.circular(12));

    canvas.save();
    canvas.clipRRect(trackRRect);
    canvas.drawRect(track, Paint()..color = colors.timelineTrack);

    for (final (index, segment) in segments.indexed) {
      final rect = Rect.fromLTRB(
        _x(segment.start, size.width),
        track.top,
        _x(segment.end, size.width),
        track.bottom,
      );
      final fill = segment.enabled
          ? colors.segmentColor(index)
          : colors.segmentDisabled;
      canvas.drawRect(rect, Paint()..color = fill);

      if (rect.width > 26) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${index + 1}',
            style: TextStyle(
              color: segment.enabled
                  ? colors.segmentInk
                  : colors.boundaryHandle,
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
        ..color = colors.boundaryHandle
        ..strokeWidth = active ? 4 : 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, track.top - 4),
        Offset(x, track.bottom + 4),
        paint,
      );
      canvas.drawCircle(
        Offset(x, track.bottom + 7),
        active ? 7 : 5,
        Paint()..color = paint.color,
      );
    }

    // Cursor de reprodução, com um coraçãozinho como marcador.
    final px = (playhead * size.width).clamp(1.0, size.width - 1.0);
    final playheadPaint = Paint()
      ..color = colors.playhead
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(px, 10),
      Offset(px, size.height - 2),
      playheadPaint,
    );
    canvas.drawPath(
      _heart(Offset(px, 5), 6.5),
      Paint()..color = colors.playhead,
    );
  }

  /// Coração centrado em [center]; [s] controla o tamanho.
  Path _heart(Offset center, double s) {
    final x = center.dx;
    final y = center.dy - s * 0.4;
    return Path()
      ..moveTo(x, y + s * 0.35)
      ..cubicTo(x - s * 0.6, y - s * 0.35, x - s * 1.1, y + s * 0.35, x, y + s)
      ..cubicTo(x + s * 1.1, y + s * 0.35, x + s * 0.6, y - s * 0.35, x,
          y + s * 0.35)
      ..close();
  }

  double _x(Duration position, double width) =>
      width * position.inMilliseconds / duration.inMilliseconds;

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.duration != duration ||
      oldDelegate.playhead != playhead ||
      oldDelegate.activeBoundary != activeBoundary ||
      oldDelegate.colors != colors;
}
