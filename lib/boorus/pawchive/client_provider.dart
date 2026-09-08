// Package imports:
import 'package:booru_clients/pawchive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/configs/config/types.dart';
import '../../core/http/client/providers.dart';

final pawchiveClientProvider = Provider.family<PawchiveClient, BooruConfigAuth>(
  (ref, config) {
    final dio = ref.watch(defaultDioProvider(config));

    return PawchiveClient(
      dio: dio,
      baseUrl: config.url,
    );
  },
);
