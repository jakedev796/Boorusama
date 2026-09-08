// Project imports:
import 'pawchive_attachment_dto.dart';

/// A post from a creator on an upstream service.
///
/// Identity is the triple ([service], [user], [id]) — [id] alone is not unique
/// across services.
///
/// The published schema documents a `content` field, but the live API returns
/// `substring` instead and adds `has_full`, `origin` and `preview_state`. Both
/// body keys are read here so either shape works.
class PawchivePostDto {
  const PawchivePostDto({
    this.id,
    this.user,
    this.service,
    this.title,
    this.content,
    this.published,
    this.added,
    this.edited,
    this.file,
    this.attachments = const [],
    this.sharedFile,
    this.hasFull,
    this.origin,
    this.previewState,
  });

  factory PawchivePostDto.fromJson(Map<String, dynamic> json) {
    return PawchivePostDto(
      id: json['id']?.toString(),
      user: json['user']?.toString(),
      service: json['service'] as String?,
      title: json['title'] as String?,
      content: (json['content'] ?? json['substring']) as String?,
      published: json['published'] as String?,
      added: json['added'] as String?,
      edited: json['edited'] as String?,
      file: _parseFile(json['file']),
      attachments: _parseAttachments(json['attachments']),
      sharedFile: json['shared_file'] as bool?,
      hasFull: json['has_full'] as bool?,
      origin: json['origin'] as String?,
      previewState: json['preview_state'] as String?,
    );
  }

  final String? id;
  final String? user;
  final String? service;
  final String? title;
  final String? content;
  final String? published;
  final String? added;
  final String? edited;

  /// The post's headline file. Comes back as an empty object when absent.
  final PawchiveAttachmentDto? file;

  final List<PawchiveAttachmentDto> attachments;
  final bool? sharedFile;
  final bool? hasFull;
  final String? origin;
  final String? previewState;

  /// [file] followed by [attachments], skipping anything without a path.
  ///
  /// Duplicates are dropped — a post's headline file is frequently repeated as
  /// its first attachment.
  List<PawchiveAttachmentDto> get allFiles {
    final seen = <String>{};
    final result = <PawchiveAttachmentDto>[];

    for (final candidate in [?file, ...attachments]) {
      if (!candidate.isAvailable) continue;
      if (!seen.add(candidate.path!)) continue;
      result.add(candidate);
    }

    return result;
  }

  static PawchiveAttachmentDto? _parseFile(dynamic json) {
    if (json is! Map<String, dynamic> || json.isEmpty) return null;

    return PawchiveAttachmentDto.fromJson(json);
  }

  static List<PawchiveAttachmentDto> _parseAttachments(dynamic json) {
    if (json is! List) return const [];

    return json
        .whereType<Map<String, dynamic>>()
        .map(PawchiveAttachmentDto.fromJson)
        .toList();
  }

  @override
  String toString() => '$service/$user/$id';
}
