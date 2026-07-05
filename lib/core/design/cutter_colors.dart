import 'package:flutter/material.dart';

/// Cores semânticas do editor que não existem no [ColorScheme] do Material —
/// principalmente a paleta pastel que identifica cada segmento na timeline
/// e na lista de partes.
///
/// Acesse com `Theme.of(context).extension<CutterColors>()!`.
@immutable
class CutterColors extends ThemeExtension<CutterColors> {
  const CutterColors({
    required this.segmentPalette,
    required this.segmentInk,
    required this.segmentDisabled,
    required this.timelineTrack,
    required this.playhead,
    required this.boundaryHandle,
  });

  /// Pastéis usados em rodízio para os segmentos (timeline e lista).
  final List<Color> segmentPalette;

  /// Cor de texto/ícones sobre os pastéis de [segmentPalette].
  final Color segmentInk;

  /// Preenchimento de segmentos fora da exportação.
  final Color segmentDisabled;

  /// Fundo da trilha da timeline.
  final Color timelineTrack;

  /// Cursor de reprodução (linha + coração).
  final Color playhead;

  /// Alças de arrasto entre segmentos.
  final Color boundaryHandle;

  /// Pastel do segmento na posição [index].
  Color segmentColor(int index) =>
      segmentPalette[index % segmentPalette.length];

  /// Rosa, lilás, pêssego, menta, céu e baunilha — a mesma paleta funciona
  /// sobre os dois temas; só trilha/cursor mudam por brilho.
  static const _palette = [
    Color(0xFFF48FB1),
    Color(0xFFB39DDB),
    Color(0xFFFFAB91),
    Color(0xFF80CBC4),
    Color(0xFF90CAF9),
    Color(0xFFFFE082),
  ];

  static const light = CutterColors(
    segmentPalette: _palette,
    segmentInk: Color(0xFF4A2F3E),
    segmentDisabled: Color(0x1F4A2F3E),
    timelineTrack: Color(0xFFF6E4EC),
    playhead: Color(0xFFD84C77),
    boundaryHandle: Color(0xFF7A5468),
  );

  static const dark = CutterColors(
    segmentPalette: _palette,
    segmentInk: Color(0xFF4A2F3E),
    segmentDisabled: Color(0x29FFFFFF),
    timelineTrack: Color(0xFF3B2C36),
    playhead: Color(0xFFFFD4E2),
    boundaryHandle: Color(0xFFE9C7D6),
  );

  @override
  CutterColors copyWith({
    List<Color>? segmentPalette,
    Color? segmentInk,
    Color? segmentDisabled,
    Color? timelineTrack,
    Color? playhead,
    Color? boundaryHandle,
  }) {
    return CutterColors(
      segmentPalette: segmentPalette ?? this.segmentPalette,
      segmentInk: segmentInk ?? this.segmentInk,
      segmentDisabled: segmentDisabled ?? this.segmentDisabled,
      timelineTrack: timelineTrack ?? this.timelineTrack,
      playhead: playhead ?? this.playhead,
      boundaryHandle: boundaryHandle ?? this.boundaryHandle,
    );
  }

  @override
  CutterColors lerp(CutterColors? other, double t) {
    if (other is! CutterColors) return this;
    return CutterColors(
      segmentPalette: [
        for (var i = 0; i < segmentPalette.length; i++)
          Color.lerp(
            segmentPalette[i],
            other.segmentPalette[i % other.segmentPalette.length],
            t,
          )!,
      ],
      segmentInk: Color.lerp(segmentInk, other.segmentInk, t)!,
      segmentDisabled: Color.lerp(segmentDisabled, other.segmentDisabled, t)!,
      timelineTrack: Color.lerp(timelineTrack, other.timelineTrack, t)!,
      playhead: Color.lerp(playhead, other.playhead, t)!,
      boundaryHandle: Color.lerp(boundaryHandle, other.boundaryHandle, t)!,
    );
  }
}
