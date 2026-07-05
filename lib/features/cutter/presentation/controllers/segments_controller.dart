import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_segment.dart';

/// Estado da segmentação: a duração do vídeo e a lista de segmentos, que é
/// sempre contígua e cobre a duração inteira.
class SegmentsState extends Equatable {
  const SegmentsState({
    this.duration = Duration.zero,
    this.segments = const [],
  });

  final Duration duration;
  final List<VideoSegment> segments;

  bool get isReady => duration > Duration.zero && segments.isNotEmpty;

  int get enabledCount => segments.where((s) => s.enabled).length;

  List<VideoSegment> get enabledSegments =>
      segments.where((s) => s.enabled).toList();

  SegmentsState copyWith({Duration? duration, List<VideoSegment>? segments}) {
    return SegmentsState(
      duration: duration ?? this.duration,
      segments: segments ?? this.segments,
    );
  }

  @override
  List<Object?> get props => [duration, segments];
}

/// Regras de edição dos segmentos: dividir, mesclar, arrastar fronteiras e
/// habilitar/desabilitar trechos.
class SegmentsController extends Notifier<SegmentsState> {
  /// Comprimento mínimo de um segmento — evita cortes degenerados.
  static const minSegment = Duration(milliseconds: 500);

  int _nextId = 0;

  @override
  SegmentsState build() => const SegmentsState();

  /// (Re)inicia a edição com um único segmento cobrindo o vídeo inteiro.
  void initialize(Duration duration) {
    _nextId = 0;
    state = SegmentsState(
      duration: duration,
      segments: [
        VideoSegment(id: _nextId++, start: Duration.zero, end: duration),
      ],
    );
  }

  /// Divide em dois o segmento que contém [position].
  ///
  /// Retorna `false` quando o corte cairia a menos de [minSegment] de uma
  /// fronteira existente (ou fora do vídeo).
  bool splitAt(Duration position) {
    final index = state.segments
        .indexWhere((s) => position > s.start && position < s.end);
    if (index == -1) return false;

    final segment = state.segments[index];
    if (position - segment.start < minSegment ||
        segment.end - position < minSegment) {
      return false;
    }

    final updated = [...state.segments]..replaceRange(index, index + 1, [
        segment.copyWith(end: position),
        VideoSegment(
          id: _nextId++,
          start: position,
          end: segment.end,
          enabled: segment.enabled,
        ),
      ]);
    state = state.copyWith(segments: updated);
    return true;
  }

  /// Remove a fronteira entre os segmentos [index] e [index] + 1,
  /// mesclando os dois em um só.
  void mergeWithNext(int index) {
    if (index < 0 || index >= state.segments.length - 1) return;
    final left = state.segments[index];
    final right = state.segments[index + 1];
    final merged = left.copyWith(
      end: right.end,
      enabled: left.enabled || right.enabled,
    );
    final updated = [...state.segments]
      ..replaceRange(index, index + 2, [merged]);
    state = state.copyWith(segments: updated);
  }

  /// Arrasta a fronteira entre os segmentos [index] e [index] + 1 para
  /// [position], respeitando [minSegment] de cada lado.
  void moveBoundary(int index, Duration position) {
    if (index < 0 || index >= state.segments.length - 1) return;
    final left = state.segments[index];
    final right = state.segments[index + 1];

    final lowerBound = left.start + minSegment;
    final upperBound = right.end - minSegment;
    if (lowerBound > upperBound) return;

    final clamped = _clamp(position, lowerBound, upperBound);
    if (clamped == left.end) return;

    final updated = [...state.segments];
    updated[index] = left.copyWith(end: clamped);
    updated[index + 1] = right.copyWith(start: clamped);
    state = state.copyWith(segments: updated);
  }

  /// Inverte a participação do segmento [id] na exportação.
  void toggle(int id) {
    state = state.copyWith(segments: [
      for (final s in state.segments)
        s.id == id ? s.copyWith(enabled: !s.enabled) : s,
    ]);
  }

  void clear() {
    _nextId = 0;
    state = const SegmentsState();
  }

  Duration _clamp(Duration value, Duration min, Duration max) =>
      value < min ? min : (value > max ? max : value);
}
