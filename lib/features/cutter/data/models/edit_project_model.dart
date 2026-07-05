import '../../domain/entities/edit_project.dart';
import '../../domain/entities/video_media.dart';
import '../../domain/entities/video_segment.dart';

/// DTO de [EditProject] para o arquivo JSON do histórico.
class EditProjectModel {
  const EditProjectModel({
    required this.id,
    required this.name,
    required this.videoPath,
    required this.origin,
    required this.durationMs,
    required this.segments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EditProjectModel.fromJson(Map<String, dynamic> json) {
    return EditProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      videoPath: json['videoPath'] as String,
      origin: MediaOrigin.values.byName(json['origin'] as String),
      durationMs: json['durationMs'] as int,
      segments: [
        for (final segment in json['segments'] as List<dynamic>)
          _segmentFromJson(segment as Map<String, dynamic>),
      ],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  factory EditProjectModel.fromEntity(EditProject entity) {
    return EditProjectModel(
      id: entity.id,
      name: entity.name,
      videoPath: entity.videoPath,
      origin: entity.origin,
      durationMs: entity.duration.inMilliseconds,
      segments: entity.segments,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  final String id;
  final String name;
  final String videoPath;
  final MediaOrigin origin;
  final int durationMs;
  final List<VideoSegment> segments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'videoPath': videoPath,
        'origin': origin.name,
        'durationMs': durationMs,
        'segments': [
          for (final segment in segments)
            {
              'id': segment.id,
              'startMs': segment.start.inMilliseconds,
              'endMs': segment.end.inMilliseconds,
              'enabled': segment.enabled,
            },
        ],
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  EditProject toEntity() => EditProject(
        id: id,
        name: name,
        videoPath: videoPath,
        origin: origin,
        duration: Duration(milliseconds: durationMs),
        segments: segments,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  EditProjectModel copyWith({
    String? name,
    int? durationMs,
    List<VideoSegment>? segments,
    DateTime? updatedAt,
  }) {
    return EditProjectModel(
      id: id,
      name: name ?? this.name,
      videoPath: videoPath,
      origin: origin,
      durationMs: durationMs ?? this.durationMs,
      segments: segments ?? this.segments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static VideoSegment _segmentFromJson(Map<String, dynamic> json) {
    return VideoSegment(
      id: json['id'] as int,
      start: Duration(milliseconds: json['startMs'] as int),
      end: Duration(milliseconds: json['endMs'] as int),
      enabled: json['enabled'] as bool,
    );
  }
}
