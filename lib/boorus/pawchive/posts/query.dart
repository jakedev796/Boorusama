/// Prefix that scopes a search to one creator, e.g.
/// `creator:patreon/92513615`.
const kPawchiveCreatorPrefix = 'creator:';

/// Prefix that filters a creator's posts by one of their own tags, e.g.
/// `tag:sketch`. Only meaningful alongside a creator — Pawchive has no global
/// tag pool.
const kPawchiveTagPrefix = 'tag:';

/// A search resolved from Boorusama's flat tag list into the shape Pawchive's
/// API actually accepts.
///
/// The core `PostRepository` contract hands the engine a list of tag strings,
/// but Pawchive offers no global tag search — only a free-text `q`, plus a
/// per-creator `tag`. Creator scope is therefore carried as a `creator:`
/// meta-tag, and anything unprefixed is treated as free text.
class PawchiveQuery {
  const PawchiveQuery({
    this.service,
    this.creatorId,
    this.tag,
    this.text,
  });

  /// Parses Boorusama's tag list.
  ///
  /// Later occurrences win, so tapping a creator after typing one behaves the
  /// way a user would expect.
  factory PawchiveQuery.parse(List<String> tags) {
    String? service;
    String? creatorId;
    String? tag;
    final freeText = <String>[];

    for (final raw in tags) {
      final entry = raw.trim();
      if (entry.isEmpty) continue;

      if (entry.startsWith(kPawchiveCreatorPrefix)) {
        final value = entry.substring(kPawchiveCreatorPrefix.length);
        final separator = value.indexOf('/');

        // Without a service the id is ambiguous, so ignore a bare creator.
        if (separator > 0 && separator < value.length - 1) {
          service = value.substring(0, separator);
          creatorId = value.substring(separator + 1);
        }
        continue;
      }

      if (entry.startsWith(kPawchiveTagPrefix)) {
        final value = entry.substring(kPawchiveTagPrefix.length);
        if (value.isNotEmpty) tag = value;
        continue;
      }

      freeText.add(entry);
    }

    return PawchiveQuery(
      service: service,
      creatorId: creatorId,
      tag: tag,
      text: freeText.isEmpty ? null : freeText.join(' '),
    );
  }

  final String? service;
  final String? creatorId;
  final String? tag;
  final String? text;

  /// Whether this search targets a single creator's posts.
  bool get hasCreator => service != null && creatorId != null;

  /// The meta-tag form, for putting a creator back into the search bar.
  static String creatorTag({
    required String service,
    required String creatorId,
  }) => '$kPawchiveCreatorPrefix$service/$creatorId';
}
