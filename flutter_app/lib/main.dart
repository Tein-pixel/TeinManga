import 'dart:convert';

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
    final relationships =
        json['relationships'] is List ? json['relationships'] as List : const [];
    final titles = attributes['title'] is Map
        ? Map<String, dynamic>.from(attributes['title'] as Map)
        : <String, dynamic>{};
    final description = attributes['description'] is Map
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
        : 'https://uploads.mangadex.org/covers/$id/$coverFile.256.jpg';
    final rating = attributes['contentRating']?.toString() ?? 'safe';
    return SeriesItem(
      id: _stableId('mangadex:$id'),
      title: _firstText([
        titles['en'],
        titles['ja-ro'],
        titles['ja'],
        titles.values.isEmpty ? '' : titles.values.first,
        'Tanpa judul',
      ]),
      type: type,
      url: id.isEmpty ? 'https://mangadex.org/' : 'https://mangadex.org/title/$id',
      cover: cover,
      description: _firstText([
        description['en'],
        description['id'],
        'Deskripsi belum tersedia.',
      ]),
      status: _firstText([attributes['status'], 'unknown']),
      rating: null,
      author: authors.take(2).join(', '),
      language: language,
      contentRating: rating,
      source: 'MangaDex',
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
  const blocked = {'ecchi', 'hentai', 'erotica', 'adult', 'mature'};
  for (final item in raw) {
    if (item is Map) {
      final name = _firstText([item['name'], item['title'], item['tag']]).toLowerCase();
      if (blocked.contains(name)) return true;
    } else if (blocked.contains(item.toString().toLowerCase())) {
      return true;
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
  static final Map<String, _CatalogCacheEntry> _cache = {};
  static DateTime? _lastJikanRequest;
  static Future<void> _jikanQueue = Future<void>.value();

  static Future<void> _paceJikan() {
    final next = _jikanQueue.then((_) async {
      final last = _lastJikanRequest;
      if (last != null) {
        final elapsed = DateTime.now().difference(last);
        const minimumGap = Duration(milliseconds: 450);
        if (elapsed < minimumGap) {
          await Future.delayed(minimumGap - elapsed);
        }
      }
      _lastJikanRequest = DateTime.now();
    });
    _jikanQueue = next;
    return next;
  }

  static Future<List<SeriesItem>> fetch({
    String? query,
    List<String> types = const [],
    String sortBy = 'trending_7d',
    int page = 1,
  }) async {
    if (testMode) return const <SeriesItem>[];
    final cleanQuery = (query ?? '').trim();
    final cacheKey = '${cleanQuery.toLowerCase()}|${types.join(",")}|$sortBy|$page';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.savedAt) < const Duration(minutes: 4)) {
      return cached.items;
    }

    var successfulSources = 0;
    Future<List<SeriesItem>> attempt(
      Future<List<SeriesItem>> Function() request,
    ) async {
      try {
        final result = await request();
        successfulSources++;
        return result;
      } catch (_) {
        return const <SeriesItem>[];
      }
    }

    final batches = await Future.wait<List<SeriesItem>>([
      attempt(() => _fetchMangaBaka(
            query: cleanQuery,
            types: types,
            sortBy: sortBy,
            page: page,
          )),
      attempt(() => _fetchMangaDex(
            query: cleanQuery,
            types: types,
            sortBy: sortBy,
            page: page,
          )),
      attempt(() => _fetchJikan(
            query: cleanQuery,
            types: types,
            sortBy: sortBy,
            page: page,
          )),
    ]);

    if (successfulSources == 0) {
      throw Exception('Semua sumber katalog sedang tidak merespons. Coba lagi nanti.');
    }

    final merged = <SeriesItem>[];
    final seenIds = <int>{};
    final seenTitles = <String>{};
    for (final batch in batches) {
      for (final item in batch) {
        final normalized = item.title
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (item.id <= 0 || item.title.isEmpty || item.contentRating != 'safe') {
          continue;
        }
        if (seenIds.add(item.id) && seenTitles.add(normalized)) {
          merged.add(item);
        }
      }
    }

    _cache[cacheKey] = _CatalogCacheEntry(
      List<SeriesItem>.unmodifiable(merged),
      DateTime.now(),
    );
    if (_cache.length > 80) _cache.remove(_cache.keys.first);
    return merged;
  }

  static Future<List<SeriesItem>> _fetchMangaBaka({
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) async {
    final params = <String>[
      'content_rating=safe',
      'with_boosts=false',
      'limit=$_providerPageSize',
      'page=$page',
      'sort_by=${Uri.encodeQueryComponent(sortBy)}',
    ];
    if (query.isNotEmpty) {
      params.add('q=${Uri.encodeQueryComponent(query)}');
    }
    for (final type in types) {
      params.add('type=${Uri.encodeQueryComponent(type)}');
    }
    final uri = Uri.parse(
      'https://api.mangabaka.org/v1/series/search?${params.join('&')}',
    );
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.4 Android',
        })
        .timeout(const Duration(seconds: 14));
    if (response.statusCode != 200) {
      throw Exception('MangaBaka HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format MangaBaka tidak dikenali.');
    }
    return (decoded['data'] as List)
        .whereType<Map>()
        .map((row) => SeriesItem.fromJson(Map<String, dynamic>.from(row)))
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
    if (types.isEmpty) {
      languages.addAll({'ja', 'ko', 'zh'});
    } else {
      if (types.contains('manga')) languages.add('ja');
      if (types.contains('manhwa')) languages.add('ko');
      if (types.contains('manhua')) languages.add('zh');
    }
    for (final language in languages) {
      params.add('originalLanguage%5B%5D=$language');
    }
    if (languages.isEmpty) return const <SeriesItem>[];

    final uri = Uri.parse(
      'https://api.mangadex.org/manga?${params.join('&')}',
    );
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.4 (Android; safe-catalog)',
        })
        .timeout(const Duration(seconds: 14));
    if (response.statusCode != 200) {
      throw Exception('MangaDex HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format MangaDex tidak dikenali.');
    }
    return (decoded['data'] as List)
        .whereType<Map>()
        .map((row) => SeriesItem.fromMangaDex(
              Map<String, dynamic>.from(row),
            ))
        .where((item) => item.id > 0 && item.contentRating == 'safe')
        .toList();
  }

  static Future<List<SeriesItem>> _fetchJikan({
    required String query,
    required List<String> types,
    required String sortBy,
    required int page,
  }) async {
    await _paceJikan();
    const typeMap = <String, String>{
      'manga': 'manga',
      'manhwa': 'manhwa',
      'manhua': 'manhua',
      'novel': 'novel',
      'lightnovel': 'lightnovel',
      'oel': 'oel',
      'webtoon': 'webtoon',
    };
    final selectedTypes = types
        .map((value) => typeMap[value])
        .whereType<String>()
        .toList();
    final path = query.isEmpty ? '/v4/top/manga' : '/v4/manga';
    final params = <String, String>{
      'limit': '$_providerPageSize',
      'page': '$page',
      'sfw': 'true',
    };
    if (query.isNotEmpty) {
      params['q'] = query;
    } else {
      params['filter'] = sortBy == 'latest' ? 'publishing' : 'bypopularity';
    }
    if (selectedTypes.length == 1) {
      params['type'] = selectedTypes.first;
    }
    final uri = Uri.https('api.jikan.moe', path, params);
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.4 (safe catalog client)',
        })
        .timeout(const Duration(seconds: 14));
    if (response.statusCode != 200) {
      throw Exception('Jikan HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format Jikan tidak dikenali.');
    }
    final items = <SeriesItem>[];
    for (final row in (decoded['data'] as List).whereType<Map>()) {
      final data = Map<String, dynamic>.from(row);
      if (_hasRestrictedTags(data['genres']) ||
          _hasRestrictedTags(data['themes']) ||
          _hasRestrictedTags(data['demographics'])) {
        continue;
      }
      items.add(SeriesItem.fromJikan(data));
    }
    return items;
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
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Future<List<MangaDexChapter>> fetchChapters(
    String mangaId, {
    String language = 'id',
  }) async {
    if (!_uuid.hasMatch(mangaId)) {
      throw const FormatException('ID MangaDex tidak valid.');
    }
    if (language != 'id' && language != 'en') {
      throw const FormatException('Bahasa chapter tidak didukung.');
    }
    final uri = Uri.parse(
      'https://api.mangadex.org/manga/$mangaId/feed'
      '?limit=100'
      '&translatedLanguage%5B%5D=$language'
      '&contentRating%5B%5D=safe'
      '&includes%5B%5D=scanlation_group'
      '&order%5Bvolume%5D=asc'
      '&order%5Bchapter%5D=asc',
    );
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.5 (safe reader)',
        })
        .timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) {
      throw Exception('MangaDex tidak dapat memuat chapter (${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format daftar chapter tidak dikenali.');
    }
    return (decoded['data'] as List)
        .whereType<Map>()
        .map((row) => MangaDexChapter.fromJson(Map<String, dynamic>.from(row)))
        .where((chapter) => chapter.id.isNotEmpty && chapter.pageCount > 0)
        .toList();
  }

  static Future<List<String>> fetchPages(
    String chapterId, {
    bool dataSaver = true,
  }) async {
    if (!_uuid.hasMatch(chapterId)) {
      throw const FormatException('ID chapter tidak valid.');
    }
    final uri = Uri.https('api.mangadex.org', '/at-home/server/$chapterId');
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.5 (safe reader)',
        })
        .timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) {
      throw Exception('Server gambar tidak tersedia (${response.statusCode}).');
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
        .map((file) => '$baseUrl/$quality/$hash/${Uri.encodeComponent(file)}')
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
  String _language = 'id';
  late Future<List<MangaDexChapter>> _future;

  @override
  void initState() {
    super.initState();
    _future = MangaDexChapterApi.fetchChapters(
      widget.mangaId,
      language: _language,
    );
  }

  void _changeLanguage(String language) {
    setState(() {
      _language = language;
      _future = MangaDexChapterApi.fetchChapters(
        widget.mangaId,
        language: language,
      );
    });
  }

  void _openChapter(MangaDexChapter chapter) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MangaDexReaderPage(
          item: widget.item,
          chapter: chapter,
        ),
      ),
    );
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
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'id', child: Text('Indonesia')),
                PopupMenuItem(value: 'en', child: Text('English')),
              ],
              icon: const Icon(Icons.translate_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<MangaDexChapter>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorPanel(
                title: 'Chapter gagal dimuat',
                message: 'Sumber sedang tidak merespons. Coba lagi.',
                onRetry: () => _changeLanguage(_language),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: accent),
              );
            }
            final chapters = snapshot.data!;
            if (chapters.isEmpty) {
              return const ErrorPanel(
                icon: Icons.menu_book_outlined,
                title: 'Belum ada chapter',
                message: 'Belum ditemukan chapter berlabel aman dalam bahasa ini.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: chapters.length,
              separatorBuilder: (_, __) => const Divider(color: stroke, height: 1),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final number = chapter.number.isEmpty
                    ? 'Chapter'
                    : 'Chapter ${chapter.number}';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                    chapter.title.isEmpty
                        ? number
                        : '$number • ${chapter.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      if (chapter.volume.isNotEmpty) 'Vol. ${chapter.volume}',
                      '${chapter.pageCount} halaman',
                      if (chapter.scanlationGroup.isNotEmpty)
                        'Grup: ${chapter.scanlationGroup}',
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: accent),
                  onTap: () => _openChapter(chapter),
                );
              },
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
                itemBuilder: (context, index) => Image.network(
                  pages[index],
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
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
              itemCount: pages.length,
              onPageChanged: (index) {
                if (mounted) setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    pages[index],
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => TextButton.icon(
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

  void _reload() {
    _trending = CatalogApi.fetch(sortBy: 'trending_7d');
    _latest = CatalogApi.fetch(sortBy: 'latest');
  }

  Future<void> _refresh() async {
    setState(_reload);
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
                    onRetry: () => setState(_reload),
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
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const _CoverFallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: panel2,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
        );
      },
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

  Future<void> _load({bool reset = false}) async {
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
      );
      if (!mounted || request != _requestId) return;

      setState(() {
        final seen = _items.map((item) => item.id).toSet();
        for (final item in results) {
          if (seen.add(item.id)) _items.add(item);
        }
        _page = nextPage;
        _hasMore = results.length >= CatalogApi.pageSize;
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
                IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh_rounded)),
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
        _hasMore = results.length >= CatalogApi.pageSize;
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
  String _readingStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadSaved();
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

  Future<void> _setReadingStatus(String status) async {
    await LocalLibrary.setStatus(widget.item, status);
    if (!mounted) return;
    setState(() => _readingStatus = status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status bacaan: ${readingStatusLabel(status)}'),
      ),
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
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(typeLabel(item.type), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _ready ? _toggleSaved : null,
            tooltip: _saved ? 'Hapus favorit' : 'Simpan favorit',
            icon: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _saved ? accent : ink,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Status bacaan',
            enabled: _ready,
            initialValue: _readingStatus,
            onSelected: _setReadingStatus,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reading', child: Text('Sedang dibaca')),
              PopupMenuItem(value: 'planned', child: Text('Rencana baca')),
              PopupMenuItem(value: 'completed', child: Text('Selesai')),
              PopupMenuItem(value: 'dropped', child: Text('Dihentikan')),
              PopupMenuItem(value: 'none', child: Text('Hapus status')),
            ],
            icon: Icon(
              _readingStatus == 'none'
                  ? Icons.playlist_add_rounded
                  : Icons.playlist_add_check_circle_rounded,
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
                    final parts = Uri.tryParse(item.url)?.pathSegments ?? const [];
                    final titleIndex = parts.indexOf('title');
                    final mangaId = titleIndex >= 0 && titleIndex + 1 < parts.length
                        ? parts[titleIndex + 1]
                        : '';
                    if (!RegExp(r'^[0-9a-fA-F-]{36}          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 9),
              child: const Text('SINOPSIS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7, fontSize: 13)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Text(item.description, style: const TextStyle(color: Color(0xFFD0D0D0), fontSize: 12, height: 1.55)),
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
            const Text('Versi 2.4.0', style: TextStyle(color: muted, fontSize: 11)),
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
).hasMatch(mangaId)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID MangaDex tidak valid.')),
                      );
                      return;
                    }
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => MangaDexChapterPage(
                          item: item,
                          mangaId: mangaId,
                        ),
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
              child: Text(item.description, style: const TextStyle(color: Color(0xFFD0D0D0), fontSize: 12, height: 1.55)),
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
            const Text('Versi 2.4.0', style: TextStyle(color: muted, fontSize: 11)),
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
