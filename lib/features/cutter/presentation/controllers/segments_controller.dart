import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_chapter.dart';
import '../../domain/entities/video_segment.dart';

/// Estado da segmentação: a duração do vídeo e a lista de segmentos, que é
/// sempre contígua e cobre a duração inteira.
class SegmentsState extends Equatable {
  const SegmentsState({
    this.duration = Duration.zero,
    this.segments = const [],
    this.canUndo = false,
    this.canRedo = false,
  });

  final Duration duration;
  final List<VideoSegment> segments;

  /// Há edições para desfazer/refazer (histórico vale só para a sessão).
  final bool canUndo;
  final bool canRedo;

  bool get isReady => duration > Duration.zero && segments.isNotEmpty;

  int get enabledCount => segments.where((s) => s.enabled).length;

  List<VideoSegment> get enabledSegments =>
      segments.where((s) => s.enabled).toList();

  SegmentsState copyWith({
    Duration? duration,
    List<VideoSegment>? segments,
    bool? canUndo,
    bool? canRedo,
  }) {
    return SegmentsState(
      duration: duration ?? this.duration,
      segments: segments ?? this.segments,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }

  @override
  List<Object?> get props => [duration, segments, canUndo, canRedo];
}

/// Regras de edição dos segmentos: dividir, mesclar, arrastar fronteiras e
/// habilitar/desabilitar trechos — com undo/redo por sessão.
class SegmentsController extends Notifier<SegmentsState> {
  /// Comprimento mínimo de um segmento — evita cortes degenerados.
  static const minSegment = Duration(milliseconds: 500);

  /// Limite de passos de undo — o bastante para uma sessão de edição.
  static const _maxHistorySteps = 100;

  int _nextId = 0;

  final List<List<VideoSegment>> _undoStack = [];
  final List<List<VideoSegment>> _redoStack = [];

  @override
  SegmentsState build() => const SegmentsState();

  /// Registra o estado atual como um passo de undo e aplica [segments].
  void _apply(List<VideoSegment> segments) {
    _pushUndoStep();
    state = state.copyWith(segments: segments, canUndo: true, canRedo: false);
  }

  void _pushUndoStep() {
    _undoStack.add(state.segments);
    if (_undoStack.length > _maxHistorySteps) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(state.segments);
    state = state.copyWith(
      segments: _undoStack.removeLast(),
      canUndo: _undoStack.isNotEmpty,
      canRedo: true,
    );
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(state.segments);
    state = state.copyWith(
      segments: _redoStack.removeLast(),
      canUndo: true,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  /// Início de um arrasto de fronteira: o arrasto inteiro (vários
  /// [moveBoundary]) vira um único passo de undo.
  void beginBoundaryDrag() {
    _pushUndoStep();
    state = state.copyWith(canUndo: true, canRedo: false);
  }

  /// Fim do arrasto: se a fronteira voltou para onde estava, descarta o
  /// passo de undo criado em [beginBoundaryDrag].
  void endBoundaryDrag() {
    if (_undoStack.isNotEmpty && listEquals(_undoStack.last, state.segments)) {
      _undoStack.removeLast();
      state = state.copyWith(canUndo: _undoStack.isNotEmpty);
    }
  }

  /// (Re)inicia a edição com um único segmento cobrindo o vídeo inteiro.
  void initialize(Duration duration) {
    _nextId = 0;
    _clearHistory();
    state = SegmentsState(
      duration: duration,
      segments: [
        VideoSegment(id: _nextId++, start: Duration.zero, end: duration),
      ],
    );
  }

  /// Retoma uma edição salva no histórico.
  ///
  /// Se o estado salvo não cobrir [duration] de forma contígua (vídeo
  /// trocado, dados antigos), recomeça do zero com [initialize].
  void restore(Duration duration, List<VideoSegment> segments) {
    if (duration <= Duration.zero || !_covers(duration, segments)) {
      initialize(duration);
      return;
    }
    _nextId = segments.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;
    _clearHistory();
    state = SegmentsState(duration: duration, segments: List.of(segments));
  }

  bool _covers(Duration duration, List<VideoSegment> segments) {
    if (segments.isEmpty) return false;
    if (segments.first.start != Duration.zero) return false;
    if (segments.last.end != duration) return false;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].end <= segments[i].start) return false;
      if (i > 0 && segments[i].start != segments[i - 1].end) return false;
    }
    return true;
  }

  /// Divide em dois o segmento que contém [position].
  ///
  /// Retorna `false` quando o corte cairia a menos de [minSegment] de uma
  /// fronteira existente (ou fora do vídeo).
  bool splitAt(Duration position) {
    final index = state.segments.indexWhere(
      (s) => position > s.start && position < s.end,
    );
    if (index == -1) return false;

    final segment = state.segments[index];
    if (position - segment.start < minSegment ||
        segment.end - position < minSegment) {
      return false;
    }

    final updated = [...state.segments]
      ..replaceRange(index, index + 1, [
        segment.copyWith(end: position),
        VideoSegment(
          id: _nextId++,
          start: position,
          end: segment.end,
          enabled: segment.enabled,
        ),
      ]);
    _apply(updated);
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
    _apply(updated);
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

  /// Recria os segmentos a partir dos capítulos do vídeo: cada capítulo
  /// vira um segmento, do timestamp dele até o próximo (ou o fim do vídeo).
  ///
  /// Capítulos fora da duração ou a menos de [minSegment] de outro corte
  /// são ignorados. Substitui a segmentação atual como um único passo de
  /// undo. Retorna quantos segmentos foram criados; 0 significa que nenhum
  /// capítulo era aproveitável e nada mudou.
  int applyChapters(List<VideoChapter> chapters) {
    final duration = state.duration;
    if (duration <= Duration.zero || chapters.isEmpty) return 0;

    final starts = chapters.map((c) => c.start).toList()..sort();
    final cuts = <Duration>[];
    var previous = Duration.zero;
    for (final start in starts) {
      if (start - previous < minSegment) continue;
      if (duration - start < minSegment) break;
      cuts.add(start);
      previous = start;
    }
    if (cuts.isEmpty) return 0;

    final points = [Duration.zero, ...cuts, duration];
    _apply([
      for (var i = 0; i < points.length - 1; i++)
        VideoSegment(id: _nextId++, start: points[i], end: points[i + 1]),
    ]);
    return state.segments.length;
  }

  /// Inverte a participação do segmento [id] na exportação.
  void toggle(int id) {
    _apply([
      for (final s in state.segments)
        s.id == id ? s.copyWith(enabled: !s.enabled) : s,
    ]);
  }

  void clear() {
    _nextId = 0;
    _clearHistory();
    state = const SegmentsState();
  }

  Duration _clamp(Duration value, Duration min, Duration max) =>
      value < min ? min : (value > max ? max : value);
}
