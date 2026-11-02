import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const Color bg = Color(0xFF080D16);
const Color panel = Color(0xFF111A29);
const Color panel2 = Color(0xFF19263A);
const Color accent = Color(0xFF36C5F0);
const Color accentAlt = Color(0xFF9B8CFF);
const Color ink = Color(0xFFF4F7FC);
const Color muted = Color(0xFF8F9BAD);
const Color stroke = Color(0xFF26364B);

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
      home: const StartupGate(),
    );
  }
}



class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const AppShell();
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [accent, Color(0xFF6488FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .22),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF06111C), size: 40),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
            ),
          ],
        ),
      ),
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
    this.publisherUrl = '',
    this.coverLarge = '',
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
  final String publisherUrl;
  final String coverLarge;

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
    final coverLarge = _firstText([
      x350['x3'],
      x350['x2'],
      x250['x3'],
      x250['x2'],
      raw['url'],
      cover,
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
      coverLarge: coverLarge,
      description: _firstText([json['description'], 'Deskripsi belum tersedia.']),
      status: _firstText([json['status'], 'unknown']),
      rating: ratingValue is num ? ratingValue.toDouble() : null,
      author: authors.map((e) => e.toString()).where((e) => e.isNotEmpty).take(2).join(', '),
      language: _firstText([json['original_language'], 'unknown']),
      contentRating: _firstText([json['content_rating'], 'unknown']).toLowerCase(),
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
    String coverValue(String key, {String dpi = 'x2'}) {
      final value = coverData[key];
      if (value is String) return value;
      if (value is Map) {
        return _firstText([
          value[dpi],
          value['x2'],
          value['x1'],
          value['url'],
        ]);
      }
      return '';
    }

    final authors = json['authors'] is List ? json['authors'] as List : const [];
    final authorNames = authors.map((entry) => entry is Map
        ? _firstText([entry['name'], entry['title']])
        : entry.toString()).where((name) => name.trim().isNotEmpty).take(2).join(', ');
    final ratingValue = json['rating'];
    final hasRestrictedTags = _hasRestrictedTags(json['tags']);
    final publisherUrl = _extractPublisherUrl(
      json['links_v2'],
      legacyLinks: json['links'],
    );

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
      coverLarge: _firstText([
        coverValue('x350', dpi: 'x3'),
        coverValue('x250', dpi: 'x3'),
        coverValue('raw'),
        coverValue('x350'),
      ]),
      description: _firstText([json['description'], 'Deskripsi belum tersedia.']),
      status: _firstText([json['status'], json['state'], 'unknown']),
      rating: ratingValue is num ? ratingValue.toDouble() : null,
      author: authorNames,
      language: language,
      contentRating: hasRestrictedTags ? 'blocked' : _firstText([json['content_rating'], 'unknown']).toLowerCase(),
      source: 'MangaBaka',
      mangaBakaId: _toInt(json['id']) > 0 ? _toInt(json['id']) : null,
      publisherUrl: publisherUrl,
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
      contentRating: 'unknown',
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
    final cover = coverFile.isEmpty
        ? ''
        : 'https://uploads.mangadex.org/covers/$id/$coverFile.512.jpg';
    final coverLarge = coverFile.isEmpty
        ? ''
        : 'https://uploads.mangadex.org/covers/$id/$coverFile';
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
      coverLarge: coverLarge,
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
      contentRating: hasRestrictedTags ? 'blocked' : _firstText([attributes['contentRating'], 'unknown']).toLowerCase(),
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
        coverLarge: _firstText([json['coverLarge']]),
        description: _firstText([json['description']]),
        status: _firstText([json['status']]),
        rating: json['rating'] is num ? (json['rating'] as num).toDouble() : null,
        author: _firstText([json['author']]),
        language: _firstText([json['language']]),
        contentRating: _firstText([json['contentRating'], 'unknown']).toLowerCase(),
        source: _firstText([json['source'], 'MangaBaka']),
        availableTranslatedLanguages: (json['availableTranslatedLanguages'] as List?)
            ?.whereType<String>().toList() ?? const <String>[],
        mangaBakaId: json['mangaBakaId'] is num ? (json['mangaBakaId'] as num).toInt() : null,
        publisherUrl: _firstText([json['publisherUrl']]),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'url': url,
        'cover': cover,
        'coverLarge': coverLarge,
        'description': description,
        'status': status,
        'rating': rating,
        'author': author,
        'language': language,
        'contentRating': contentRating,
        'source': source,
        'availableTranslatedLanguages': availableTranslatedLanguages,
        'mangaBakaId': mangaBakaId,
        'publisherUrl': publisherUrl,
      };
}


String _extractPublisherUrl(dynamic rawLinks, {dynamic legacyLinks}) {
  Uri? trustedHttpsUrl(dynamic raw) {
    if (raw is! Map) return null;
    final candidate = Uri.tryParse(_firstText([raw['url']]));
    if (candidate == null ||
        candidate.scheme.toLowerCase() != 'https' ||
        candidate.host.isEmpty ||
        candidate.userInfo.isNotEmpty) {
      return null;
    }
    return candidate;
  }

  // Current MangaBaka v2 records use `links`; newer records may expose
  // `links_v2` with explicit trust and status fields.
  if (rawLinks is List) {
    for (final raw in rawLinks) {
      if (raw is! Map) continue;
      final type = raw['type']?.toString().toLowerCase();
      final trust = raw['trust_level']?.toString().toLowerCase();
      final status = raw['status']?.toString().toLowerCase();
      final explicitlyTrustedPlatform = type == 'webplatform' &&
          (trust == 'official' || trust == 'trusted') && status == 'active';
      if (type != 'publisher' && !explicitlyTrustedPlatform) continue;
      if (status.isNotEmpty && status != 'active') continue;
      if (trust.isNotEmpty && trust != 'official' && trust != 'trusted') continue;
      final candidate = trustedHttpsUrl(raw);
      if (candidate != null) return candidate.toString();
    }
  }

  // A legacy `publisher` link is explicitly typed by MangaBaka. Do not
  // promote unverified webplatform/mirror records to publisher links.
  if (legacyLinks is List) {
    for (final raw in legacyLinks) {
      if (raw is! Map || raw['type']?.toString().toLowerCase() != 'publisher') {
        continue;
      }
      final candidate = trustedHttpsUrl(raw);
      if (candidate != null) return candidate.toString();
    }
  }
  return '';
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
    'ecchi', 'hentai', 'erotica', 'adult', 'mature', 'suggestive',
    'pornographic', 'nudity', 'sexual content', 'sexual violence',
    'sexual abuse', 'gore', 'graphic violence',
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


class RespectfulHttp {
  static Future<http.Response> get(
    http.Client client,
    Uri uri, {
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await client.get(uri, headers: headers).timeout(timeout);
      final retryable = response.statusCode == 429 ||
          response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 504;
      if (!retryable || attempt == 1) return response;

      final rawRetryAfter = response.headers['retry-after'];
      final retryAfter = int.tryParse(rawRetryAfter ?? '');
      // MangaBaka documents Retry-After: 10 for 429 responses.
      // Honor useful server guidance instead of retrying too early; avoid
      // holding the UI for an excessive server-supplied delay.
      if (retryAfter != null && (retryAfter < 0 || retryAfter > 30)) {
        return response;
      }
      if (rawRetryAfter != null && retryAfter == null) {
        return response;
      }
      final delay = retryAfter == null
          ? const Duration(milliseconds: 650)
          : Duration(seconds: retryAfter);
      await Future<void>.delayed(delay);
    }
    throw StateError('Permintaan tidak selesai.');
  }
}

abstract interface class CatalogSourceAdapter {
  String get id;

  Future<List<SeriesItem>> search({
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  });
}

class MangaDexCatalogAdapter implements CatalogSourceAdapter {
  const MangaDexCatalogAdapter();

  @override
  String get id => 'mangadex';

  @override
  Future<List<SeriesItem>> search({
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) {
    return CatalogApi._fetchMangaDex(
      query: query,
      types: types,
      sortBy: sortBy,
      page: page,
    );
  }
}

class MangaBakaCatalogAdapter implements CatalogSourceAdapter {
  const MangaBakaCatalogAdapter();

  @override
  String get id => 'mangabaka';

  @override
  Future<List<SeriesItem>> search({
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) {
    return CatalogApi._fetchMangaBakaV2(
      query: query,
      types: types,
      sortBy: sortBy,
      page: page,
    );
  }
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
  static final Map<String, bool> _lastSourceHealth = {};
  static Map<String, bool> get lastSourceHealth => Map.unmodifiable(_lastSourceHealth);

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
    const adapters = <CatalogSourceAdapter>[
      MangaDexCatalogAdapter(),
      MangaBakaCatalogAdapter(),
    ];
    var successCount = 0;
    final sourceHealth = <String, bool>{};

    Future<List<SeriesItem>> attempt(CatalogSourceAdapter adapter) async {
      try {
        final result = await adapter.search(
          query: query,
          types: types,
          sortBy: sortBy,
          page: page,
        );
        sourceHealth[adapter.id] = true;
        successCount++;
        return result;
      } catch (_) {
        sourceHealth[adapter.id] = false;
        return const <SeriesItem>[];
      }
    }

    final batches = await Future.wait<List<SeriesItem>>(
      adapters.map(attempt),
    );
    _lastSourceHealth
      ..clear()
      ..addAll(sourceHealth);

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
            cover: supplement.source == 'MangaBaka' && supplement.cover.isNotEmpty
                ? supplement.cover
                : (primary.cover.isNotEmpty ? primary.cover : supplement.cover),
            coverLarge: supplement.source == 'MangaBaka' && supplement.coverLarge.isNotEmpty
                ? supplement.coverLarge
                : (primary.coverLarge.isNotEmpty ? primary.coverLarge : supplement.coverLarge),
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
            publisherUrl: primary.publisherUrl.isNotEmpty ? primary.publisherUrl : supplement.publisherUrl,
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
    final response = await RespectfulHttp.get(
      _client,
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'ManhwaKu/2.9.1 (Android; catalog)',
      },
      timeout: _providerTimeout,
    );
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
    final response = await RespectfulHttp.get(
      _client,
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'ManhwaKu/2.9.1 (Android; safe-catalog)',
      },
      timeout: _providerTimeout,
    );
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
            'User-Agent': 'ManhwaKu/2.9.2 (Android; metadata)',
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

  static Future<SeriesItem?> _fetch(int id, {int mergeDepth = 0}) async {
    try {
      final uri = Uri.https(
        'api.mangabaka.org',
        '/v2/series/$id',
        const {'schema': 'full'},
      );
      final response = await _client
          .get(uri, headers: const {
            'Accept': 'application/json',
            'User-Agent': 'ManhwaKu/2.9.2 (Android; metadata)',
          })
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final raw = decoded['data'] is Map ? decoded['data'] : decoded;
      if (raw is! Map) return null;
      final data = Map<String, dynamic>.from(raw);
      if (data['state']?.toString().toLowerCase() == 'merged') {
        final replacementId = _toInt(data['merged_with']);
        if (replacementId > 0 && replacementId != id && mergeDepth < 2) {
          return _fetch(replacementId, mergeDepth: mergeDepth + 1);
        }
        return null;
      }
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
    if (normalizedLanguage != 'all' &&
        !RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(normalizedLanguage)) {
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

    final params = <String>[
      'limit=100',
      'offset=' + offset.toString(),
      'contentRating%5B%5D=safe',
      'includes%5B%5D=scanlation_group',
      'order%5Bvolume%5D=desc',
      'order%5Bchapter%5D=desc',
    ];
    if (normalizedLanguage != 'all') {
      params.insert(
        2,
        'translatedLanguage%5B%5D=' + Uri.encodeQueryComponent(normalizedLanguage),
      );
    }
    final uri = Uri.parse(
      'https://api.mangadex.org/manga/' + mangaId + '/feed?' + params.join('&'),
    );
    final response = await RespectfulHttp.get(
      _client,
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'ManhwaKu/2.9.1 (safe reader)',
      },
      timeout: const Duration(seconds: 12),
    );
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
    final response = await RespectfulHttp.get(
      _client,
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'ManhwaKu/2.9.1 (safe reader)',
      },
      timeout: const Duration(seconds: 15),
    );
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
    if (baseUri == null ||
        baseUri.scheme != 'https' ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUrl.isEmpty) {
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
  static const String preferredLanguage = 'id';

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
  String _language = MangaDexChapterPage.preferredLanguage;
  final List<MangaDexChapter> _chapters = [];
  int _requestId = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _usingLanguageFallback = false;
  String? _error;

  List<String> get _availableLanguages {
    final values = <String>['id', 'all'];
    for (final language in [
      ...widget.item.availableTranslatedLanguages,
      widget.item.language,
      ..._chapters.map((chapter) => chapter.language),
    ]) {
      final value = language.toLowerCase();
      if (value != 'unknown' &&
          RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(value) &&
          !values.contains(value)) {
        values.add(value);
      }
    }
    return values;
  }

  String _languageLabel(String code) {
    const labels = {
      'all': 'Semua bahasa',
      'id': 'Indonesia',
      'en': 'English',
      'ko': '한국어',
      'ja': '日本語',
      'zh': '中文',
      'zh-hk': '中文 (HK)',
      'zh-mo': '中文 (MO)',
      'es': 'Español',
      'es-la': 'Español (LatAm)',
      'pt-br': 'Português (BR)',
    };
    return labels[code] ?? code.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _load(reset: true, allowAutomaticLanguageFallback: true);
  }

  Future<void> _load({
    bool reset = false,
    bool allowAutomaticLanguageFallback = false,
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
      var fetched = await MangaDexChapterApi.fetchChapters(
        widget.mangaId,
        language: _language,
        offset: offset,
      );
      var resolvedLanguage = _language;
      var usedLanguageFallback = false;

      // If there is no Indonesian feed, inspect the source's combined feed
      // once so Korean/English/other available chapters are not hidden.
      if (reset &&
          allowAutomaticLanguageFallback &&
          _language == MangaDexChapterPage.preferredLanguage &&
          fetched.isEmpty) {
        final allLanguages = await MangaDexChapterApi.fetchChapters(
          widget.mangaId,
          language: 'all',
          offset: 0,
        );
        if (allLanguages.isNotEmpty) {
          fetched = allLanguages;
          resolvedLanguage = 'all';
          usedLanguageFallback = true;
        }
      }

      if (!mounted || request != _requestId) return;
      setState(() {
        final seen = _chapters.map((chapter) => chapter.id).toSet();
        for (final chapter in fetched) {
          if (seen.add(chapter.id)) _chapters.add(chapter);
        }
        _language = resolvedLanguage;
        _usingLanguageFallback = usedLanguageFallback;
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
    if (!_availableLanguages.contains(language) || language == _language) return;
    setState(() {
      _language = language;
      _usingLanguageFallback = false;
    });
    _load(reset: true);
  }

  void _openChapter(MangaDexChapter chapter) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MangaDexReaderPage(item: widget.item, chapter: chapter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 10, 9),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _chapters.isEmpty
                      ? 'Chapter'
                      : 'Chapter ' + _chapters.length.toString() + (_hasMore ? '+' : ''),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Bahasa',
                initialValue: _language,
                onSelected: _changeLanguage,
                itemBuilder: (context) => _availableLanguages
                    .map((language) => PopupMenuItem(
                          value: language,
                          child: Text(_languageLabel(language)),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: stroke),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.translate_rounded, color: accent, size: 16),
                      const SizedBox(width: 7),
                      Text(_languageLabel(_language), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 3),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: muted),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        if (_usingLanguageFallback)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 9),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: accent, size: 15),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Chapter Indonesia belum tersedia. Menampilkan bahasa lain yang tersedia.',
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading && _chapters.isEmpty
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
                          title: 'Belum ada chapter',
                          message: _language == 'id'
                              ? 'Belum ada chapter bahasa Indonesia dari sumber yang terhubung. Pilih Semua bahasa untuk memeriksa terjemahan lain.'
                              : 'Belum ada chapter aman dalam bahasa yang dipilih.',
                          onRetry: () => _load(reset: true),
                          secondary: OfficialReadingLinkButton(item: widget.item),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 3, 16, 18),
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
                                          label: const Text('Muat lebih lama'),
                                        ),
                                ),
                              );
                            }
                            final chapter = _chapters[index];
                            final number = chapter.number.isEmpty
                                ? 'Chapter'
                                : 'Chapter ' + chapter.number;
                            final detail = [
                              _languageLabel(chapter.language),
                              chapter.pageCount.toString() + ' halaman',
                              if (chapter.scanlationGroup.isNotEmpty) chapter.scanlationGroup,
                            ].join('  •  ');
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                              minVerticalPadding: 7,
                              leading: SizedBox(
                                width: 48,
                                height: 62,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: SeriesCover(url: widget.item.cover),
                                ),
                              ),
                              title: Text(
                                chapter.title.isEmpty ? number : number + '  ·  ' + chapter.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: muted, fontSize: 10),
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: accent),
                              onTap: () => _openChapter(chapter),
                            );
                          },
                        ),
        ),
      ],
    );
  }
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
              reverse: widget.chapter.language == 'ja',
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
  const SeriesCover({super.key, required this.url, this.fit = BoxFit.cover, this.highResolution = false});
  final String url;
  final BoxFit fit;
  final bool highResolution;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _CoverFallback();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: highResolution ? 720 : 480,
      maxWidthDiskCache: highResolution ? 720 : 480,
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


class MangaDexSeriesLookupApi {
  static final http.Client _client = http.Client();
  static final Map<String, SeriesItem> _cache = {};
  static final Map<String, Future<SeriesItem?>> _inFlight = {};

  static String _normalize(String value) {
    final withoutArticle = value.trim().toLowerCase().replaceFirst(
      RegExp(r'^(the|a|an)\s+'),
      '',
    );
    return withoutArticle.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String? idFromUrl(String url) {
    final parts = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final index = parts.indexOf('title');
    if (index < 0 || index + 1 >= parts.length) return null;
    final id = parts[index + 1];
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(id)
        ? id
        : null;
  }

  static Future<SeriesItem?> findMatch(SeriesItem source) async {
    final directId = idFromUrl(source.url);
    if (source.source == 'MangaDex' && directId != null) return source;

    final query = source.title.trim();
    final key = _normalize(query);
    if (key.length < 2 || key.length > 100) return null;
    if (_cache.containsKey(key)) return _cache[key];
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final request = _search(query, key);
    _inFlight[key] = request;
    try {
      return await request;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<SeriesItem?> _search(String query, String key) async {
    try {
      final uri = Uri.parse(
        'https://api.mangadex.org/manga?limit=10&title=' +
        Uri.encodeQueryComponent(query) +
        '&contentRating%5B%5D=safe&includes%5B%5D=cover_art&includes%5B%5D=author&order%5Brelevance%5D=desc',
      );
      final response = await _client.get(uri, headers: const {
        'Accept': 'application/json',
        'User-Agent': 'ManhwaKu/2.9.1 (safe title match)',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['data'] is! List) return null;
      for (final raw in decoded['data'] as List) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final attributes = row['attributes'] is Map
            ? Map<String, dynamic>.from(row['attributes'] as Map)
            : <String, dynamic>{};
        if (attributes['contentRating'] != 'safe' ||
            _hasRestrictedTags(attributes['tags'])) {
          continue;
        }

        final names = <String>[];
        final titles = attributes['title'];
        if (titles is Map) names.addAll(titles.values.map((value) => value.toString()));
        final alternate = attributes['altTitles'];
        if (alternate is List) {
          for (final entry in alternate.whereType<Map>()) {
            names.addAll(entry.values.map((value) => value.toString()));
          }
        }
        if (!names.any((name) => _normalize(name) == key)) continue;

        final item = SeriesItem.fromMangaDex(row);
        final id = idFromUrl(item.url);
        if (id == null || item.contentRating != 'safe' || item.cover.isEmpty) continue;
        _cache[key] = item;
        return item;
      }
    } catch (_) {
      // A catalogue match is optional; never block the details screen.
    }
    return null;
  }
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
  bool _chapterLookup = true;
  late SeriesItem _displayItem;
  SeriesItem? _chapterItem;
  String? _mangaDexId;
  String _readingStatus = 'none';

  @override
  void initState() {
    super.initState();
    _displayItem = widget.item;
    _loadSaved();
    _enrichMetadata();
    _resolveChapterSource();
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
        widget.item.cover.isNotEmpty &&
        widget.item.publisherUrl.isNotEmpty) return;

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
          coverLarge: base.coverLarge.isNotEmpty ? base.coverLarge : full.coverLarge,
          description: hasSynopsis ? base.description : full.description,
          status: base.status == 'unknown' ? full.status : base.status,
          rating: base.rating ?? full.rating,
          author: base.author.isNotEmpty ? base.author : full.author,
          language: base.language == 'unknown' ? full.language : base.language,
          contentRating: base.contentRating,
          source: base.source,
          availableTranslatedLanguages: base.availableTranslatedLanguages,
          mangaBakaId: base.mangaBakaId ?? full.mangaBakaId ?? full.id,
          publisherUrl: base.publisherUrl.isNotEmpty ? base.publisherUrl : full.publisherUrl,
        );
      });
    } catch (_) {
      // Keep the initial page usable if enrichment is unavailable.
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _resolveChapterSource() async {
    final directId = MangaDexSeriesLookupApi.idFromUrl(widget.item.url);
    if (widget.item.source == 'MangaDex' && directId != null) {
      if (mounted) {
        setState(() {
          _mangaDexId = directId;
          _chapterItem = widget.item;
          _chapterLookup = false;
        });
      }
      return;
    }

    try {
      final match = await MangaDexSeriesLookupApi.findMatch(widget.item);
      if (!mounted) return;
      setState(() {
        if (match != null) {
          _chapterItem = match;
          _mangaDexId = MangaDexSeriesLookupApi.idFromUrl(match.url);
          if (match.cover.isNotEmpty) {
            final current = _displayItem;
            final hasDescription = current.description.isNotEmpty &&
                current.description != 'Deskripsi belum tersedia.';
            _displayItem = SeriesItem(
              id: current.id,
              title: current.title,
              type: current.type,
              url: current.url,
              cover: current.cover.isNotEmpty ? current.cover : match.cover,
              coverLarge: current.coverLarge.isNotEmpty ? current.coverLarge : match.coverLarge,
              description: hasDescription ? current.description : match.description,
              status: current.status,
              rating: current.rating,
              author: current.author.isNotEmpty ? current.author : match.author,
              language: current.language,
              contentRating: current.contentRating,
              source: current.source,
              availableTranslatedLanguages: current.availableTranslatedLanguages,
              mangaBakaId: current.mangaBakaId,
              publisherUrl: current.publisherUrl.isNotEmpty ? current.publisherUrl : match.publisherUrl,
            );
          }
        }
        _chapterLookup = false;
      });
    } catch (_) {
      if (mounted) setState(() => _chapterLookup = false);
    }
  }

  Future<void> _setReadingStatus(String status) async {
    await LocalLibrary.setStatus(_displayItem, status);
    if (!mounted) return;
    setState(() => _readingStatus = status);
  }

  Future<void> _toggleSaved() async {
    final value = await LocalLibrary.toggleFavorite(_displayItem);
    if (!mounted) return;
    setState(() => _saved = value);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _displayItem.title + ' — ' + _displayItem.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tautan disalin')),
    );
  }

  Widget _buildHero(SeriesItem item) {
    return SizedBox(
      height: 232,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF18324A),
                  Color(0xFF172239),
                  Color(0xFF101725),
                  bg,
                ],
                stops: [0, .34, .72, 1],
              ),
            ),
          ),
          Positioned(
            right: -74,
            top: -106,
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accent.withValues(alpha: .22), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            left: -105,
            top: 20,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accentAlt.withValues(alpha: .16), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 134,
                    height: 184,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: .12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .38),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SeriesCover(
                        url: item.coverLarge.isNotEmpty ? item.coverLarge : item.cover,
                        highResolution: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.08),
                          ),
                          if (item.author.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              item.author,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: muted, fontSize: 11),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _DetailChip(text: typeLabel(item.type), color: accent),
                              _DetailChip(text: statusLabel(item.status), color: accentAlt),
                              if (item.rating != null)
                                _DetailChip(
                                  text: (item.rating! / 10).toStringAsFixed(1) + ' ★',
                                  color: const Color(0xFFFFC857),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 7, 15, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _ready ? _toggleSaved : null,
            child: _DetailAction(
              icon: _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: 'Favorit',
              active: _saved,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Status bacaan',
            onSelected: _setReadingStatus,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reading', child: Text('Sedang dibaca')),
              PopupMenuItem(value: 'planned', child: Text('Nanti')),
              PopupMenuItem(value: 'completed', child: Text('Selesai')),
              PopupMenuItem(value: 'dropped', child: Text('Berhenti')),
              PopupMenuItem(value: 'none', child: Text('Hapus status')),
            ],
            child: _DetailAction(
              icon: _readingStatus == 'none'
                  ? Icons.bookmark_add_outlined
                  : Icons.bookmark_added_rounded,
              label: 'Status',
              active: _readingStatus != 'none',
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _copyLink,
            child: const _DetailAction(
              icon: Icons.ios_share_rounded,
              label: 'Salin',
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoTab(SeriesItem item) {
    final description = item.description.trim().isEmpty ||
            item.description == 'Deskripsi belum tersedia.'
        ? 'Sinopsis belum tersedia.'
        : item.description;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const Text('Sinopsis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: Color(0xFFD2D9E4), fontSize: 13, height: 1.55)),
        if (_enriching) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2, color: accent, backgroundColor: panel),
        ],
        const SizedBox(height: 24),
        const Text('Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        _InfoRow(label: 'Jenis', value: typeLabel(item.type)),
        _InfoRow(label: 'Status', value: statusLabel(item.status)),
        if (item.author.isNotEmpty) _InfoRow(label: 'Kreator', value: item.author),
        if (item.language != 'unknown' && item.language.isNotEmpty)
          _InfoRow(label: 'Bahasa asli', value: item.language.toUpperCase()),
        if (item.source.isNotEmpty) _InfoRow(label: 'Metadata', value: item.source),
        if (item.publisherUrl.isNotEmpty) PublisherLinkButton(publisherUrl: item.publisherUrl),
      ],
    );
  }

  Widget _buildChapterTab(SeriesItem item) {
    if (_chapterLookup) {
      return const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: accent)),
      );
    }
    if (_mangaDexId != null && _chapterItem != null) {
      return MangaDexChapterPage(item: item, mangaId: _mangaDexId!);
    }
    return ErrorPanel(
      icon: Icons.menu_book_outlined,
      title: 'Chapter belum tersedia',
      message: 'Belum ada sumber chapter yang cocok untuk judul ini.',
      secondary: item.publisherUrl.isNotEmpty ? PublisherLinkButton(publisherUrl: item.publisherUrl) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _displayItem;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          leading: const BackButton(),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: _saved ? 'Hapus favorit' : 'Favorit',
              onPressed: _ready ? _toggleSaved : null,
              icon: Icon(_saved ? Icons.favorite_rounded : Icons.favorite_border_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildHero(item),
            _buildActions(),
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: stroke)),
              ),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: accent,
                unselectedLabelColor: muted,
                indicatorColor: accent,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Info'),
                  Tab(text: 'Chapters'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildInfoTab(item),
                  _buildChapterTab(item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PublisherLinkButton extends StatelessWidget {
  const PublisherLinkButton({super.key, required this.publisherUrl});
  final String publisherUrl;

  @override
  Widget build(BuildContext context) {
    final url = Uri.tryParse(publisherUrl);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: () {
          launchUrl(url, mode: LaunchMode.externalApplication);
        },
        icon: const Icon(Icons.open_in_new_rounded, size: 17),
        label: const Text('Buka penerbit'),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: stroke),
          minimumSize: const Size.fromHeight(46),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .30)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({required this.icon, required this.label, this.active = false});
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: panel,
                shape: BoxShape.circle,
                border: Border.all(color: stroke),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: active ? .14 : .04), blurRadius: 16),
                ],
              ),
              child: Icon(icon, color: active ? accent : ink, size: 23),
            ),
            const SizedBox(height: 7),
            Text(label, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 105, child: Text(label, style: const TextStyle(color: muted, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
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
            const Text('Versi 2.8.0', style: TextStyle(color: muted, fontSize: 11)),
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
              url: 'https://mangabaka.org/about/data-license',
              note: 'Metadata • CC BY-NC-SA 4.0 • ketentuan data pihak ketiga berlaku',
            ),
            _SourceCredit(
              title: 'MangaDex',
              url: 'https://gitlab.com/mangadex-pub/mangadex-api-docs',
              note: 'Metadata katalog • kebijakan penggunaan dan atribusi berlaku',
            ),
            const SizedBox(height: 14),
            const Text(
              'Chapter hanya tersedia jika sumber mendukung akses. '
              'Rating yang hilang atau tidak jelas tidak masuk katalog aman.',
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
