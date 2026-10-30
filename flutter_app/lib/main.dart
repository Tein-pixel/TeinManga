import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  const ManhwaKuApp({super.key});

  @override
  Widget build(BuildContext context) {
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


class WebtoonPick {
  const WebtoonPick({
    required this.title,
    required this.genre,
    required this.ageRating,
    required this.creator,
    required this.url,
    required this.coverUrl,
  });

  final String title;
  final String genre;
  final String ageRating;
  final String creator;
  final String url;
  final String coverUrl;
}

const officialWebtoonPicks = <WebtoonPick>[
  WebtoonPick(
    title: 'LOOKISM',
    genre: 'Aksi',
    ageRating: '16+',
    creator: 'Taejoon Park',
    url: 'https://m.webtoons.com/id/action/lookism/list?title_no=532',
    coverUrl: 'https://webtoon-phinf.pstatic.net/20231116_134/1700108772436oh00c_JPEG/532.jpg?type=q70',
  ),
  WebtoonPick(
    title: 'Eleceed',
    genre: 'Fantasi',
    ageRating: '13+',
    creator: 'ZHENA • Jeho Son',
    url: 'https://m.webtoons.com/id/fantasy/eleceed/list?title_no=2034',
    coverUrl: 'https://webtoon-phinf.pstatic.net/20231116_148/1700108786426s2R7i_JPEG/2034.jpg?type=q70',
  ),
];

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
    default:
      return 'Komik';
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

class CatalogApi {
  static final http.Client _client = http.Client();
  static const int pageSize = 25;

  static Future<List<SeriesItem>> fetch({
    String? query,
    List<String> types = const [],
    String sortBy = 'trending_7d',
    int page = 1,
  }) async {
    final params = <String>[
      'content_rating=safe',
      'with_boosts=false',
      'limit=' + pageSize.toString(),
      'page=' + page.toString(),
      'sort_by=' + Uri.encodeQueryComponent(sortBy),
    ];
    final cleanQuery = (query ?? '').trim();
    if (cleanQuery.isNotEmpty) {
      params.add('q=' + Uri.encodeQueryComponent(cleanQuery));
    }
    for (final type in types) {
      params.add('type=' + Uri.encodeQueryComponent(type));
    }

    final uri = Uri.parse(
      'https://api.mangabaka.org/v1/series/search?' + params.join('&'),
    );
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ManhwaKu/2.3 Android',
        })
        .timeout(const Duration(seconds: 22));

    if (response.statusCode != 200) {
      String message = 'Layanan katalog sedang bermasalah.';
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }
      } catch (_) {}
      throw Exception(message + ' (' + response.statusCode.toString() + ')');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Format katalog tidak dikenali.');
    }

    return (decoded['data'] as List)
        .whereType<Map>()
        .map((row) => SeriesItem.fromJson(Map<String, dynamic>.from(row)))
        .where((item) =>
            item.id > 0 &&
            item.title.isNotEmpty &&
            item.contentRating == 'safe')
        .toList();
  }
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

  Future<void> _openSeries(SeriesItem item) async {
    await LocalLibrary.addHistory(item);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SeriesDetailsPage(item: item),
      ),
    );
    if (mounted) setState(() {});
  }

  void _goSearch() => setState(() => _tab = 2);

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeTab(onOpen: _openSeries, onSearch: _goSearch, onExplore: () => setState(() => _tab = 1), onFavorites: () => setState(() => _tab = 3), onHistory: () => setState(() => _tab = 4)),
      DiscoveryTab(onOpen: _openSeries),
      SearchTab(onOpen: _openSeries),
      LibraryTab(onOpen: _openSeries, mode: 'favorites'),
      LibraryTab(onOpen: _openSeries, mode: 'history'),
    ];

    return Scaffold(
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _tab, children: screens),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (value) => setState(() => _tab = value),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF858585),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        showUnselectedLabels: true,
        elevation: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.local_fire_department_outlined), activeIcon: Icon(Icons.local_fire_department_rounded), label: 'BARU & HOT'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'CARI'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border_rounded), activeIcon: Icon(Icons.bookmark_rounded), label: 'FAVORIT'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'RIWAYAT'),
        ],
      ),
    );
  }
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
            child: SectionHeader(
              title: 'WEBTOON ORIGINAL',
              action: 'Lihat semua',
              onTap: () => _openOfficialWebtoon(
                context,
                'WEBTOON Populer',
                'https://www.webtoons.com/id/ranking/popular',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: WebtoonPickCard(
                      pick: officialWebtoonPicks[0],
                      onTap: () => _openOfficialWebtoon(
                        context,
                        officialWebtoonPicks[0].title,
                        officialWebtoonPicks[0].url,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WebtoonPickCard(
                      pick: officialWebtoonPicks[1],
                      onTap: () => _openOfficialWebtoon(
                        context,
                        officialWebtoonPicks[1].title,
                        officialWebtoonPicks[1].url,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: panel,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openOfficialWebtoon(
                    context,
                    'WEBTOON Populer',
                    'https://www.webtoons.com/id/ranking/popular',
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.language_rounded, color: accent, size: 22),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Jelajahi semua komik WEBTOON',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 15),
                      ],
                    ),
                  ),
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

  String get _key => widget.mode == 'favorites' ? 'favorites' : 'history';
  String get _title => widget.mode == 'favorites' ? 'Favorit' : 'Riwayat baca';

  @override
  void initState() {
    super.initState();
    _future = LocalLibrary.read(_key);
  }

  Future<void> _clear() async {
    await LocalLibrary.clear(_key);
    if (!mounted) return;
    setState(() => _future = LocalLibrary.read(_key));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SeriesItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorPanel(title: 'Koleksi gagal dibuka', message: 'Silakan coba kembali.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: accent));
          }
          final items = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 16, 18, 12),
                child: Row(
                  children: [
                    Expanded(child: Text(_title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: _clear,
                        child: const Text('Hapus', style: TextStyle(color: accent)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? ErrorPanel(
                        icon: widget.mode == 'favorites' ? Icons.bookmark_border_rounded : Icons.history_rounded,
                        title: widget.mode == 'favorites' ? 'Belum ada favorit' : 'Belum ada riwayat',
                        message: widget.mode == 'favorites'
                            ? 'Simpan judul dari halaman detail untuk menemukannya di sini.'
                            : 'Judul yang pernah kamu buka akan tampil di sini.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                        itemCount: items.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 15,
                          crossAxisSpacing: 10,
                          childAspectRatio: .52,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return SeriesCard(item: item, onTap: () => widget.onOpen(item));
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

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final value = await LocalLibrary.isFavorite(widget.item.id);
    if (mounted) setState(() {
      _saved = value;
      _ready = true;
    });
  }

  Future<void> _toggleSaved() async {
    final value = await LocalLibrary.toggleFavorite(widget.item);
    if (!mounted) return;
    setState(() => _saved = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit')),
    );
  }

  Future<void> _openSource() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SourceWebPage(item: widget.item)),
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
            icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _saved ? accent : ink),
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
              child: FilledButton.icon(
                onPressed: _openSource,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Lihat sumber & opsi membaca'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(49),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
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

class SourceWebPage extends StatefulWidget {
  const SourceWebPage({super.key, required this.item});
  final SeriesItem item;

  @override
  State<SourceWebPage> createState() => _SourceWebPageState();
}

class _SourceWebPageState extends State<SourceWebPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _configure();
  }

  Future<void> _configure() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(bg);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (mounted) setState(() {
              _loading = true;
              _failed = false;
              _progress = 0;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() {
              _loading = false;
              _progress = 100;
            });
          },
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      );
      await _controller.loadRequest(Uri.parse(widget.item.url));
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _external() async {
    final uri = Uri.tryParse(widget.item.url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Browser tidak dapat dibuka.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(onPressed: () => _controller.reload(), icon: const Icon(Icons.refresh_rounded)),
            IconButton(onPressed: _external, icon: const Icon(Icons.open_in_browser_rounded)),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  color: accent,
                  backgroundColor: Colors.transparent,
                ),
              ),
            if (_failed)
              Positioned.fill(
                child: Container(
                  color: bg,
                  padding: const EdgeInsets.all(26),
                  child: ErrorPanel(
                    icon: Icons.language_rounded,
                    title: 'Halaman sumber belum terbuka',
                    message: 'Coba muat ulang atau lanjutkan melalui browser. Akses chapter mengikuti situs penyedianya.',
                    onRetry: () {
                      setState(() {
                        _failed = false;
                        _loading = true;
                      });
                      _controller.loadRequest(Uri.parse(widget.item.url));
                    },
                    retryLabel: 'Coba lagi',
                    secondary: TextButton.icon(
                      onPressed: _external,
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Buka browser'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

void _openOfficialWebtoon(BuildContext context, String title, String url) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OfficialWebtoonPage(title: title, url: url),
    ),
  );
}

class WebtoonPickCard extends StatelessWidget {
  const WebtoonPickCard({super.key, required this.pick, required this.onTap});
  final WebtoonPick pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: panel,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: .78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      pick.coverUrl,
                      fit: BoxFit.cover,
                      headers: const {'Referer': 'https://m.webtoons.com/'},
                      errorBuilder: (_, __, ___) => Container(
                        color: panel2,
                        alignment: Alignment.center,
                        child: const Icon(Icons.auto_stories_rounded, color: accent, size: 38),
                      ),
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : Container(
                              color: panel2,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                color: accent,
                                strokeWidth: 2,
                              ),
                            ),
                    ),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pick.ageRating,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pick.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pick.genre + ' • ' + pick.creator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class OfficialWebtoonPage extends StatefulWidget {
  const OfficialWebtoonPage({super.key, required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<OfficialWebtoonPage> createState() => _OfficialWebtoonPageState();
}

class _OfficialWebtoonPageState extends State<OfficialWebtoonPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _configure();
  }

  Future<void> _configure() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(bg);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (mounted) setState(() {
              _loading = true;
              _failed = false;
              _progress = 0;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() {
              _loading = false;
              _progress = 100;
            });
          },
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      );
      await _controller.loadRequest(Uri.parse(widget.url));
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Browser eksternal tidak tersedia.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka browser eksternal.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(onPressed: () => _controller.reload(), icon: const Icon(Icons.refresh_rounded)),
            IconButton(onPressed: _openExternal, icon: const Icon(Icons.open_in_browser_rounded)),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  color: accent,
                  backgroundColor: Colors.transparent,
                ),
              ),
            if (_failed)
              Positioned.fill(
                child: Container(
                  color: bg,
                  padding: const EdgeInsets.all(26),
                  child: ErrorPanel(
                    icon: Icons.language_rounded,
                    title: 'WEBTOON belum terbuka',
                    message: 'Periksa koneksi, lalu coba lagi atau buka melalui browser.',
                    onRetry: () {
                      setState(() {
                        _failed = false;
                        _loading = true;
                        _progress = 0;
                      });
                      _controller.loadRequest(Uri.parse(widget.url));
                    },
                    secondary: TextButton.icon(
                      onPressed: _openExternal,
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Buka browser'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tentang ManhwaKu')),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.menu_book_rounded, color: Colors.black, size: 35),
              ),
              const SizedBox(height: 16),
              const Text('ManhwaKu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('Versi 2.2', style: TextStyle(color: muted, fontSize: 11)),
              const SizedBox(height: 14),
              const Text(
                'Temukan manga, manhwa, manhua, dan novel dalam satu aplikasi.',
                style: TextStyle(color: Color(0xFFD0D0D0), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openOfficialWebtoon(
                  context,
                  'WEBTOON Populer',
                  'https://www.webtoons.com/id/ranking/popular',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.language_rounded),
                label: const Text('Buka WEBTOON'),
              ),
            ],
          ),
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
