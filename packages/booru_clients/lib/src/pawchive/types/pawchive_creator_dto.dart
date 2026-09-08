/// A creator whose posts have been archived.
///
/// Identity is the pair ([service], [id]).
class PawchiveCreatorDto {
  const PawchiveCreatorDto({
    this.id,
    this.name,
    this.service,
    this.favorited,
    this.indexed,
    this.updated,
  });

  factory PawchiveCreatorDto.fromJson(Map<String, dynamic> json) {
    return PawchiveCreatorDto(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      service: json['service'] as String?,
      favorited: (json['favorited'] as num?)?.toInt(),
      indexed: _parseTimestamp(json['indexed']),
      updated: _parseTimestamp(json['updated']),
    );
  }

  final String? id;
  final String? name;
  final String? service;

  /// How many accounts have favorited this creator.
  final int? favorited;

  final DateTime? indexed;
  final DateTime? updated;

  /// Unix seconds in practice, but the schema types these as `number`, so a
  /// string or a float has to be tolerated.
  static DateTime? _parseTimestamp(dynamic value) {
    final seconds = switch (value) {
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? double.tryParse(s)?.toInt(),
      _ => null,
    };

    if (seconds == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  @override
  String toString() => '$service/$id ($name)';
}
