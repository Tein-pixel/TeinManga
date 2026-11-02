import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color bg = Color(0xFF101010);
const Color panel = Color(0xFF1A1A1A);
const Color panel2 = Color(0xFF242424);
const Color accent = Color(0xFF00D084);
const Color ink = Color(0xFFF7F7F7);
const Color muted = Color(0xFF9A9A9A);
const Color stroke = Color(0xFF303030);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 60;
  imageCache.maximumSizeBytes = 32 * 1024 * 1024;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: bg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ManhwaKuApp());
}

class ManhwaKuApp extends StatelessWidget {
  const ManhwaKuApp({super.key, this.testMode = false});
  final bool testMode;

  @override
  Widget build(BuildContext context) {
    CatalogApi.testMode = testMode;
    return MaterialApp(
      title: 'ManhwaKu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        fontFamily: 'sans-serif',
      ),
      home: const AppShell(),
    );
  }
}


class SeriesItem {
  const SeriesItem({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    required this.cover,
    required this.description,
    required this.status,
    required this.rating,
    required this.author,
    required this.language,
    required this.contentRating,
    this.source = 'MangaBaka',
    this.availableTranslatedLanguages = const <String>[],
    this.mangaBakaId,
  });

  final int id;
  final String title;
  final String type;
  final String url;
  final String cover;
  final String description;
  final String status;
  final double? rating;
  final String author;
  final String language;
  final String contentRating;
  final String source;
  final List<String> availableTranslatedLanguages;
  final int? mangaBakaId;

  factory SeriesItem.fromJson(Map<String, dynamic> json) {
    final coverData = json['cover'] is Map
        ? Map<String, dynamic>.from(json['cover'] as Map)
        : <String, dynamic>{};
    final x350 = coverData['x350'] is Map
        ? Map<String, dynamic>.from(coverData['x350'] as Map)
        : <String, dynamic>{};
    final x250 = coverData['x250'] is Map
        ? Map<String, dynamic>.from(coverData['x250'] as Map)
        : <String, dynamic>{};
    final raw = coverData['raw'] is Map
        ? Map<String, dynamic>.from(coverData['raw'] as Map)
        : <String, dynamic>{};
    final cover = _firstText([
      x350['x2'],
      x350['x1'],
      x250['x2'],
      x250['x1'],
      raw['url'],
    ]);
    final authors = json['authors'] is List ? json['authors'] as List : const [];
    final ratingValue = json['rating'];
    return SeriesItem(
      id: _toInt(json['id']),
      title: _firstText([
        json['title'],
        json['romanized_title'],
        json['native_title'],
        'Tanpa judul',
      ]),
      type: _firstText([json['type'], 'other']),
      url: _firstText([json['canonical_url'], 'https://mangabaka.org/']),
      cover: cover,
      description: _firstText([json['description'], 'Deskripsi belum tersedia.']),
      status: _firstText([json['status'], 'unknown']),
      rating: ratingValue is num ? ratingValue.toDouble() : null,
      author: authors.map((e) => e.toString()).where((e) => e.isNotEmpty).take(2).join(', '),
      language: _firstText([json['original_language'], 'unknown']),
      contentRating: _firstText([json['content_rating'], 'safe']),
      source: 'MangaBaka',
    );
  }



  factory SeriesItem.fromMangaBakaV2(Map<String, dynamic> json) {
    final language = _firstText([json['original_language'], 'unknown']);
    final rows = (json['titles'] is List ? json['titles'] as List : const [])
        .whereType<Map>()
        .toList();

    String titleFor(String code, {bool primaryOnly = false}) {
      for (final row in rows) {
        if (row['language']?.toString().toLowerCase() != code.toLowerCase()) continue;
        if (primaryOnly && row['is_primary'] != true) continue;
        final value = _firstText([row['title']]);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final coverData = json['cover'] is Map
        ? Map<String, dynamic>.from(json['cover'] as Map)
        : <String, dynamic>{};
    String coverValue(String key) {
      final value = coverData[key];
      if (value is String) return value;
      if (value is Map) return _firstText([value['x2'], value['x1'], value['url']]);
      return '';
    }

    final authors = json['authors'] is List ? json['authors'] as List : const [];
    final authorNames = authors.map((entry) => entry is Map
        ? _firstText([entry['name'], entry['title']])
        : entry.toString()).where((name) => name.trim().isNotEmpty).take(2).join(', ');
    final ratingValue = json['rating'];
    final hasRestrictedTags = _hasRestrictedTags(json['tags']);

    return SeriesItem(
      id: _toInt(json['id']),
      title: _firstText([
        titleFor('en', primaryOnly: true),
        titleFor('en'),
        titleFor(language, primaryOnly: true),
        titleFor(language),
        ...rows.where((row) => row['is_primary'] == true).map((row) => row['title']),
        json['title'],
        'Tanpa judul',
      ]),
      type: _firstText([json['type'], 'other']).toLowerCase(),
      url: _firstText([json['canonical_url'], 'https://mangabaka.org/']),
      cover: _firstText([
        coverValue('x350'),
        coverValue('x250'),
        coverValue('x150'),
        coverValue('raw'),
      ]),
      description: _firstText([json['description'], 'Deskripsi belum tersedia.']),
      status: _firstText([json['status'], json['state'], 'unknown']),
      rating: ratingValue is num ? ratingValue.toDouble() : null,
      author: authorNames,
      language: language,
      contentRating: hasRestrictedTags ? 'blocked' : _firstText([json['content_rating'], 'safe']),
      source: 'MangaBaka',
      mangaBakaId: _toInt(json['id']) > 0 ? _toInt(json['id']) : null,
    );
  }

  factory SeriesItem.fromJikan(Map<String, dynamic> json) {
    final authors = json['authors'] is List ? json['authors'] as List : const [];
    final images = json['images'] is Map
        ? Map<String, dynamic>.from(json['images'] as Map)
        : <String, dynamic>{};
    final webp = images['webp'] is Map
        ? Map<String, dynamic>.from(images['webp'] as Map)
        : <String, dynamic>{};
    final jpg = images['jpg'] is Map
        ? Map<String, dynamic>.from(images['jpg'] as Map)
        : <String, dynamic>{};
    final score = json['score'];
    final type = _firstText([json['type'], 'manga']).toLowerCase();
    return SeriesItem(
      id: 1000000000 + _toInt(json['mal_id']),
      title: _firstText([json['title'], json['title_english'], 'Tanpa judul']),
      type: type,
      url: _firstText([json['url'], 'https://myanimelist.net/']),
      cover: _firstText([
        webp['large_image_url'],
        webp['image_url'],
        jpg['large_image_url'],
        jpg['image_url'],
      ]),
      description: _firstText([json['synopsis'], 'Deskripsi belum tersedia.']),
      status: _firstText([json['status'], 'unknown']),
      rating: score is num ? score.toDouble() * 10 : null,
      author: authors
          .whereType<Map>()
          .map((author) => _firstText([author['name']]))
          .where((name) => name.isNotEmpty)
          .take(2)
          .join(', '),
      language: 'ja',
      contentRating: 'safe',
      source: 'Jikan / MyAnimeList',
    );
  }

  factory SeriesItem.fromMangaDex(Map<String, dynamic> json) {
    final attributes = json['attributes'] is Map
        ? Map<String, dynamic>.from(json['attributes'] as Map)
        : <String, dynamic>{};
    final relationships = json['relationships'] is List
        ? json['relationships'] as List
        : const [];
    final titles = attributes['title'] is Map
        ? Map<String, dynamic>.from(attributes['title'] as Map)
        : <String, dynamic>{};
    final descriptions = attributes['description'] is Map
        ? Map<String, dynamic>.from(attributes['description'] as Map)
        : <String, dynamic>{};
    final language = _firstText([attributes['originalLanguage'], 'unknown']);
    final type = language == 'ko'
        ? 'manhwa'
        : language == 'zh' || language == 'zh-hk' || language == 'zh-mo'
            ? 'manhua'
            : language == 'ja'
                ? 'manga'
                : 'other';

    String coverFile = '';
    final authors = <String>[];
    for (final relation in relationships.whereType<Map>()) {
      final relationType = relation['type']?.toString();
      final relationAttributes = relation['attributes'] is Map
          ? Map<String, dynamic>.from(relation['attributes'] as Map)
          : <String, dynamic>{};
      if (relationType == 'cover_art') {
        coverFile = _firstText([relationAttributes['fileName']]);
      } else if (relationType == 'author') {
        final name = _firstText([relationAttributes['name']]);
        if (name.isNotEmpty) authors.add(name);
      }
    }

    final id = _firstText([json['id']]);
    final cover = coverFile.isEmpty ? '' :
        'https://uploads.mangadex.org/covers/$id/$coverFile.256.jpg';
    final hasRestrictedTags = _hasRestrictedTags(attributes['tags']);
    final availableLanguages = attributes['availableTranslatedLanguages'] is List
        ? (attributes['availableTranslatedLanguages'] as List)
            .whereType<String>()
            .map((value) => value.toLowerCase())
            .where((value) => RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(value))
            .toSet()
            .toList()
        : <String>[];

    return SeriesItem(
      id: _stableId('mangadex:$id'),
      title: _firstText([
        titles['en'],
        titles[language],
        titles['ja-ro'],
        titles['ko-ro'],
        titles['zh-ro'],
        ...titles.values,
        'Tanpa judul',
      ]),
      type: type,
      url: id.isEmpty ? 'https://mangadex.org/' : 'https://mangadex.org/title/$id',
      cover: cover,
      description: _firstText([
        descriptions['en'],
        descriptions['id'],
        descriptions[language],
        ...descriptions.values,
        'Deskripsi belum tersedia.',
      ]),
      status: _firstText([attributes['status'], 'unknown']),
      rating: null,
      author: authors.take(2).join(', '),
      language: language,
      contentRating: hasRestrictedTags ? 'blocked' : (attributes['contentRating']?.toString() ?? 'safe'),
      source: 'MangaDex',
      availableTranslatedLanguages: availableLanguages,
    );
  }

  factory SeriesItem.fromMap(Map<String, dynamic> json) => SeriesItem(
        id: _toInt(json['id']),
        title: _firstText([json['title'], 'Tanpa judul']),
        type: _firstText([json['type'], 'other']),
        url: _firstText([json['url'], 'https://mangabaka.org/']),
        cover: _firstText([json['cover']]),
        description: _firstText([json['description']]),
        status: _firstText([json['status']]),
        rating: json['rating'] is num ? (json['rating'] as num).toDouble() : null,
        author: _firstText([json['author']]),
        language: _firstText([json['language']]),
        contentRating: _firstText([json['contentRating'], 'safe']),
        source: _firstText([json['source'], 'MangaBaka']),
        availableTranslatedLanguages: (json['availableTranslatedLanguages'] as List?)
            ?.whereType<String>().toList() ?? const <String>[],
        mangaBakaId: json['mangaBakaId'] is num ? (json['mangaBakaId'] as num).toInt() : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'url': url,
        'cover': cover,
        'description': description,
        'status': status,
        'rating': rating,
        'author': author,
        'language': language,
        'contentRating': contentRating,
        'source': source,
        'availableTranslatedLanguages': availableTranslatedLanguages,
        'mangaBakaId': mangaBakaId,
      };
}

String _firstText(List<dynamic> values) {
  for (final value in values) {
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _stableId(String value) {
  var hash = 5381;
  for (final unit in value.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
    hash &= 0x3fffffff;
  }
  return 1500000000 + hash;
}

bool _hasRestrictedTags(dynamic raw) {
  if (raw is! List) return false;
  const blocked = {
    'ecchi', 'hentai', 'erotica', 'adult', 'mature',
    'gore', 'graphic violence', 'sexual violence', 'sexual abuse',
  };

  String normalize(dynamic value) {
    if (value is Map) {
      return value.values.map((entry) => entry.toString().toLowerCase()).join(' ');
    }
    return value?.toString().toLowerCase() ?? '';
  }

  for (final item in raw) {
    if (item is Map) {
      final attributes = item['attributes'] is Map
          ? Map<String, dynamic>.from(item['attributes'] as Map)
          : <String, dynamic>{};
      final name = normalize(
        attributes['name'] ?? item['name'] ?? item['title'] ?? item['tag'],
      );
      final rating = _firstText([
        attributes['contentRating'],
        item['content_rating'],
        item['contentRating'],
      ]).toLowerCase();
      if (const {'suggestive', 'erotica', 'pornographic'}.contains(rating)) return true;
      if (blocked.any(name.contains)) return true;
    } else {
      final name = normalize(item);
      if (blocked.any(name.contains)) return true;
    }
  }
  return false;
}

String typeLabel(String value) {
  switch (value.toLowerCase()) {
    case 'manga':
      return 'Manga';
    case 'manhwa':
      return 'Manhwa';
    case 'manhua':
      return 'Manhua';
    case 'novel':
      return 'Novel';
    case 'oel':
      return 'Komik original';
    case 'lightnovel':
      return 'Light Novel';
    case 'webtoon':
      return 'Webtoon';
    default:
      return 'Komik';
  }
}

String readingStatusLabel(String value) {
  switch (value) {
    case 'reading':
      return 'Sedang dibaca';
    case 'planned':
      return 'Rencana baca';
    case 'completed':
      return 'Selesai';
    case 'dropped':
      return 'Dihentikan';
    default:
      return 'Belum diatur';
  }
}

String statusLabel(String value) {
  switch (value.toLowerCase()) {
    case 'releasing':
      return 'Berjalan';
    case 'completed':
      return 'Tamat';
    case 'hiatus':
      return 'Hiatus';
    case 'upcoming':
      return 'Segera hadir';
    case 'cancelled':
      return 'Dibatalkan';
    default:
      return 'Status tidak diketahui';
  }
}

class _CatalogCacheEntry {
  const _CatalogCacheEntry(this.items, this.savedAt);
  final List<SeriesItem> items;
  final DateTime savedAt;
}

class CatalogApi {
  static bool testMode = false;
  static final http.Client _client = http.Client();
  static const int pageSize = 24;
  static const int _providerPageSize = 12;
  static const Duration _providerTimeout = Duration(seconds: 7);
  static const Duration _memoryTtl = Duration(minutes: 4);
  static const Duration _diskMaxAge = Duration(days: 5);
  static final Map<String, _CatalogCacheEntry> _cache = {};
  static final Map<String, Future<List<SeriesItem>>> _inFlight = {};

  static String _diskKey(String cacheKey) =>
      'catalog_cache_' + _stableId(cacheKey).toString();

  static Future<List<SeriesItem>?> _readDiskCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskKey(cacheKey));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['items'] is! List) return null;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(_toInt(decoded['savedAt']));
      if (DateTime.now().difference(savedAt) > _diskMaxAge) return null;
      return (decoded['items'] as List)
          .whereType<Map>()
          .map((row) => SeriesItem.fromMap(Map<String, dynamic>.from(row)))
          .where((item) => item.id > 0 && item.contentRating == 'safe')
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeDiskCache(String cacheKey, List<SeriesItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _diskKey(cacheKey);
      await prefs.setString(
        key,
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'items': items.map((item) => item.toMap()).toList(),
        }),
      );
      final index = prefs.getStringList('catalog_cache_index') ?? <String>[];
      index.remove(key);
      index.insert(0, key);
      const maxEntries = 12;
      final removed = index.skip(maxEntries).toList();
      await prefs.setStringList('catalog_cache_index', index.take(maxEntries).toList());
      for (final oldKey in removed) {
        await prefs.remove(oldKey);
      }
    } catch (_) {
      // Disk cache is an optimization; storage failure must not break requests.
    }
  }

  static Future<List<SeriesItem>> fetch({
    String? query,
    List<String> types = const [],
    String sortBy = 'trending_7d',
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (testMode) return const <SeriesItem>[];
    final cleanQuery = (query ?? '').trim();
    final normalizedTypes = types.map((value) => value.toLowerCase()).toList()..sort();
    final cacheKey = '${cleanQuery.toLowerCase()}|${normalizedTypes.join(",")}|${sortBy}|${page}';

    if (!forceRefresh) {
      final memory = _cache[cacheKey];
      if (memory != null && DateTime.now().difference(memory.savedAt) < _memoryTtl) {
        return memory.items;
      }
      final diskItems = await _readDiskCache(cacheKey);
      if (diskItems != null) {
        final entry = _CatalogCacheEntry(
          List<SeriesItem>.unmodifiable(diskItems),
          DateTime.now(),
        );
        _cache[cacheKey] = entry;
        unawaited(_refreshInBackground(
          cacheKey: cacheKey,
          query: cleanQuery,
          types: types,
          sortBy: sortBy,
          page: page,
        ));
        return entry.items;
      }
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;
    final request = _fetchRemote(
      cacheKey: cacheKey,
      query: cleanQuery,
      types: types,
      sortBy: sortBy,
      page: page,
    );
    _inFlight[cacheKey] = request;
    try {
      return await request;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static Future<void> _refreshInBackground({
    required String cacheKey,
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) async {
    if (_inFlight.containsKey(cacheKey)) return;
    final request = _fetchRemote(
      cacheKey: cacheKey,
      query: query,
      types: types,
      sortBy: sortBy,
      page: page,
    );
    _inFlight[cacheKey] = request;
    try {
      await request;
    } catch (_) {
      // Keep cached results when network refresh fails.
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static Future<List<SeriesItem>> _fetchRemote({
    required String cacheKey,
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) async {
    var successCount = 0;
    Future<List<SeriesItem>> attempt(Future<List<SeriesItem>> Function() request) async {
      try {
        final result = await request();
        successCount++;
        return result;
      } catch (_) {
        return const <SeriesItem>[];
      }
    }

    // Two documented catalogue sources run concurrently. Jikan is deliberately
    // not on the first-load path because its public API is rate-limited.
    final batches = await Future.wait<List<SeriesItem>>([
      attempt(() => _fetchMangaDex(query: query, types: types, sortBy: sortBy, page: page)),
      attempt(() => _fetchMangaBakaV2(query: query, types: types, sortBy: sortBy, page: page)),
    ]);

    if (successCount == 0) {
      throw Exception('Sumber katalog tidak merespons. Data tersimpan tetap dapat dibuka; coba segarkan lagi.');
    }

    final merged = <SeriesItem>[];
    final byTitle = <String, int>{};
    final seenIds = <int>{};

    for (final batch in batches) {
      for (final item in batch) {
        if (item.id <= 0 || item.title.isEmpty || item.contentRating != 'safe') continue;
        final normalized = item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (normalized.isEmpty) continue;
        final existingIndex = byTitle[normalized];

        if (existingIndex != null) {
          final existing = merged[existingIndex];
          final useIncoming = existing.source != 'MangaDex' && item.source == 'MangaDex';
          final primary = useIncoming ? item : existing;
          final supplement = useIncoming ? existing : item;
          merged[existingIndex] = SeriesItem(
            id: primary.id,
            title: primary.title,
            type: primary.type,
            url: primary.url,
            cover: primary.cover.isNotEmpty ? primary.cover : supplement.cover,
            description: primary.description.isNotEmpty &&
                    primary.description != 'Deskripsi belum tersedia.'
                ? primary.description
                : supplement.description,
            status: primary.status == 'unknown' ? supplement.status : primary.status,
            rating: primary.rating ?? supplement.rating,
            author: primary.author.isNotEmpty ? primary.author : supplement.author,
            language: primary.language == 'unknown' ? supplement.language : primary.language,
            contentRating: primary.contentRating,
            source: primary.source,
            availableTranslatedLanguages:
                primary.availableTranslatedLanguages.isNotEmpty
                    ? primary.availableTranslatedLanguages
                    : supplement.availableTranslatedLanguages,
            mangaBakaId: primary.mangaBakaId ?? supplement.mangaBakaId,
          );
          seenIds.add(item.id);
          continue;
        }
        if (seenIds.add(item.id)) {
          byTitle[normalized] = merged.length;
          merged.add(item);
        }
      }
    }

    final immutable = List<SeriesItem>.unmodifiable(merged);
    _cache[cacheKey] = _CatalogCacheEntry(immutable, DateTime.now());
    if (_cache.length > 80) _cache.remove(_cache.keys.first);
    await _writeDiskCache(cacheKey, immutable);
    return immutable;
  }

  static Future<List<SeriesItem>> _fetchMangaBakaV2({
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) async {
    if (types.contains('webtoon')) return const <SeriesItem>[];
    final params = <String>['content_rating=safe', 'limit=$_providerPageSize', 'page=$page'];
    if (query.isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(query)}');
    } else {
      final safeSort = sortBy == 'latest' ? 'latest' : 'trending_7d';
      params.add('sort_by=$safeSort');
    }
    for (final type in types) {
      final apiType = type == 'lightnovel' ? 'novel' : type;
      if (const {'manga', 'manhwa', 'manhua', 'novel', 'oel', 'other'}.contains(apiType)) {
        params.add('type=${Uri.encodeQueryComponent(apiType)}');
      }
    }

    final uri = Uri.parse('https://api.mangabaka.org/v2/series/search?${params.join('&')}');
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.6 Android',
        })
        .timeout(_providerTimeout);
    if (response.statusCode != 200) {
      throw Exception('MangaBaka HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format MangaBaka v2 tidak dikenali.');
    }
    return (decoded['data'] as List)
        .whereType<Map>()
        .map((row) => SeriesItem.fromMangaBakaV2(Map<String, dynamic>.from(row)))
        .where((item) => item.id > 0 && item.contentRating == 'safe')
        .toList();
  }

  static Future<List<SeriesItem>> _fetchMangaDex({
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) async {
    final params = <String>[
      'limit=$_providerPageSize',
      'offset=${(page - 1) * _providerPageSize}',
      'contentRating%5B%5D=safe',
      'includes%5B%5D=cover_art',
      'includes%5B%5D=author',
    ];
    if (query.isNotEmpty) {
      params.add('title=${Uri.encodeQueryComponent(query)}');
      params.add('order%5Brelevance%5D=desc');
    } else if (sortBy == 'latest') {
      params.add('order%5BlatestUploadedChapter%5D=desc');
    } else {
      params.add('order%5BfollowedCount%5D=desc');
    }

    final languages = <String>{};
    final isWebtoon = types.contains('webtoon');
    if (types.isEmpty || isWebtoon) {
      languages.addAll({'ja', 'ko', 'zh'});
    } else {
      if (types.contains('manga')) languages.add('ja');
      if (types.contains('manhwa')) languages.add('ko');
      if (types.contains('manhua')) languages.add('zh');
    }
    for (final language in languages) {
      params.add('originalLanguage%5B%5D=$language');
    }
    if (isWebtoon) {
      params.add('includedTags%5B%5D=e197df38-d0e7-43b5-9b09-2842d0c326dd');
    }
    if (languages.isEmpty) return const <SeriesItem>[];

    final uri = Uri.parse('https://api.mangadex.org/manga?${params.join('&')}');
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.6 (Android; safe-catalog)',
        })
        .timeout(_providerTimeout);
    if (response.statusCode != 200) {
      throw Exception('MangaDex HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format MangaDex tidak dikenali.');
    }
    return (decoded['data'] as List)
        .whereType<Map>()
        .map((row) => SeriesItem.fromMangaDex(Map<String, dynamic>.from(row)))
        .where((item) => item.id > 0 && item.contentRating == 'safe')
        .toList();
  }
}

class MangaBakaDetailsApi {
  static final http.Client _client = http.Client();
  static final Map<int, SeriesItem> _cache = {};
  static final Map<int, Future<SeriesItem?>> _inFlight = {};
  static final Map<String, Future<SeriesItem?>> _titleLookups = {};

  static String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Future<SeriesItem?> fetchForItem(SeriesItem item) async {
    final id = item.mangaBakaId ??
        (item.source == 'MangaBaka' ? item.id : null);
    if (id != null && id > 0) return fetch(id);
    return findByTitle(item.title);
  }

  static Future<SeriesItem?> findByTitle(String title) async {
    final query = title.trim();
    if (query.length < 2 || query.length > 100) return null;
    final key = _normalizeTitle(query);
    final existing = _titleLookups[key];
    if (existing != null) return existing;

    final request = _searchAndFetch(query);
    _titleLookups[key] = request;
    try {
      return await request;
    } finally {
      _titleLookups.remove(key);
    }
  }

  static Future<SeriesItem?> _searchAndFetch(String title) async {
    try {
      final uri = Uri.https(
        'api.mangabaka.org',
        '/v2/series/search',
        {
          'q': title,
          'content_rating': 'safe',
          'limit': '8',
        },
      );
      final response = await _client
          .get(uri, headers: const {
            'Accept': 'application/json',
            'User-Agent': 'ManhwaKu/2.6 Android',
          })
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['data'] is! List) return null;

      final target = _normalizeTitle(title);
      final candidates = <Map<String, dynamic>>[];
      for (final row in (decoded['data'] as List).whereType<Map>()) {
        final data = Map<String, dynamic>.from(row);
        if (_hasRestrictedTags(data['tags'])) continue;
        final titles = data['titles'] is List
            ? (data['titles'] as List).whereType<Map>()
            : const <Map>[];
        final normalizedTitles = <String>[
          _normalizeTitle(_firstText([data['title']])),
          _normalizeTitle(_firstText([data['romanized_title']])),
          _normalizeTitle(_firstText([data['native_title']])),
          ...titles.map((entry) => _normalizeTitle(_firstText([entry['title']]))),
        ].where((value) => value.isNotEmpty).toList();

        final matched = normalizedTitles.any((candidate) {
          if (candidate == target) return true;
          if (candidate.length < 5 || target.length < 5) return false;
          return candidate.startsWith(target) || target.startsWith(candidate);
        });
        if (matched) candidates.add(data);
      }

      if (candidates.isEmpty) return null;
      candidates.sort((left, right) {
        final leftId = _toInt(left['id']);
        final rightId = _toInt(right['id']);
        final leftTitles = left['titles'] is List ? left['titles'] as List : const [];
        final rightTitles = right['titles'] is List ? right['titles'] as List : const [];
        final leftHasEnglish = leftTitles.whereType<Map>().any(
          (entry) => entry['language'] == 'en' && entry['is_primary'] == true,
        );
        final rightHasEnglish = rightTitles.whereType<Map>().any(
          (entry) => entry['language'] == 'en' && entry['is_primary'] == true,
        );
        if (leftHasEnglish != rightHasEnglish) {
          return leftHasEnglish ? -1 : 1;
        }
        return leftId.compareTo(rightId);
      });

      final matchedId = _toInt(candidates.first['id']);
      return matchedId > 0 ? await fetch(matchedId) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<SeriesItem?> fetch(int id) async {
    if (id <= 0) return null;
    final cached = _cache[id];
    if (cached != null) return cached;
    final existing = _inFlight[id];
    if (existing != null) return existing;

    final request = _fetch(id);
    _inFlight[id] = request;
    try {
      final result = await request;
      if (result != null) _cache[id] = result;
      return result;
    } finally {
      _inFlight.remove(id);
    }
  }

  static Future<SeriesItem?> _fetch(int id) async {
    try {
      final uri = Uri.https(
        'api.mangabaka.org',
        '/v2/series/$id',
        const {'schema': 'full'},
      );
      final response = await _client
          .get(uri, headers: const {
            'Accept': 'application/json',
            'User-Agent': 'ManhwaKu/2.6 Android',
          })
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final raw = decoded['data'] is Map ? decoded['data'] : decoded;
      if (raw is! Map) return null;
      final data = Map<String, dynamic>.from(raw);
      final item = SeriesItem.fromMangaBakaV2(data);
      if (item.id <= 0 || item.contentRating != 'safe') return null;
      return item;
    } catch (_) {
      return null;
    }
  }
}

class MangaDexChapter {
  const MangaDexChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.volume,
    required this.pageCount,
    required this.scanlationGroup,
    required this.language,
  });

  final String id;
  final String number;
  final String title;
  final String volume;
  final int pageCount;
  final String scanlationGroup;
  final String language;

  factory MangaDexChapter.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] is Map
        ? Map<String, dynamic>.from(json['attributes'] as Map)
        : <String, dynamic>{};
    final relations = json['relationships'] is List
        ? json['relationships'] as List
        : const [];
    var group = '';
    for (final relation in relations.whereType<Map>()) {
      if (relation['type'] == 'scanlation_group') {
        final data = relation['attributes'] is Map
            ? Map<String, dynamic>.from(relation['attributes'] as Map)
            : <String, dynamic>{};
        group = _firstText([data['name']]);
        if (group.isNotEmpty) break;
      }
    }
    return MangaDexChapter(
      id: _firstText([json['id']]),
      number: _firstText([attributes['chapter'], 'Oneshot']),
      title: _firstText([attributes['title']]),
      volume: _firstText([attributes['volume']]),
      pageCount: _toInt(attributes['pages']),
      scanlationGroup: group,
      language: _firstText([attributes['translatedLanguage']]),
    );
  }
}

class MangaDexChapterApi {
  static final http.Client _client = http.Client();
  static const Duration _chapterCacheTtl = Duration(minutes: 2);
  static final Map<String, List<MangaDexChapter>> _chapterCache = {};
  static final Map<String, DateTime> _chapterCacheTime = {};
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Future<List<MangaDexChapter>> fetchChapters(
    String mangaId, {
    String language = 'id',
    int offset = 0,
  }) async {
    if (!_uuid.hasMatch(mangaId)) {
      throw const FormatException('ID MangaDex tidak valid.');
    }
    final normalizedLanguage = language.toLowerCase();
    if (!RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(normalizedLanguage)) {
      throw const FormatException('Kode bahasa chapter tidak valid.');
    }
    if (offset < 0) {
      throw const FormatException('Offset chapter tidak valid.');
    }

    final cacheKey = mangaId + '|' + normalizedLanguage + '|' + offset.toString();
    final cached = _chapterCache[cacheKey];
    final cacheTime = _chapterCacheTime[cacheKey];
    if (cached != null &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) < _chapterCacheTtl) {
      return cached;
    }

    final uri = Uri.parse(
      'https://api.mangadex.org/manga/' + mangaId +
      '/feed?limit=100&offset=' + offset.toString() +
      '&translatedLanguage%5B%5D=' + Uri.encodeQueryComponent(normalizedLanguage) +
      '&contentRating%5B%5D=safe&includes%5B%5D=scanlation_group' +
      '&order%5Bvolume%5D=desc&order%5Bchapter%5D=desc',
    );
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.6 (safe reader)',
        })
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception(
        'MangaDex gagal memuat chapter (' + response.statusCode.toString() + ').',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format daftar chapter tidak dikenali.');
    }

    final chapters = (decoded['data'] as List)
        .whereType<Map>()
        .map((row) => MangaDexChapter.fromJson(Map<String, dynamic>.from(row)))
        .where((chapter) => chapter.id.isNotEmpty && chapter.pageCount > 0)
        .toList();
    _chapterCache[cacheKey] = chapters;
    _chapterCacheTime[cacheKey] = DateTime.now();
    if (_chapterCache.length > 40) {
      final oldestKey = _chapterCache.keys.first;
      _chapterCache.remove(oldestKey);
      _chapterCacheTime.remove(oldestKey);
    }
    return chapters;
  }

  static Future<List<String>> fetchPages(
    String chapterId, {
    bool dataSaver = true,
  }) async {
    if (!_uuid.hasMatch(chapterId)) {
      throw const FormatException('ID chapter tidak valid.');
    }
    final uri = Uri.https('api.mangadex.org', '/at-home/server/' + chapterId);
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.6 (safe reader)',
        })
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Server gambar tidak tersedia (' + response.statusCode.toString() + ').',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['chapter'] is! Map) {
      throw const FormatException('Data chapter tidak dikenali.');
    }
    final chapter = Map<String, dynamic>.from(decoded['chapter'] as Map);
    final baseUrl = _firstText([decoded['baseUrl']]);
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || baseUri.scheme != 'https' || baseUrl.isEmpty) {
      throw const FormatException('Alamat gambar chapter tidak aman.');
    }

    final hash = _firstText([chapter['hash']]);
    final rawFiles = dataSaver ? chapter['dataSaver'] : chapter['data'];
    if (hash.isEmpty || rawFiles is! List || rawFiles.isEmpty) {
      throw const FormatException('Halaman chapter tidak tersedia.');
    }

    final quality = dataSaver ? 'data-saver' : 'data';
    return rawFiles
        .whereType<String>()
        .map((file) => baseUrl + '/' + quality + '/' + hash + '/' + Uri.encodeComponent(file))
        .toList();
  }
}

class MangaDexChapterPage extends StatefulWidget {
  const MangaDexChapterPage({
    super.key,
    required this.item,
    required this.mangaId,
  });

  final SeriesItem item;
  final String mangaId;

  @override
  State<MangaDexChapterPage> createState() => _MangaDexChapterPageState();
}

class _MangaDexChapterPageState extends State<MangaDexChapterPage> {
  static const int _pageSize = 100;
  late String _language;
  final List<MangaDexChapter> _chapters = [];
  int _requestId = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  List<String> get _availableLanguages {
    final languages = <String>[];
    for (final value in widget.item.availableTranslatedLanguages) {
      final normalized = value.toLowerCase();
      if (RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(normalized) &&
          !languages.contains(normalized)) {
        languages.add(normalized);
      }
    }
    final original = widget.item.language.toLowerCase();
    if (original != 'unknown' &&
        RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(original) &&
        !languages.contains(original)) {
      languages.add(original);
    }
    if (languages.isEmpty) return const ['id', 'en', 'ko', 'ja', 'zh'];
    return languages;
  }

  String _initialLanguage() {
    final languages = _availableLanguages;
    if (languages.contains('id')) return 'id';
    if (languages.contains(widget.item.language.toLowerCase())) {
      return widget.item.language.toLowerCase();
    }
    if (languages.contains('en')) return 'en';
    return languages.first;
  }

  @override
  void initState() {
    super.initState();
    _language = _initialLanguage();
    _load(reset: true, allowAutoFallback: true);
  }

  Future<void> _load({
    bool reset = false,
    bool allowAutoFallback = false,
  }) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) return;
    final request = ++_requestId;
    final offset = reset ? 0 : _chapters.length;
    setState(() {
      if (reset) {
        _chapters.clear();
        _loading = true;
        _loadingMore = false;
        _hasMore = false;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });

    try {
      var resolvedLanguage = _language;
      var fetched = await MangaDexChapterApi.fetchChapters(
        widget.mangaId,
        language: resolvedLanguage,
        offset: offset,
      );

      // On the first open only, an empty selected-language feed tries the
      // original language and English from the title's published translations.
      if (reset && allowAutoFallback && fetched.isEmpty) {
        final candidates = <String>[];
        final preferred = [
          widget.item.language.toLowerCase(),
          'en',
          'id',
        ];
        for (final language in preferred) {
          if (language != resolvedLanguage &&
              _availableLanguages.contains(language) &&
              !candidates.contains(language)) {
            candidates.add(language);
          }
        }

        final fallbackResults = await Future.wait(
          candidates.take(2).map((language) async {
            try {
              final chapters = await MangaDexChapterApi.fetchChapters(
                widget.mangaId,
                language: language,
                offset: 0,
              );
              return MapEntry(language, chapters);
            } catch (_) {
              return MapEntry(language, const <MangaDexChapter>[]);
            }
          }),
        );

        for (final result in fallbackResults) {
          if (result.value.isNotEmpty) {
            resolvedLanguage = result.key;
            fetched = result.value;
            break;
          }
        }
      }

      if (!mounted || request != _requestId) return;
      setState(() {
        _language = resolvedLanguage;
        final seen = _chapters.map((chapter) => chapter.id).toSet();
        for (final chapter in fetched) {
          if (seen.add(chapter.id)) _chapters.add(chapter);
        }
        _hasMore = fetched.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _changeLanguage(String language) {
    if (!_availableLanguages.contains(language)) return;
    setState(() => _language = language);
    _load(reset: true);
  }

  void _openChapter(MangaDexChapter chapter) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MangaDexReaderPage(item: widget.item, chapter: chapter),
      ),
    );
  }

  String _languageLabel(String code) {
    const labels = {
      'id': 'Indonesia',
      'en': 'English',
      'ko': '한국어',
      'ja': '日本語',
      'zh': '中文',
      'zh-hk': '中文 (Hong Kong)',
      'zh-mo': '中文 (Macau)',
      'es': 'Español',
      'es-la': 'Español (LatAm)',
      'pt-br': 'Português (Brasil)',
    };
    return labels[code] ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Daftar chapter'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Bahasa chapter',
              initialValue: _language,
              onSelected: _changeLanguage,
              itemBuilder: (context) => _availableLanguages
                  .map((language) => PopupMenuItem(
                        value: language,
                        child: Text(_languageLabel(language)),
                      ))
                  .toList(),
              icon: const Icon(Icons.translate_rounded),
            ),
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: () => _load(reset: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading && _chapters.isEmpty
            ? const Center(child: CircularProgressIndicator(color: accent))
            : _error != null && _chapters.isEmpty
                ? ErrorPanel(
                    title: 'Chapter gagal dimuat',
                    message: _error!,
                    onRetry: () => _load(reset: true),
                  )
                : _chapters.isEmpty
                    ? ErrorPanel(
                        icon: Icons.menu_book_outlined,
                        title: 'Chapter belum ditemukan',
                        message: 'Tidak ada chapter berlabel aman dalam bahasa ' + _languageLabel(_language) + '. Coba bahasa lain yang tersedia pada menu bahasa.',
                        onRetry: () => _load(reset: true),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _chapters.length + (_hasMore || _loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(color: stroke, height: 1),
                        itemBuilder: (context, index) {
                          if (index >= _chapters.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator(color: accent)
                                    : TextButton.icon(
                                        onPressed: () => _load(),
                                        icon: const Icon(Icons.expand_more_rounded),
                                        label: const Text('Muat chapter lebih lama'),
                                      ),
                              ),
                            );
                          }
                          final chapter = _chapters[index];
                          final number = chapter.number.isEmpty
                              ? 'Chapter'
                              : 'Chapter ' + chapter.number;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: panel,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.menu_book_rounded, color: accent),
                            ),
                            title: Text(
                              chapter.title.isEmpty ? number : number + ' • ' + chapter.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              [
                                if (chapter.volume.isNotEmpty) 'Vol. ' + chapter.volume,
                                chapter.pageCount.toString() + ' halaman',
                                if (chapter.scanlationGroup.isNotEmpty)
                                  'Grup: ' + chapter.scanlationGroup,
                              ].join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: muted, fontSize: 10),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: accent),
                            onTap: () => _openChapter(chapter),
                          );
                        },
                      ),
      );
}

class MangaDexReaderPage extends StatefulWidget {
  const MangaDexReaderPage({
    super.key,
    required this.item,
    required this.chapter,
  });

  final SeriesItem item;
  final MangaDexChapter chapter;

  @override
  State<MangaDexReaderPage> createState() => _MangaDexReaderPageState();
}

class _MangaDexReaderPageState extends State<MangaDexReaderPage> {
  late Future<List<String>> _pages;
  late bool _verticalMode;
  bool _dataSaver = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _verticalMode = widget.item.type == 'manhwa' ||
        widget.item.type == 'webtoon';
    _pages = MangaDexChapterApi.fetchPages(
      widget.chapter.id,
      dataSaver: _dataSaver,
    );
  }

  void _reload() {
    setState(() {
      _pages = MangaDexChapterApi.fetchPages(
        widget.chapter.id,
        dataSaver: _dataSaver,
      );
    });
  }

  void _toggleQuality() {
    setState(() {
      _dataSaver = !_dataSaver;
      _currentPage = 0;
      _pages = MangaDexChapterApi.fetchPages(
        widget.chapter.id,
        dataSaver: _dataSaver,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              Text(
                'Chapter ${widget.chapter.number} • ${_currentPage + 1}',
                style: const TextStyle(color: muted, fontSize: 9),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: _verticalMode ? 'Mode halaman' : 'Mode scroll vertikal',
              onPressed: () => setState(() => _verticalMode = !_verticalMode),
              icon: Icon(
                _verticalMode
                    ? Icons.view_agenda_outlined
                    : Icons.chrome_reader_mode_outlined,
              ),
            ),
            IconButton(
              tooltip: _dataSaver
                  ? 'Kualitas gambar hemat data'
                  : 'Kualitas gambar tinggi',
              onPressed: _toggleQuality,
              icon: Icon(
                _dataSaver
                    ? Icons.data_saver_on_rounded
                    : Icons.high_quality_rounded,
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<String>>(
          future: _pages,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorPanel(
                title: 'Halaman gagal dimuat',
                message: 'Periksa koneksi atau coba lagi.',
                onRetry: _reload,
                retryLabel: 'Muat ulang',
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: accent),
              );
            }
            final pages = snapshot.data!;
            if (pages.isEmpty) {
              return const ErrorPanel(
                title: 'Chapter kosong',
                message: 'Tidak ada halaman yang tersedia untuk chapter ini.',
              );
            }
            if (_verticalMode) {
              return ListView.builder(
                itemCount: pages.length,
                itemBuilder: (context, index) => CachedNetworkImage(
                  imageUrl: pages[index],
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  memCacheWidth: 1280,
                  maxWidthDiskCache: 1280,
                  fadeInDuration: const Duration(milliseconds: 80),
                  placeholder: (_, __) => Container(
                    height: 120,
                    color: panel,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 150,
                    alignment: Alignment.center,
                    color: panel,
                    child: TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('Ulangi halaman ${index + 1}'),
                    ),
                  ),
                ),
              );
            }
            return PageView.builder(
              reverse: widget.item.language == 'ja',
              itemCount: pages.length,
              onPageChanged: (index) {
                if (mounted) setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: pages[index],
                    fit: BoxFit.contain,
                    memCacheWidth: 1280,
                    maxWidthDiskCache: 1280,
                    fadeInDuration: const Duration(milliseconds: 80),
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                      ),
                    ),
                    errorWidget: (_, __, ___) => TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba muat ulang'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
          child: SafeArea(
            top: false,
            child: Text(
              'Sumber: MangaDex • Grup: ${widget.chapter.scanlationGroup.isEmpty ? 'tidak tercantum' : widget.chapter.scanlationGroup}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 9),
            ),
          ),
        ),
      );
}


class LocalLibrary {
  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<List<SeriesItem>> read(String key) async {
    final raw = (await _prefs).getStringList(key) ?? <String>[];
    final items = <SeriesItem>[];
    for (final value in raw) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          items.add(SeriesItem.fromMap(decoded));
        }
      } catch (_) {}
    }
    return items;
  }

  static Future<void> _write(String key, List<SeriesItem> items) async {
    await (await _prefs).setStringList(
      key,
      items.map((item) => jsonEncode(item.toMap())).toList(),
    );
  }

  static Future<bool> toggleFavorite(SeriesItem item) async {
    final items = await read('favorites');
    final index = items.indexWhere((value) => value.id == item.id);
    final saved = index < 0;
    if (saved) {
      items.insert(0, item);
    } else {
      items.removeAt(index);
    }
    await _write('favorites', items.take(200).toList());
    return saved;
  }

  static Future<bool> isFavorite(int id) async {
    final items = await read('favorites');
    return items.any((item) => item.id == id);
  }

  static Future<void> addHistory(SeriesItem item) async {
    final items = await read('history');
    items.removeWhere((value) => value.id == item.id);
    items.insert(0, item);
    await _write('history', items.take(100).toList());
  }

  static Future<void> remove(String key, int id) async {
    final items = await read(key);
    items.removeWhere((item) => item.id == id);
    await _write(key, items);
  }

  static const List<String> readingStatusKeys = [
    'reading',
    'planned',
    'completed',
    'dropped',
  ];

  static Future<String> statusFor(int id) async {
    for (final key in readingStatusKeys) {
      final items = await read(key);
      if (items.any((item) => item.id == id)) return key;
    }
    return 'none';
  }

  static Future<void> setStatus(SeriesItem item, String status) async {
    for (final key in readingStatusKeys) {
      final items = await read(key);
      final filtered = items.where((entry) => entry.id != item.id).toList();
      if (filtered.length != items.length) await _write(key, filtered);
    }
    if (readingStatusKeys.contains(status)) {
      final items = await read(status);
      items.insert(0, item);
      await _write(status, items.take(200).toList());
    }
  }

  static Future<void> clear(String key) async {
    await (await _prefs).remove(key);
  }
}

typedef OpenSeries = Future<void> Function(SeriesItem item);

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    _screens = List<Widget?>.filled(5, null);
    _screens[0] = _buildScreen(0);
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return HomeTab(
          onOpen: _openSeries,
          onSearch: () => _selectTab(2),
          onExplore: () => _selectTab(1),
          onFavorites: () => _selectTab(3),
          onHistory: () => _selectTab(4),
        );
      case 1:
        return DiscoveryTab(onOpen: _openSeries);
      case 2:
        return SearchTab(onOpen: _openSeries);
      case 3:
        return LibraryTab(onOpen: _openSeries, mode: 'favorites');
      default:
        return LibraryTab(onOpen: _openSeries, mode: 'history');
    }
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() {
      _tab = index;
      _screens[index] ??= _buildScreen(index);
    });
  }

  Future<void> _openSeries(SeriesItem item) async {
    await LocalLibrary.addHistory(item);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SeriesDetailsPage(item: item)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          top: false,
          child: IndexedStack(
            index: _tab,
            children: _screens
                .map((screen) => screen ?? const SizedBox.shrink())
                .toList(),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: _selectTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: accent,
          unselectedItemColor: const Color(0xFF858585),
          selectedFontSize: 10,
          unselectedFontSize: 10,
          showUnselectedLabels: true,
          elevation: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_fire_department_outlined),
              activeIcon: Icon(Icons.local_fire_department_rounded),
              label: 'BARU & HOT',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'CARI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border_rounded),
              activeIcon: Icon(Icons.bookmark_rounded),
              label: 'KOLEKSI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'RIWAYAT',
            ),
          ],
        ),
      );
}

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.onOpen,
    required this.onSearch,
    required this.onExplore,
    required this.onFavorites,
    required this.onHistory,
  });

  final OpenSeries onOpen;
  final VoidCallback onSearch;
  final VoidCallback onExplore;
  final VoidCallback onFavorites;
  final VoidCallback onHistory;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<SeriesItem>> _trending;
  late Future<List<SeriesItem>> _latest;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool forceRefresh = false}) {
    _trending = CatalogApi.fetch(sortBy: 'trending_7d', forceRefresh: forceRefresh);
    _latest = CatalogApi.fetch(sortBy: 'latest', forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    setState(() => _reload(forceRefresh: true));
    try {
      await Future.wait([_trending, _latest]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: accent,
      backgroundColor: panel,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.paddingOf(context).top + 9,
                12,
                12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.black, size: 25),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ManhwaKu', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                        Text('KOMIK • MANGA • NOVEL', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cari judul',
                    onPressed: widget.onSearch,
                    icon: const Icon(Icons.search_rounded, size: 27),
                  ),
                  IconButton(
                    tooltip: 'Tentang aplikasi',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 25),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<SeriesItem>>(
              future: _trending,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorPanel(
                    message: 'Katalog belum dapat dimuat. Periksa koneksi lalu coba lagi.',
                    onRetry: () => setState(() => _reload(forceRefresh: true)),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 215,
                    child: Center(child: CircularProgressIndicator(color: accent)),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const ErrorPanel(message: 'Belum ada judul yang cocok dengan filter aman.');
                }
                return HeroCarousel(items: items.take(6).toList(), onOpen: widget.onOpen);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 3),
              child: Row(
                children: [
                  _QuickAction(icon: Icons.grid_view_rounded, label: 'Kategori', onTap: widget.onExplore),
                  _QuickAction(icon: Icons.favorite_rounded, label: 'Favorit', color: const Color(0xFFFF6E8A), onTap: widget.onFavorites),
                  _QuickAction(icon: Icons.history_rounded, label: 'Riwayat', onTap: widget.onHistory),
                  _QuickAction(icon: Icons.local_fire_department_rounded, label: 'Trending', color: const Color(0xFFFFC857), onTap: widget.onExplore),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: stroke),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MULTI-SOURCE CATALOG', style: TextStyle(
                      color: accent, fontSize: 9, letterSpacing: 1.3,
                      fontWeight: FontWeight.w900,
                    )),
                    SizedBox(height: 7),
                    Text('Manga • Manhwa • Manhua • Novel',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('Metadata disatukan dari MangaBaka, MangaDex, dan Jikan. Hasil dengan rating tidak aman disaring.',
                      style: TextStyle(color: muted, fontSize: 10, height: 1.45)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(title: 'Baru diperbarui', action: 'Lihat selengkapnya', onTap: widget.onExplore),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<SeriesItem>>(
              future: _latest,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    child: Text('Bagian terbaru belum tersedia.', style: TextStyle(color: muted)),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: accent)));
                }
                return GridShelf(items: snapshot.data!.take(9).toList(), onOpen: widget.onOpen);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(title: 'Pilihan terbaik untukmu', action: 'Jelajahi', onTap: widget.onExplore),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<SeriesItem>>(
              future: _trending,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 180);
                }
                return GridShelf(
                  items: snapshot.data!.skip(6).take(9).toList(),
                  onOpen: widget.onOpen,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icon, color: color, size: 27),
                const SizedBox(height: 7),
                Text(label, style: const TextStyle(fontSize: 11, color: ink, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.items, required this.onOpen});
  final List<SeriesItem> items;
  final OpenSeries onOpen;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController(viewportFraction: .88);
  int _active = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 218,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (value) => setState(() => _active = value),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: GestureDetector(
                  onTap: () => widget.onOpen(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SeriesCover(url: item.cover, fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: .14),
                                Colors.black.withValues(alpha: .74),
                                Colors.black.withValues(alpha: .94),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 116,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: AspectRatio(
                                  aspectRatio: .68,
                                  child: SeriesCover(url: item.cover),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 17, top: 20, bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(30)),
                                      child: Text(typeLabel(item.type).toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: .5)),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
                                    const SizedBox(height: 8),
                                    Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD0D0D0), fontSize: 10, height: 1.35)),
                                    const SizedBox(height: 8),
                                    const Text('BUKA DETAIL  ›', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (index) {
            final selected = index == _active;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 18 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: selected ? accent : const Color(0xFF555555),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.action, required this.onTap});
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 25, 18, 12),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.3))),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(foregroundColor: accent, padding: const EdgeInsets.symmetric(horizontal: 5)),
              child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right_rounded, color: accent, size: 18),
          ],
        ),
      );
}

class GridShelf extends StatelessWidget {
  const GridShelf({super.key, required this.items, required this.onOpen});
  final List<SeriesItem> items;
  final OpenSeries onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Text('Belum ada judul pada bagian ini.', style: TextStyle(color: muted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 15,
          crossAxisSpacing: 10,
          childAspectRatio: .52,
        ),
        itemBuilder: (context, index) => SeriesCard(item: items[index], onTap: () => onOpen(items[index])),
      ),
    );
  }
}

class SeriesCard extends StatelessWidget {
  const SeriesCard({super.key, required this.item, required this.onTap});
  final SeriesItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SeriesCover(url: item.cover),
                  ),
                  Positioned(
                    left: 5,
                    top: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .76), borderRadius: BorderRadius.circular(5)),
                      child: Text(typeLabel(item.type), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  if (item.rating != null)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .76), borderRadius: BorderRadius.circular(5)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 10),
                            const SizedBox(width: 2),
                            Text((item.rating! / 10).toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 3),
            Text(statusLabel(item.status), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class SeriesCover extends StatelessWidget {
  const SeriesCover({super.key, required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _CoverFallback();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: 480,
      maxWidthDiskCache: 480,
      fadeInDuration: const Duration(milliseconds: 100),
      placeholder: (_, __) => Container(
        color: panel2,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
        ),
      ),
      errorWidget: (_, __, ___) => const _CoverFallback(),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) => Container(
        color: panel2,
        alignment: Alignment.center,
        child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF686868), size: 34),
      );
}

class DiscoveryTab extends StatefulWidget {
  const DiscoveryTab({super.key, required this.onOpen});
  final OpenSeries onOpen;

  @override
  State<DiscoveryTab> createState() => _DiscoveryTabState();
}

class _DiscoveryTabState extends State<DiscoveryTab> {
  static const _filters = <String, List<String>>{
    'Semua': [],
    'Manga': ['manga'],
    'Manhwa': ['manhwa'],
    'Manhua': ['manhua'],
    'Novel': ['novel'],
    'Light Novel': ['lightnovel'],
    'Webtoon': ['webtoon'],
    'OEL': ['oel'],
    'Lainnya': ['other'],
  };

  String _selected = 'Semua';
  final List<SeriesItem> _items = [];
  int _page = 0;
  int _requestId = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false, bool forceRefresh = false}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) return;
    final request = ++_requestId;
    final nextPage = reset ? 1 : _page + 1;

    setState(() {
      if (reset) {
        _items.clear();
        _page = 0;
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });

    try {
      final results = await CatalogApi.fetch(
        types: _filters[_selected]!,
        sortBy: 'trending_7d',
        page: nextPage,
        forceRefresh: forceRefresh,
      );
      if (!mounted || request != _requestId) return;

      setState(() {
        final seen = _items.map((item) => item.id).toSet();
        for (final item in results) {
          if (seen.add(item.id)) _items.add(item);
        }
        _page = nextPage;
        _hasMore = results.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Katalog gagal dimuat. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 16, 18, 10),
            child: Row(
              children: [
                const Expanded(child: Text('Jelajahi', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => _load(reset: true, forceRefresh: true), icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
          ),
          SizedBox(
            height: 43,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              children: _filters.keys.map((name) {
                final selected = name == _selected;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selected = name);
                      _load(reset: true);
                    },
                    selectedColor: accent,
                    backgroundColor: panel,
                    labelStyle: TextStyle(color: selected ? Colors.black : ink, fontWeight: FontWeight.w800, fontSize: 11),
                    side: BorderSide(color: selected ? accent : stroke),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator(color: accent))
                : _error != null && _items.isEmpty
                    ? ErrorPanel(message: _error!, onRetry: () => _load(reset: true))
                    : _items.isEmpty
                        ? const ErrorPanel(message: 'Belum ada judul pada kategori ini.')
                        : Column(
                            children: [
                              Expanded(
                                child: GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                                  itemCount: _items.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 15,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: .52,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return SeriesCard(item: item, onTap: () => widget.onOpen(item));
                                  },
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(_error!, style: const TextStyle(color: muted, fontSize: 10)),
                                ),
                              if (_hasMore)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 9),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _loadingMore ? null : () => _load(),
                                      child: _loadingMore
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                                          : const Text('Muat lebih banyak'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
          ),
        ],
      );
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.onOpen});
  final OpenSeries onOpen;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _controller = TextEditingController();
  static const _types = <String, List<String>>{
    'Semua': [],
    'Manga': ['manga'],
    'Manhwa': ['manhwa'],
    'Manhua': ['manhua'],
    'Novel': ['novel'],
    'Light Novel': ['lightnovel'],
    'Webtoon': ['webtoon'],
    'OEL': ['oel'],
    'Lainnya': ['other'],
  };

  String _selected = 'Semua';
  final List<SeriesItem> _items = [];
  int _page = 0;
  int _requestId = 0;
  bool _searched = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search({bool reset = true}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) return;
    final request = ++_requestId;
    final query = _controller.text.trim();
    final nextPage = reset ? 1 : _page + 1;

    setState(() {
      if (reset) {
        _items.clear();
        _page = 0;
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _searched = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });

    try {
      final results = await CatalogApi.fetch(
        query: query,
        types: _types[_selected]!,
        sortBy: query.isEmpty ? 'popularity_asc' : 'relevance_desc',
        page: nextPage,
      );
      if (!mounted || request != _requestId) return;

      setState(() {
        final seen = _items.map((item) => item.id).toSet();
        for (final item in results) {
          if (seen.add(item.id)) _items.add(item);
        }
        _page = nextPage;
        _hasMore = results.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Pencarian gagal. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 15, 18, 12),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Cari komik & novel', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Masukkan judul atau nama seri',
                hintStyle: const TextStyle(color: muted, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: muted),
                suffixIcon: IconButton(
                  onPressed: () {
                    _controller.clear();
                    _search();
                  },
                  icon: const Icon(Icons.close_rounded, color: muted),
                ),
                filled: true,
                fillColor: panel,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              children: _types.keys.map((name) {
                final selected = name == _selected;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selected = name);
                      _search();
                    },
                    selectedColor: accent,
                    backgroundColor: panel,
                    labelStyle: TextStyle(color: selected ? Colors.black : ink, fontSize: 11, fontWeight: FontWeight.w800),
                    side: BorderSide(color: selected ? accent : stroke),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: !_searched
                ? const ErrorPanel(
                    icon: Icons.manage_search_rounded,
                    title: 'Temukan cerita favoritmu',
                    message: 'Cari berdasarkan judul atau jelajahi katalog berdasarkan jenis bacaan.',
                  )
                : _loading && _items.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: accent))
                    : _error != null && _items.isEmpty
                        ? ErrorPanel(message: _error!, onRetry: () => _search())
                        : _items.isEmpty
                            ? const ErrorPanel(
                                icon: Icons.search_off_rounded,
                                title: 'Judul tidak ditemukan',
                                message: 'Coba kata kunci atau kategori yang berbeda.',
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                                      itemCount: _items.length,
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 15,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: .52,
                                      ),
                                      itemBuilder: (context, index) {
                                        final item = _items[index];
                                        return SeriesCard(item: item, onTap: () => widget.onOpen(item));
                                      },
                                    ),
                                  ),
                                  if (_error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(_error!, style: const TextStyle(color: muted, fontSize: 10)),
                                    ),
                                  if (_hasMore)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 9),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: _loadingMore ? null : () => _search(reset: false),
                                          child: _loadingMore
                                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                                              : const Text('Muat lebih banyak'),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
          ),
        ],
      );
}

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key, required this.onOpen, required this.mode});
  final OpenSeries onOpen;
  final String mode;

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  late Future<List<SeriesItem>> _future;
  String _selectedFilter = 'favorites';

  String get _key => widget.mode == 'favorites' ? _selectedFilter : 'history';
  String get _title => widget.mode == 'favorites' ? 'Koleksi' : 'Riwayat baca';

  static const Map<String, String> _filters = {
    'favorites': 'Favorit',
    'reading': 'Sedang dibaca',
    'planned': 'Rencana',
    'completed': 'Selesai',
    'dropped': 'Dihentikan',
  };

  @override
  void initState() {
    super.initState();
    _future = LocalLibrary.read(_key);
  }

  void _selectFilter(String key) {
    setState(() {
      _selectedFilter = key;
      _future = LocalLibrary.read(_key);
    });
  }

  Future<void> _clear() async {
    await LocalLibrary.clear(_key);
    if (!mounted) return;
    setState(() => _future = LocalLibrary.read(_key));
  }

  String get _emptyTitle {
    if (widget.mode == 'history') return 'Belum ada riwayat';
    switch (_selectedFilter) {
      case 'favorites':
        return 'Belum ada favorit';
      case 'reading':
        return 'Belum ada bacaan aktif';
      case 'planned':
        return 'Belum ada rencana baca';
      case 'completed':
        return 'Belum ada judul selesai';
      default:
        return 'Belum ada judul dihentikan';
    }
  }

  String get _emptyMessage => widget.mode == 'history'
      ? 'Judul yang pernah kamu buka akan tampil di sini.'
      : 'Atur status bacaan dari halaman detail sebuah judul.';

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SeriesItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorPanel(
              title: 'Koleksi gagal dibuka',
              message: 'Silakan coba kembali.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: accent));
          }
          final items = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  MediaQuery.paddingOf(context).top + 16,
                  18,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: _clear,
                        child: const Text('Hapus', style: TextStyle(color: accent)),
                      ),
                  ],
                ),
              ),
              if (widget.mode == 'favorites')
                SizedBox(
                  height: 43,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    children: _filters.entries.map((entry) {
                      final selected = _selectedFilter == entry.key;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: (_) => _selectFilter(entry.key),
                          selectedColor: accent,
                          backgroundColor: panel,
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          side: BorderSide(color: selected ? accent : stroke),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? ErrorPanel(
                        icon: widget.mode == 'favorites'
                            ? Icons.bookmark_border_rounded
                            : Icons.history_rounded,
                        title: _emptyTitle,
                        message: _emptyMessage,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                        itemCount: items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 15,
                          crossAxisSpacing: 10,
                          childAspectRatio: .52,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return SeriesCard(
                            item: item,
                            onTap: () => widget.onOpen(item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
}

class SeriesDetailsPage extends StatefulWidget {
  const SeriesDetailsPage({super.key, required this.item});
  final SeriesItem item;

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  bool _saved = false;
  bool _ready = false;
  bool _enriching = false;
  late SeriesItem _displayItem;
  String _readingStatus = 'none';

  @override
  void initState() {
    super.initState();
    _displayItem = widget.item;
    _loadSaved();
    _enrichMetadata();
  }

  Future<void> _loadSaved() async {
    final values = await Future.wait([
      LocalLibrary.isFavorite(widget.item.id),
      LocalLibrary.statusFor(widget.item.id),
    ]);
    if (!mounted) return;
    setState(() {
      _saved = values[0] as bool;
      _readingStatus = values[1] as String;
      _ready = true;
    });
  }


  Future<void> _enrichMetadata() async {
    if (widget.item.description != 'Deskripsi belum tersedia.' &&
        widget.item.cover.isNotEmpty) return;

    if (mounted) setState(() => _enriching = true);
    try {
      final full = await MangaBakaDetailsApi.fetchForItem(widget.item);
      if (!mounted || full == null) return;
      final base = _displayItem;
      final hasSynopsis = base.description.isNotEmpty &&
          base.description != 'Deskripsi belum tersedia.';
      setState(() {
        _displayItem = SeriesItem(
          id: base.id,
          title: base.title,
          type: base.type,
          url: base.url,
          cover: base.cover.isNotEmpty ? base.cover : full.cover,
          description: hasSynopsis ? base.description : full.description,
          status: base.status == 'unknown' ? full.status : base.status,
          rating: base.rating ?? full.rating,
          author: base.author.isNotEmpty ? base.author : full.author,
          language: base.language == 'unknown' ? full.language : base.language,
          contentRating: base.contentRating,
          source: base.source,
          availableTranslatedLanguages: base.availableTranslatedLanguages,
          mangaBakaId: base.mangaBakaId ?? full.mangaBakaId ?? full.id,
        );
      });
    } catch (_) {
      // Detail metadata is optional; keep the initial fast page intact.
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _setReadingStatus(String status) async {
    await LocalLibrary.setStatus(widget.item, status);
    if (!mounted) return;
    setState(() => _readingStatus = status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status bacaan: ${readingStatusLabel(status)}')),
    );
  }

  Future<void> _toggleSaved() async {
    final value = await LocalLibrary.toggleFavorite(widget.item);
    if (!mounted) return;
    setState(() => _saved = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _displayItem;
    return Scaffold(
      appBar: AppBar(
        title: Text(typeLabel(item.type), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _ready ? _toggleSaved : null,
            tooltip: _saved ? 'Hapus favorit' : 'Simpan favorit',
            icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _saved ? accent : ink),
          ),
          PopupMenuButton<String>(
            tooltip: 'Status bacaan',
            enabled: _ready,
            onSelected: _setReadingStatus,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reading', child: Text('Sedang dibaca')),
              PopupMenuItem(value: 'planned', child: Text('Rencana baca')),
              PopupMenuItem(value: 'completed', child: Text('Selesai')),
              PopupMenuItem(value: 'dropped', child: Text('Dihentikan')),
              PopupMenuItem(value: 'none', child: Text('Hapus status')),
            ],
            icon: Icon(
              _readingStatus == 'none' ? Icons.playlist_add_rounded : Icons.playlist_add_check_circle_rounded,
              color: _readingStatus == 'none' ? ink : accent,
            ),
          ),
          IconButton(
            tooltip: 'Bagikan judul',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: item.title + ' — ' + item.url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul dan tautan disalin.')));
              }
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 9, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 142,
                    height: 210,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: SeriesCover(url: item.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.12)),
                        const SizedBox(height: 10),
                        _InfoPill(text: typeLabel(item.type)),
                        const SizedBox(height: 7),
                        _InfoPill(text: statusLabel(item.status)),
                        if (item.rating != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 17),
                            const SizedBox(width: 4),
                            Text((item.rating! / 10).toStringAsFixed(1) + '/10', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ]),
                        ],
                        if (item.author.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text('PENULIS', style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(item.author, style: const TextStyle(fontSize: 11, color: ink)),
                        ],
                        const SizedBox(height: 8),
                        Text('Bahasa asli: ' + item.language.toUpperCase(), style: const TextStyle(color: muted, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: stroke),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: accent, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sumber metadata', style: TextStyle(fontSize: 10, color: muted)),
                          Text(item.source, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (item.source == 'MangaDex')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: FilledButton.icon(
                  onPressed: () {
                    final parts = Uri.tryParse(item.url)?.pathSegments ?? const <String>[];
                    final titleIndex = parts.indexOf('title');
                    final mangaId = titleIndex >= 0 && titleIndex + 1 < parts.length
                        ? parts[titleIndex + 1]
                        : '';
                    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(mangaId)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID MangaDex tidak valid.')),
                      );
                      return;
                    }
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => MangaDexChapterPage(item: item, mangaId: mangaId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Buka daftar chapter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 9),
              child: const Text('SINOPSIS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7, fontSize: 13)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.description, style: const TextStyle(color: Color(0xFFD0D0D0), fontSize: 12, height: 1.55)),
                  if (_enriching && item.description == 'Deskripsi belum tersedia.') ...[
                    const SizedBox(height: 8),
                    const Text('Memuat sinopsis tambahan…', style: TextStyle(color: muted, fontSize: 10)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: panel2, borderRadius: BorderRadius.circular(7)),
        child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
      );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tentang ManhwaKu')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.black, size: 35),
            ),
            const SizedBox(height: 16),
            const Text('ManhwaKu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const Text('Versi 2.5.0', style: TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 14),
            const Text(
              'Katalog penemuan komik dan novel dari beberapa sumber metadata publik. '
              'Aplikasi menyaring hasil ke rating aman dan tidak mengunduh chapter dari situs pihak ketiga.',
              style: TextStyle(color: Color(0xFFD0D0D0), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            const Text('SUMBER DATA', style: TextStyle(
              color: accent, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900,
            )),
            const SizedBox(height: 10),
            _SourceCredit(
              title: 'MangaBaka',
              url: 'https://mangabaka.org/developers',
              note: 'Metadata • penggunaan personal/non-komersial • atribusi wajib',
            ),
            _SourceCredit(
              title: 'MangaDex',
              url: 'https://gitlab.com/mangadex-pub/mangadex-api-docs',
              note: 'Metadata katalog • kebijakan penggunaan dan atribusi berlaku',
            ),
            _SourceCredit(
              title: 'Jikan / MyAnimeList',
              url: 'https://docs.api.jikan.moe/',
              note: 'Metadata manga publik • tanpa API key',
            ),
            const SizedBox(height: 14),
            const Text(
              'ManhwaKu tidak berafiliasi dengan penyedia data tersebut. '
              'Judul, sampul, dan deskripsi tetap dimiliki pemegang hak masing-masing.',
              style: TextStyle(color: muted, fontSize: 10, height: 1.5),
            ),
          ],
        ),
      );
}

class _SourceCredit extends StatelessWidget {
  const _SourceCredit({
    required this.title,
    required this.url,
    required this.note,
  });

  final String title;
  final String url;
  final String note;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(color: muted, fontSize: 10)),
            const SizedBox(height: 4),
            Text(url, style: const TextStyle(color: accent, fontSize: 9)),
          ],
        ),
      );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    this.icon = Icons.cloud_off_rounded,
    this.title = 'Tidak dapat memuat data',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
    this.secondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 43),
              const SizedBox(height: 13),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 11, height: 1.45)),
              if (onRetry != null) ...[
                const SizedBox(height: 15),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                  child: Text(retryLabel),
                ),
              ],
              if (secondary != null) secondary!,
            ],
          ),
        ),
      );
}
