/// A single file attached to a post.
///
/// Three shapes come back from the API: `{name, path}`, `{name, path,
/// preview_only}` and `{name, deferred}`. A deferred attachment has not been
/// scraped yet and carries no [path], so it has no downloadable URL.
class PawchiveAttachmentDto {
  const PawchiveAttachmentDto({
    this.name,
    this.path,
    this.deferred,
    this.previewOnly,
  });

  factory PawchiveAttachmentDto.fromJson(Map<String, dynamic> json) {
    return PawchiveAttachmentDto(
      name: json['name'] as String?,
      path: json['path'] as String?,
      deferred: json['deferred'] as bool?,
      previewOnly: json['preview_only'] as bool?,
    );
  }

  final String? name;
  final String? path;
  final bool? deferred;
  final bool? previewOnly;

  bool get isAvailable => path != null && path!.isNotEmpty;

  @override
  String toString() => name ?? path ?? '<deferred>';
}
