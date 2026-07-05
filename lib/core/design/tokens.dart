import 'package:flutter/animation.dart';

/// Tokens de layout do design system.
///
/// Toda medida usada na UI deve vir daqui — nada de números mágicos nas
/// telas. A escala é base-4.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Raios de borda. Cantos bem arredondados são parte da identidade do app.
abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

/// Durações e curvas padrão de animação.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 500);

  static const ease = Curves.easeOutCubic;
  static const bouncy = Curves.elasticOut;
}
