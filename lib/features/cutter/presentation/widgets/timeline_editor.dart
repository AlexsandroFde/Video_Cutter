import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/cutter_colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/utils/duration_format.dart';
import '../../domain/entities/video_segment.dart';
import '../controllers/segments_controller.dart';
import '../providers.dart';

/// Barra de segmentação do vídeo, com régua de tempo e zoom.
///
/// - Toque ou arraste em área livre: move o cursor de reprodução (scrub).
/// - Arraste sobre uma fronteira: reposiciona o corte.
/// - Pinça com dois dedos (ou os botões de lupa): zoom para ajustes finos.
class TimelineEditor extends ConsumerStatefulWidget {
  const TimelineEditor({
    super.key,
    required this.player,
    this.focusedSegmentId,
    this.onClearFocus,
  });

  final VideoPlayerController player;

  /// Corte mantido em foco na reprodução (destacado na trilha), se houver.
  final int? focusedSegmentId;

  /// Chamado quando o usuário remove o foco pelo chip acima da trilha.
  final VoidCallback? onClearFocus;

  /// Altura da trilha, incluindo régua, folga para as alças e o coração.
  static const double height = 110;

  @override
  ConsumerState<TimelineEditor> createState() => _TimelineEditorState();
}

class _TimelineEditorState extends ConsumerState<TimelineEditor> {
  /// Distância máxima (px) para "agarrar" uma fronteira ao arrastar.
  static const _grabRadius = 18.0;

  /// Fator aplicado a cada toque nos botões de zoom.
  static const _zoomStep = 1.6;

  /// Densidade máxima do zoom, em px por segundo de vídeo. Mais que isso
  /// não ajuda: cada parte tem no mínimo 0,5 s.
  static const _maxPxPerSecond = 240.0;

  int? _dragBoundary;

  double _zoom = 1;

  /// Deslocamento (px) da janela visível sobre a trilha ampliada.
  double _scroll = 0;

  bool _pinching = false;
  double _pinchBaseZoom = 1;
  double _pinchBaseFraction = 0;

  /// Dedos encostados na trilha agora (via [Listener]); diferencia o fim
  /// real de uma pinça de apenas um dedo levantado.
  int _activePointers = 0;

  /// Depois de uma pinça, o dedo que sobrou desloca a trilha em vez de
  /// fazer scrub — evita pulos acidentais do cursor ao soltar os dedos.
  bool _panTail = false;

  /// Enquanto um arrasto segura a marcação na beirada (ou além dela), este
  /// timer desliza a trilha continuamente, mesmo com o dedo parado.
  Timer? _edgeScrollTimer;
  double _lastDragDx = 0;
  double _lastWidth = 0;

  @override
  void dispose() {
    _edgeScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segmentsState = ref.watch(segmentsControllerProvider);
    final cutter = Theme.of(context).extension<CutterColors>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _zoom = _zoom.clamp(1.0, _maxZoomFor(width, segmentsState.duration));
        _scroll = _clampScroll(_scroll, width);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControls(context, segmentsState, width),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: widget.player,
              builder: (context, value, _) {
                final totalMs = segmentsState.duration.inMilliseconds;
                final playhead = totalMs == 0
                    ? 0.0
                    : (value.position.inMilliseconds / totalMs).clamp(0.0, 1.0);

                // Durante a reprodução, a janela segue o cursor.
                if (value.isPlaying && !_pinching && _dragBoundary == null) {
                  final px = playhead * width * _zoom - _scroll;
                  if (px < 0 || px > width) {
                    _scroll = _clampScroll(
                      playhead * width * _zoom - width * 0.2,
                      width,
                    );
                  }
                }

                final focusedIndex = segmentsState.segments.indexWhere(
                  (s) => s.id == widget.focusedSegmentId,
                );

                return Listener(
                  onPointerDown: (_) => _activePointers++,
                  onPointerUp: (_) => _onPointerGone(),
                  onPointerCancel: (_) => _onPointerGone(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // No soltar (e não no toque), para o primeiro dedo de uma
                    // pinça não teleportar o cursor.
                    onTapUp: (details) {
                      final dx = details.localPosition.dx;
                      if (_hitBoundary(dx, width, segmentsState) == null) {
                        widget.player.seekTo(
                          _positionAt(dx, width, segmentsState),
                        );
                      }
                    },
                    onScaleStart: (details) {
                      final dx = details.localFocalPoint.dx;
                      if (details.pointerCount >= 2) {
                        _startPinch(dx, width);
                        return;
                      }
                      if (_panTail) return;
                      _pinching = false;
                      _lastDragDx = dx;
                      _lastWidth = width;
                      _startEdgeScroll();
                      final hit = _hitBoundary(dx, width, segmentsState);
                      setState(() => _dragBoundary = hit);
                      if (hit == null) {
                        widget.player.seekTo(
                          _positionAt(dx, width, segmentsState),
                        );
                      } else {
                        HapticFeedback.selectionClick();
                      }
                    },
                    onScaleUpdate: (details) {
                      final dx = details.localFocalPoint.dx;
                      if (_pinching || details.pointerCount >= 2) {
                        if (!_pinching) _startPinch(dx, width);
                        setState(() {
                          _zoom = (_pinchBaseZoom * details.scale).clamp(
                            1.0,
                            _maxZoomFor(width, segmentsState.duration),
                          );
                          _scroll = _clampScroll(
                            _pinchBaseFraction * width * _zoom - dx,
                            width,
                          );
                        });
                        return;
                      }
                      if (_panTail) {
                        setState(
                          () => _scroll = _clampScroll(
                            _scroll - details.focalPointDelta.dx,
                            width,
                          ),
                        );
                        return;
                      }
                      _lastDragDx = dx;
                      _lastWidth = width;
                      final position = _positionAt(
                        dx.clamp(0.0, width),
                        width,
                        segmentsState,
                      );
                      final boundary = _dragBoundary;
                      if (boundary != null) {
                        ref
                            .read(segmentsControllerProvider.notifier)
                            .moveBoundary(boundary, position);
                      } else {
                        widget.player.seekTo(position);
                      }
                    },
                    onScaleEnd: (_) {
                      _stopEdgeScroll();
                      if (_pinching) _panTail = _activePointers > 0;
                      _pinching = false;
                      setState(() => _dragBoundary = null);
                    },
                    child: CustomPaint(
                      size: Size(width, TimelineEditor.height),
                      painter: _TimelinePainter(
                        segments: segmentsState.segments,
                        duration: segmentsState.duration,
                        playhead: playhead,
                        activeBoundary: _dragBoundary,
                        focusedIndex: focusedIndex == -1 ? null : focusedIndex,
                        zoom: _zoom,
                        scroll: _scroll,
                        colors: cutter,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Chip do corte em foco + botões de zoom, acima da trilha.
  Widget _buildControls(
    BuildContext context,
    SegmentsState state,
    double width,
  ) {
    final theme = Theme.of(context);
    final maxZoom = _maxZoomFor(width, state.duration);
    final focusedIndex = state.segments.indexWhere(
      (s) => s.id == widget.focusedSegmentId,
    );

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          if (focusedIndex != -1)
            Flexible(
              child: InputChip(
                avatar: Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Foco: Parte ${focusedIndex + 1}',
                  overflow: TextOverflow.ellipsis,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onDeleted: widget.onClearFocus,
                deleteButtonTooltipMessage: 'Tirar do foco',
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Afastar',
            visualDensity: VisualDensity.compact,
            onPressed: _zoom > 1
                ? () => setState(
                    () => _applyZoom(_zoom / _zoomStep, width, state.duration),
                  )
                : null,
            icon: const Icon(Icons.zoom_out_rounded),
          ),
          Tooltip(
            message: 'Ver o vídeo inteiro',
            child: TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(52, 32),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              onPressed: _zoom > 1
                  ? () => setState(() {
                      _zoom = 1;
                      _scroll = 0;
                    })
                  : null,
              child: Text(_zoomLabel),
            ),
          ),
          IconButton(
            tooltip: 'Aproximar',
            visualDensity: VisualDensity.compact,
            onPressed: _zoom < maxZoom
                ? () => setState(
                    () => _applyZoom(_zoom * _zoomStep, width, state.duration),
                  )
                : null,
            icon: const Icon(Icons.zoom_in_rounded),
          ),
        ],
      ),
    );
  }

  String get _zoomLabel {
    final text = _zoom >= 9.95
        ? _zoom.round().toString()
        : _zoom.toStringAsFixed(1).replaceFirst('.0', '').replaceAll('.', ',');
    return '$text×';
  }

  void _onPointerGone() {
    _activePointers = math.max(0, _activePointers - 1);
    if (_activePointers == 0) {
      _panTail = false;
      _pinching = false;
      _stopEdgeScroll();
    }
  }

  void _startPinch(double dx, double width) {
    _pinching = true;
    _panTail = false;
    _stopEdgeScroll();
    _pinchBaseZoom = _zoom;
    final contentWidth = width * _zoom;
    _pinchBaseFraction = contentWidth == 0 ? 0 : (_scroll + dx) / contentWidth;
    if (_dragBoundary != null) setState(() => _dragBoundary = null);
  }

  /// Zoom pelos botões, ancorado no cursor de reprodução quando visível
  /// (senão no centro da janela).
  void _applyZoom(double targetZoom, double width, Duration duration) {
    final newZoom = targetZoom.clamp(1.0, _maxZoomFor(width, duration));
    final contentWidth = width * _zoom;
    final totalMs = duration.inMilliseconds;
    var anchor = width / 2;
    if (totalMs > 0 && contentWidth > 0) {
      final px =
          widget.player.value.position.inMilliseconds / totalMs * contentWidth -
          _scroll;
      if (px >= 0 && px <= width) anchor = px;
    }
    final fraction = contentWidth == 0
        ? 0.0
        : (_scroll + anchor) / contentWidth;
    _zoom = newZoom;
    _scroll = _clampScroll(fraction * width * newZoom - anchor, width);
  }

  /// Segurar a marcação na beirada da janela (ou fora dela) desliza a
  /// trilha continuamente — quanto mais para fora, mais rápido — e leva o
  /// corte ou o cursor junto.
  void _edgeScrollTick() {
    if (!mounted || _pinching || _panTail || _zoom <= 1) return;
    final width = _lastWidth;
    if (width <= 0) return;

    const edge = 32.0;
    const maxSpeed = 18.0; // px por tick (~60 fps)
    final dx = _lastDragDx;
    double delta;
    if (dx < edge) {
      delta = -math.min(maxSpeed, (edge - dx) * 0.25);
    } else if (dx > width - edge) {
      delta = math.min(maxSpeed, (dx - (width - edge)) * 0.25);
    } else {
      return;
    }

    final next = _clampScroll(_scroll + delta, width);
    if (next == _scroll) return; // chegou no limite da trilha
    setState(() => _scroll = next);

    // A trilha andou por baixo do dedo: reaplica a posição sob ele.
    final state = ref.read(segmentsControllerProvider);
    final position = _positionAt(dx.clamp(0.0, width), width, state);
    final boundary = _dragBoundary;
    if (boundary != null) {
      ref
          .read(segmentsControllerProvider.notifier)
          .moveBoundary(boundary, position);
    } else {
      widget.player.seekTo(position);
    }
  }

  void _startEdgeScroll() {
    _edgeScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _edgeScrollTick(),
    );
  }

  void _stopEdgeScroll() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
  }

  double _maxZoomFor(double width, Duration duration) {
    if (width <= 0 || duration <= Duration.zero) return 1;
    final seconds = duration.inMilliseconds / 1000;
    return math.max(1.0, seconds * _maxPxPerSecond / width);
  }

  double _clampScroll(double value, double width) =>
      value.clamp(0.0, math.max(0.0, width * _zoom - width));

  /// Índice da fronteira mais próxima de [dx] (em px da janela), ou `null`
  /// se nenhuma estiver ao alcance de [_grabRadius].
  int? _hitBoundary(double dx, double width, SegmentsState state) {
    final totalMs = state.duration.inMilliseconds;
    if (totalMs == 0) return null;

    final contentWidth = width * _zoom;
    int? nearest;
    var nearestDistance = _grabRadius;
    for (var i = 0; i < state.segments.length - 1; i++) {
      final x =
          contentWidth * state.segments[i].end.inMilliseconds / totalMs -
          _scroll;
      final distance = (dx - x).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = i;
      }
    }
    return nearest;
  }

  Duration _positionAt(double dx, double width, SegmentsState state) {
    final contentWidth = width * _zoom;
    final fraction = contentWidth == 0
        ? 0.0
        : ((dx + _scroll) / contentWidth).clamp(0.0, 1.0);
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
    required this.focusedIndex,
    required this.zoom,
    required this.scroll,
    required this.colors,
  });

  final List<VideoSegment> segments;
  final Duration duration;

  /// Posição do cursor de reprodução, de 0 a 1.
  final double playhead;

  final int? activeBoundary;

  /// Índice do corte em foco (esmaece os demais), se houver.
  final int? focusedIndex;

  final double zoom;
  final double scroll;
  final CutterColors colors;

  /// Faixa superior reservada à régua de tempo.
  static const _rulerHeight = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration == Duration.zero || segments.isEmpty) return;
    canvas.clipRect(Offset.zero & size);

    final contentWidth = size.width * zoom;
    final track = Rect.fromLTWH(
      -scroll,
      _rulerHeight + 18,
      contentWidth,
      size.height - _rulerHeight - 32,
    );
    final trackRRect = RRect.fromRectAndRadius(
      track,
      const Radius.circular(12),
    );

    _paintRuler(canvas, size, contentWidth);

    canvas.save();
    canvas.clipRRect(trackRRect);
    canvas.drawRect(track, Paint()..color = colors.timelineTrack);

    final dimPaint = Paint()
      ..color = colors.timelineTrack.withValues(alpha: 0.6);

    for (final (index, segment) in segments.indexed) {
      final left = _x(segment.start, contentWidth);
      final right = _x(segment.end, contentWidth);
      if (right < 0 || left > size.width) continue;

      final rect = Rect.fromLTRB(left, track.top, right, track.bottom);
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
        // Centro da parte visível, para o número não sumir com o zoom.
        final cx = (math.max(left, 0.0) + math.min(right, size.width)) / 2;
        textPainter.paint(
          canvas,
          Offset(
            cx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      }

      if (focusedIndex != null && index != focusedIndex) {
        canvas.drawRect(rect, dimPaint);
      }
    }
    canvas.restore();

    // Contorno do corte em foco.
    final focused = focusedIndex;
    if (focused != null && focused < segments.length) {
      final segment = segments[focused];
      final rect = Rect.fromLTRB(
        _x(segment.start, contentWidth),
        track.top,
        _x(segment.end, contentWidth),
        track.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(8)),
        Paint()
          ..color = colors.playhead
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Alças das fronteiras entre segmentos.
    for (var i = 0; i < segments.length - 1; i++) {
      final x = _x(segments[i].end, contentWidth);
      if (x < -12 || x > size.width + 12) continue;
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
    var px = playhead * contentWidth - scroll;
    if (px >= -2 && px <= size.width + 2) {
      px = px.clamp(1.0, size.width - 1.0);
      final playheadPaint = Paint()
        ..color = colors.playhead
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(px, _rulerHeight + 10),
        Offset(px, size.height - 2),
        playheadPaint,
      );
      canvas.drawPath(
        _heart(Offset(px, _rulerHeight + 5), 6.5),
        Paint()..color = colors.playhead,
      );
    }
  }

  /// Régua de tempo: marcas maiores rotuladas e marcas menores entre elas.
  void _paintRuler(Canvas canvas, Size size, double contentWidth) {
    final totalMs = duration.inMilliseconds;
    final pxPerMs = contentWidth / totalMs;

    // Menor passo que ainda deixa ~72 px entre rótulos.
    const steps = [
      100, 200, 500, 1000, 2000, 5000, 10000, 15000, 30000,
      60000, 120000, 300000, 600000, 1800000, 3600000, //
    ];
    final stepMs = steps.firstWhere(
      (s) => s * pxPerMs >= 72,
      orElse: () => steps.last,
    );
    final minorStepMs = stepMs ~/ 5;

    final tickPaint = Paint()
      ..color = colors.boundaryHandle.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final minorPaint = Paint()
      ..color = colors.boundaryHandle.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: colors.boundaryHandle.withValues(alpha: 0.8),
      fontFamily: 'Nunito',
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );

    final firstMs = math.max(0, ((scroll / pxPerMs) ~/ stepMs) * stepMs);
    final lastVisibleMs = math.min(
      totalMs.toDouble(),
      (scroll + size.width) / pxPerMs,
    );

    for (var t = firstMs; t <= lastVisibleMs; t += stepMs) {
      final x = t * pxPerMs - scroll;
      canvas.drawLine(
        Offset(x, _rulerHeight - 5),
        Offset(x, _rulerHeight),
        tickPaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: Duration(milliseconds: t).label(tenths: stepMs < 1000),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = (x - textPainter.width / 2)
          .clamp(1.0, math.max(1.0, size.width - textPainter.width - 1))
          .toDouble();
      textPainter.paint(canvas, Offset(lx, 1));

      if (minorStepMs > 0) {
        for (
          var m = t + minorStepMs;
          m < t + stepMs && m <= totalMs;
          m += minorStepMs
        ) {
          final mx = m * pxPerMs - scroll;
          canvas.drawLine(
            Offset(mx, _rulerHeight - 3),
            Offset(mx, _rulerHeight),
            minorPaint,
          );
        }
      }
    }
  }

  /// Coração centrado em [center]; [s] controla o tamanho.
  Path _heart(Offset center, double s) {
    final x = center.dx;
    final y = center.dy - s * 0.4;
    return Path()
      ..moveTo(x, y + s * 0.35)
      ..cubicTo(x - s * 0.6, y - s * 0.35, x - s * 1.1, y + s * 0.35, x, y + s)
      ..cubicTo(
        x + s * 1.1,
        y + s * 0.35,
        x + s * 0.6,
        y - s * 0.35,
        x,
        y + s * 0.35,
      )
      ..close();
  }

  double _x(Duration position, double contentWidth) =>
      contentWidth * position.inMilliseconds / duration.inMilliseconds - scroll;

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.duration != duration ||
      oldDelegate.playhead != playhead ||
      oldDelegate.activeBoundary != activeBoundary ||
      oldDelegate.focusedIndex != focusedIndex ||
      oldDelegate.zoom != zoom ||
      oldDelegate.scroll != scroll ||
      oldDelegate.colors != colors;
}
