# Video Cutter

App Flutter para dividir um vídeo em vários segmentos e exportar todos de uma
vez. O vídeo pode vir do dispositivo (seletor de arquivos) ou de um link do
YouTube.

## Funcionalidades

- **Duas origens de vídeo**: arquivo local ou download do YouTube (com
  progresso). Quando o YouTube só oferece streams adaptativos, o app baixa
  vídeo e áudio separados e junta com FFmpeg, sem recodificar.
- **Timeline interativa**: toque/arraste para navegar (scrub), botão
  **Dividir** corta no cursor, e as fronteiras entre segmentos podem ser
  arrastadas. Cada segmento pode ser ligado/desligado da exportação ou
  mesclado com o vizinho.
- **Exportação em lote** com dois modos:
  - *Rápido*: cópia de streams (`-c copy`) — instantâneo e sem perda, corte
    ajustado ao keyframe mais próximo.
  - *Preciso*: recodifica com H.264/AAC — corte exato, mais lento.
- **Compartilhar tudo**: os arquivos gerados saem juntos pela share sheet do
  sistema (Fotos, Drive, WhatsApp etc.).

## Arquitetura

Feature-first + Clean Architecture, com **Riverpod** para injeção de
dependências e gerenciamento de estado:

```
lib/
├── main.dart                  # ProviderScope + bootstrap
├── app.dart                   # MaterialApp e tema
├── core/                      # código sem regra de negócio
│   ├── errors/                # AppException (falhas tipadas e amigáveis)
│   ├── theme/                 # tema Material 3
│   └── utils/                 # formatação de Duration, nomes de arquivo
└── features/cutter/
    ├── domain/                # ★ não depende de Flutter nem de pacotes
    │   ├── entities/          # VideoMedia, VideoSegment, ExportMode/Event
    │   └── repositories/      # contratos (MediaRepository, ExportRepository)
    ├── data/
    │   ├── datasources/       # youtube_explode_dart, file_picker, FFmpegKit
    │   └── repositories/      # implementações dos contratos
    └── presentation/
        ├── providers.dart     # composição de dependências (DI)
        ├── controllers/       # Notifiers Riverpod com estados selados
        ├── pages/             # HomePage, EditorPage
        └── widgets/           # TimelineEditor (CustomPainter), ExportSheet…
```

### Design system

Tudo que é visual mora em `lib/core/design/`:

- **`app_theme.dart`** — temas claro e escuro gerados de um seed rosa
  framboesa (`ColorScheme.fromSeed` com variante *fidelity*), tipografia
  **Nunito** (embutida em `assets/fonts/`, sem dependência de rede) e todos
  os component themes do Material 3 (botões, inputs, sheets, diálogos…)
  configurados em um lugar só.
- **`tokens.dart`** — escalas de espaçamento (`AppSpacing`), raios
  (`AppRadii`) e movimento (`AppMotion`). As telas não usam números mágicos.
- **`cutter_colors.dart`** — `ThemeExtension` com as cores semânticas do
  editor: paleta pastel dos segmentos (rosa, lilás, pêssego, menta, céu,
  baunilha), trilha da timeline, cursor e alças — resolvidas por tema.

Detalhes de experiência: cursor de reprodução com marcador de coração,
feedback háptico ao cortar e arrastar fronteiras, estados de carregamento e
sucesso animados, e microcopy carinhosa ("pedacinhos" 💕).

Decisões principais:

- **Estados selados** (`sealed class`) por controller — `MediaState`,
  `ExportState` — tornam impossível renderizar um estado não tratado
  (o `switch` da UI é exaustivo em tempo de compilação).
- **Segmentos sempre contíguos**: o `SegmentsController` garante as
  invariantes (cobertura total, mínimo de 0,5 s por parte, fronteiras
  ordenadas). A UI nunca manipula a lista diretamente.
- **Progresso como stream**: `ExportRepository.exportSegments` emite eventos
  (`ExportSegmentProgress`/`ExportCompleted`), então a UI mostra progresso
  real do FFmpeg sem acoplamento.
- **Falhas tipadas**: a camada de dados converte qualquer erro em
  `AppException` com mensagem pronta para o usuário.
- O `VideoPlayerController` fica no `State` da página (ciclo de vida de UI),
  não em provider — apenas o estado de negócio vive no Riverpod.

## Requisitos

| Plataforma | Mínimo | Observação |
| ---------- | ------ | ---------- |
| Android    | API 24 (Android 7) | exigido pelo `ffmpeg_kit_flutter_new` |
| iOS        | 14.0   | defina `platform :ios, '14.0'` no Podfile gerado |

Windows/desktop não é suportado: `video_player` e o FFmpegKit não têm
implementação para desktop.

## Rodando

```bash
flutter pub get
flutter run          # com um emulador/dispositivo Android conectado
flutter test         # testes unitários (controllers e utilitários)
```

## Pacotes

| Pacote | Papel |
| ------ | ----- |
| `flutter_riverpod` | estado + DI |
| `video_player` | reprodução e posição do cursor |
| `ffmpeg_kit_flutter_new` | corte/junção (fork mantido do FFmpegKit, variante full-gpl) |
| `youtube_explode_dart` | resolução e download de streams do YouTube |
| `file_picker` | seleção de vídeo local |
| `share_plus` | compartilhar os segmentos em lote |
| `path_provider` / `path` | diretórios e caminhos |
| `equatable` | igualdade por valor nas entidades/estados |

## Avisos

- Baixar vídeos do YouTube pode violar os Termos de Serviço da plataforma.
  Use apenas com conteúdo próprio ou licenciado.
- Os segmentos são gravados em `Documentos do app/VideoCutter/<título>_<data>/`
  e podem ser compartilhados em lote ao final da exportação.
