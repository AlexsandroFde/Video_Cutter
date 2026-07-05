// Gera os PNGs do ícone do app em assets/icon/.
//
// Rode com: flutter test test/tools/generate_app_icon_test.dart
//
// Saídas (1024x1024):
//  - app_icon.png            -> ícone legado (fundo arredondado embutido)
//  - app_icon_foreground.png -> camada frontal do ícone adaptativo
//  - app_icon_background.png -> camada de fundo do ícone adaptativo
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

const _pinkLight = Color(0xFFF7A3BF);
const _pinkSeed = Color(0xFFE2557B);
const _pinkDeep = Color(0xFFD84C77);

void main() {
  test('gera os PNGs do ícone do app', () async {
    final dir = Directory('assets/icon');
    dir.createSync(recursive: true);

    await _savePng('${dir.path}/app_icon.png', (canvas) {
      _paintBackground(canvas, cornerRadius: 224);
      _paintHeartWithPlay(canvas, scale: 0.78);
    });

    await _savePng('${dir.path}/app_icon_background.png', (canvas) {
      _paintBackground(canvas, cornerRadius: 0);
    });

    await _savePng('${dir.path}/app_icon_foreground.png', (canvas) {
      _paintHeartWithPlay(canvas, scale: 0.54);
    });
  });
}

Future<void> _savePng(String path, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, _size, _size),
  );
  paint(canvas);
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _paintBackground(Canvas canvas, {required double cornerRadius}) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));

  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [_pinkLight, _pinkSeed, _pinkDeep],
        [0.0, 0.55, 1.0],
      ),
  );

  // Brilho suave no canto superior esquerdo.
  canvas.save();
  canvas.clipRRect(rrect);
  canvas.drawCircle(
    const Offset(_size * 0.22, _size * 0.18),
    _size * 0.55,
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_size * 0.22, _size * 0.18),
        _size * 0.55,
        [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.0)],
      ),
  );
  canvas.restore();

}

void _paintHeartWithPlay(Canvas canvas, {required double scale}) {
  final heartSide = _size * scale;
  // O desenho do coração ocupa 0.06–0.90 do rect na vertical, então o centro
  // da bounding box fica 0.02*lado acima do centro do rect. O rect é
  // deslocado para que a bounding box fique no centro exato da tela,
  // independente da escala.
  final heartRect = Rect.fromCenter(
    center: Offset(_size / 2, _size * 0.50 + heartSide * 0.02),
    width: heartSide,
    height: heartSide,
  );
  final heart = _heartPath(heartRect);

  canvas.drawShadow(heart, const Color(0x66922046), _size * 0.02, false);
  canvas.drawPath(heart, Paint()..color = Colors.white);

  // Triângulo de play equilátero, com o centroide no centro do coração
  // (centralização óptica padrão de botões de play).
  final r = heartSide * 0.19;
  // O coração foi elevado em 0.0125 da tela, mas o play fica na altura
  // original (o deslocamento é só do coração).
  final center = heart.getBounds().center.translate(0, _size * 0.0125);
  final play = Path()
    ..moveTo(center.dx + r, center.dy)
    ..lineTo(center.dx - r / 2, center.dy - r * 0.866)
    ..lineTo(center.dx - r / 2, center.dy + r * 0.866)
    ..close();
  canvas.drawPath(
    play,
    Paint()
      ..color = _pinkDeep
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = r * 0.45
      ..style = PaintingStyle.stroke,
  );
  canvas.drawPath(play, Paint()..color = _pinkDeep);

  // Brilhinhos junto do coração, para ficarem dentro da área visível da
  // máscara do ícone adaptativo (que corta as bordas do canvas).
  final hc = heart.getBounds().center;
  _paintSparkle(
      canvas, hc.translate(heartSide * 0.42, -heartSide * 0.38), heartSide * 0.075);
  _paintSparkle(
      canvas, hc.translate(-heartSide * 0.45, heartSide * 0.26), heartSide * 0.055);
  _paintSparkle(
      canvas, hc.translate(heartSide * 0.46, heartSide * 0.20), heartSide * 0.040);
}

Path _heartPath(Rect r) {
  double x(double u) => r.left + u * r.width;
  double y(double v) => r.top + v * r.height;
  return Path()
    ..moveTo(x(0.50), y(0.30))
    ..cubicTo(x(0.42), y(0.10), x(0.16), y(0.06), x(0.08), y(0.24))
    ..cubicTo(x(0.00), y(0.42), x(0.16), y(0.62), x(0.50), y(0.90))
    ..cubicTo(x(0.84), y(0.62), x(1.00), y(0.42), x(0.92), y(0.24))
    ..cubicTo(x(0.84), y(0.06), x(0.58), y(0.10), x(0.50), y(0.30))
    ..close();
}

void _paintSparkle(Canvas canvas, Offset c, double r) {
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();
  canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.85));
}
