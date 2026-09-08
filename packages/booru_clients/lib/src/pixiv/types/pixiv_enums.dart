/// Ranking mode, mapped to the API's wire string via [value].
enum PixivRankingMode {
  day('day'),
  week('week'),
  month('month'),
  dayMale('day_male'),
  dayFemale('day_female'),
  weekOriginal('week_original'),
  weekRookie('week_rookie'),
  dayManga('day_manga'),
  weekManga('week_manga'),
  monthManga('month_manga'),
  dayAi('day_ai'),
  dayR18('day_r18'),
  dayMaleR18('day_male_r18'),
  dayFemaleR18('day_female_r18'),
  weekR18('week_r18'),
  weekR18g('week_r18g');

  const PixivRankingMode(this.value);

  final String value;
}

/// `search_target` parameter for `/v1/search/illust`.
enum PixivSearchTarget {
  partialMatchForTags('partial_match_for_tags'),
  exactMatchForTags('exact_match_for_tags'),
  titleAndCaption('title_and_caption');

  const PixivSearchTarget(this.value);

  final String value;
}

/// `sort` parameter for `/v1/search/illust`. `popularDesc` requires Premium.
enum PixivSearchSort {
  dateDesc('date_desc'),
  dateAsc('date_asc'),
  popularDesc('popular_desc');

  const PixivSearchSort(this.value);

  final String value;
}
