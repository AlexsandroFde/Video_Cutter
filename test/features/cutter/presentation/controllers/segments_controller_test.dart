import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_cutter/features/cutter/domain/entities/video_segment.dart';
import 'package:video_cutter/features/cutter/presentation/controllers/segments_controller.dart';
import 'package:video_cutter/features/cutter/presentation/providers.dart';

void main() {
  late ProviderContainer container;
  late SegmentsController controller;

  const total = Duration(minutes: 10);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    controller = container.read(segmentsControllerProvider.notifier);
    controller.initialize(total);
  });

  SegmentsState state() => container.read(segmentsControllerProvider);

  group('initialize', () {
    test('cria um único segmento cobrindo o vídeo inteiro', () {
      expect(state().segments, hasLength(1));
      expect(state().segments.single.start, Duration.zero);
      expect(state().segments.single.end, total);
      expect(state().segments.single.enabled, isTrue);
      expect(state().isReady, isTrue);
    });
  });

  group('splitAt', () {
    test('divide o segmento em dois no ponto pedido', () {
      const cut = Duration(minutes: 4);

      expect(controller.splitAt(cut), isTrue);

      final segments = state().segments;
      expect(segments, hasLength(2));
      expect(segments[0].start, Duration.zero);
      expect(segments[0].end, cut);
      expect(segments[1].start, cut);
      expect(segments[1].end, total);
    });

    test('mantém o id do segmento original na metade esquerda', () {
      final originalId = state().segments.single.id;

      controller.splitAt(const Duration(minutes: 4));

      expect(state().segments[0].id, originalId);
      expect(state().segments[1].id, isNot(originalId));
    });

    test('recusa corte mais perto que 0,5 s de uma fronteira', () {
      expect(controller.splitAt(const Duration(milliseconds: 300)), isFalse);
      expect(
        controller.splitAt(total - const Duration(milliseconds: 300)),
        isFalse,
      );
      expect(state().segments, hasLength(1));
    });

    test('recusa corte fora do vídeo ou exatamente na fronteira', () {
      expect(controller.splitAt(Duration.zero), isFalse);
      expect(controller.splitAt(total), isFalse);
      expect(controller.splitAt(total + const Duration(seconds: 1)), isFalse);
    });

    test('novo segmento herda o enabled do segmento dividido', () {
      controller.splitAt(const Duration(minutes: 5));
      final disabledId = state().segments[1].id;
      controller.toggle(disabledId);

      controller.splitAt(const Duration(minutes: 7));

      expect(state().segments[1].enabled, isFalse);
      expect(state().segments[2].enabled, isFalse);
    });
  });

  group('mergeWithNext', () {
    test('une dois segmentos vizinhos preservando a cobertura', () {
      controller.splitAt(const Duration(minutes: 4));
      controller.splitAt(const Duration(minutes: 7));

      controller.mergeWithNext(0);

      final segments = state().segments;
      expect(segments, hasLength(2));
      expect(segments[0].start, Duration.zero);
      expect(segments[0].end, const Duration(minutes: 7));
      expect(segments[1].end, total);
    });

    test('ignora índices inválidos', () {
      controller.mergeWithNext(0); // único segmento, não há próximo
      controller.mergeWithNext(-1);
      expect(state().segments, hasLength(1));
    });

    test('segmento mesclado fica habilitado se qualquer lado estava', () {
      controller.splitAt(const Duration(minutes: 4));
      controller.toggle(state().segments[0].id);
      expect(state().segments[0].enabled, isFalse);

      controller.mergeWithNext(0);

      expect(state().segments.single.enabled, isTrue);
    });
  });

  group('moveBoundary', () {
    test('reposiciona a fronteira entre dois segmentos', () {
      controller.splitAt(const Duration(minutes: 4));

      controller.moveBoundary(0, const Duration(minutes: 6));

      expect(state().segments[0].end, const Duration(minutes: 6));
      expect(state().segments[1].start, const Duration(minutes: 6));
    });

    test('respeita o comprimento mínimo dos vizinhos', () {
      controller.splitAt(const Duration(minutes: 4));

      controller.moveBoundary(0, Duration.zero);
      expect(state().segments[0].end, SegmentsController.minSegment);

      controller.moveBoundary(0, total);
      expect(state().segments[1].start, total - SegmentsController.minSegment);
    });

    test('ignora índices inválidos', () {
      controller.moveBoundary(0, const Duration(minutes: 1));
      expect(state().segments.single.end, total);
    });
  });

  group('toggle', () {
    test('alterna apenas o segmento com o id pedido', () {
      controller.splitAt(const Duration(minutes: 4));
      final firstId = state().segments[0].id;

      controller.toggle(firstId);

      expect(state().segments[0].enabled, isFalse);
      expect(state().segments[1].enabled, isTrue);
      expect(state().enabledCount, 1);
    });
  });

  group('restore', () {
    test('retoma os segmentos salvos e continua os ids sem colisão', () {
      const cut = Duration(minutes: 4);
      controller.restore(total, const [
        VideoSegment(id: 0, start: Duration.zero, end: cut),
        VideoSegment(id: 3, start: cut, end: total, enabled: false),
      ]);

      expect(state().segments, hasLength(2));
      expect(state().segments[1].enabled, isFalse);

      controller.splitAt(const Duration(minutes: 2));
      final ids = state().segments.map((s) => s.id).toSet();
      expect(ids, hasLength(3), reason: 'novo id não pode repetir os salvos');
    });

    test('estado salvo que não cobre o vídeo inteiro recomeça do zero', () {
      controller.restore(total, const [
        VideoSegment(id: 0, start: Duration.zero, end: Duration(minutes: 4)),
      ]);

      expect(state().segments, hasLength(1));
      expect(state().segments.single.end, total);
    });

    test('segmentos não contíguos recomeçam do zero', () {
      controller.restore(total, const [
        VideoSegment(id: 0, start: Duration.zero, end: Duration(minutes: 3)),
        VideoSegment(id: 1, start: Duration(minutes: 4), end: total),
      ]);

      expect(state().segments, hasLength(1));
    });

    test('lista vazia recomeça do zero', () {
      controller.restore(total, const []);
      expect(state().segments, hasLength(1));
      expect(state().segments.single.start, Duration.zero);
      expect(state().segments.single.end, total);
    });
  });

  group('clear', () {
    test('volta ao estado vazio', () {
      controller.splitAt(const Duration(minutes: 4));
      controller.clear();
      expect(state().segments, isEmpty);
      expect(state().isReady, isFalse);
    });
  });
}
