import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const bg = Color(0xFF080B11);
const surface = Color(0xFF141A24);
const surface2 = Color(0xFF1B2431);
const blue = Color(0xFF48B7FF);
const white = Color(0xFFF4F8FF);
const muted = Color(0xFF9AAAC0);
const line = Color(0xFF273244);

class ComicSource {
  const ComicSource({
    required this.name, required this.subtitle, required this.url,
    required this.category, required this.language, required this.icon,
    required this.accent,
  });
  final String name, subtitle, url, category, language;
  final IconData icon;
  final Color accent;
}

const sources = <ComicSource>[
  ComicSource(name: 'WEBTOON', subtitle: 'Webtoon dan komik berbahasa Indonesia',
    url: 'https://www.webtoons.com/id/', category: 'Manhwa', language: 'Indonesia',
    icon: Icons.auto_stories_rounded, accent: Color(0xFF48B7FF)),
  ComicSource(name: 'MANGA Plus', subtitle: 'Manga resmi dari penerbit Shueisha',
    url: 'https://mangaplus.shueisha.co.jp/updates', category: 'Manga', language: 'Multi bahasa',
    icon: Icons.menu_book_rounded, accent: Color(0xFFFF6B78)),
  ComicSource(name: 'Tapas', subtitle: 'Webcomic dan cerita dari kreator',
    url: 'https://tapas.io/series', category: 'Webcomic', language: 'Inggris',
    icon: Icons.auto_awesome_rounded, accent: Color(0xFFFFB45C)),
  ComicSource(name: 'Comikey', subtitle: 'Manga, manhwa, manhua dan webcomic',
    url: 'https://comikey.com/comics/', category: 'Campuran', language: 'Inggris',
    icon: Icons.collections_bookmark_rounded, accent: Color(0xFF80E1C1)),
  ComicSource(name: 'MANGA UP!', subtitle: 'Katalog manga resmi dari SQUARE ENIX',
    url: 'https://global.manga-up.com/', category: 'Manga', language: 'Inggris',
    icon: Icons.library_books_rounded, accent: Color(0xFFB8A0FF)),
  ComicSource(name: 'GlobalComix', subtitle: 'Komik dari penerbit dan kreator global',
    url: 'https://globalcomix.com/browse', category: 'Komik', language: 'Inggris',
    icon: Icons.public_rounded, accent: Color(0xFF7AB6FF)),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: bg, statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ManhwaKuApp());
}

class PageEntry {
  const PageEntry({required this.title, required this.url, required this.source});
  final String title, url, source;
  Map<String, String> toMap() => {'title': title, 'url': url, 'source': source};
  factory PageEntry.fromMap(Map<String, dynamic> map) => PageEntry(
    title: (map['title'] ?? '').toString(),
    url: (map['url'] ?? '').toString(),
    source: (map['source'] ?? 'Komik online').toString(),
  );
}

class Store {
  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<List<PageEntry>> entries(String key) async {
    final raw = (await _prefs).getStringList(key) ?? <String>[];
    final result = <PageEntry>[];
    for (final item in raw) {
      try {
        // Decode stored JSON entries separately so one bad entry cannot break the list.
        final decoded = _decodeEntry(item);
        if (decoded != null && decoded.url.startsWith('http')) result.add(decoded);
      } catch (_) {
        // Ignore corrupted local entries.
      }
    }
    return result;
  }

  static PageEntry? _decodeEntry(String raw) {
    try {
      final decoded = Uri.decodeComponent(raw);
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return PageEntry.fromMap(map);
      return null;
    } catch (_) {
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) return PageEntry.fromMap(map);
      } catch (_) {}
      return null;
    }
  }

  static Future<void> _write(String key, List<PageEntry> list) async {
    await (await _prefs).setStringList(
      key, list.map((entry) => Uri.encodeComponent(jsonEncode(entry.toMap()))).toList(),
    );
  }

  static Future<bool> isSaved(String url) async {
    final list = await entries('savedPages');
    return list.any((entry) => entry.url == url);
  }

  static Future<bool> toggleSaved(PageEntry entry) async {
    final list = await entries('savedPages');
    final index = list.indexWhere((item) => item.url == entry.url);
    final nowSaved = index < 0;
    if (nowSaved) {
      list.insert(0, entry);
    } else {
      list.removeAt(index);
    }
    await _write('savedPages', list.take(100).toList());
    return nowSaved;
  }

  static Future<void> removeSaved(String url) async {
    final list = await entries('savedPages');
    list.removeWhere((entry) => entry.url == url);
    await _write('savedPages', list);
  }

  static Future<void> addHistory(PageEntry entry) async {
    final list = await entries('history');
    list.removeWhere((item) => item.url == entry.url);
    list.insert(0, entry);
    await _write('history', list.take(40).toList());
  }

  static Future<void> clearHistory() async {
    await (await _prefs).remove('history');
  }
}

class ManhwaKuApp extends StatelessWidget {
  const ManhwaKuApp({super.key, this.showLiveHome = true});
  final bool showLiveHome;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ManhwaKu', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: blue, secondary: blue, surface: surface),
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: white, elevation: 0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0D121B),
        indicatorColor: blue.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11, color: states.contains(WidgetState.selected) ? blue : muted,
          fontWeight: FontWeight.w700,
        )),
      ),
    ),
    home: AppShell(showLiveHome: showLiveHome),
  );
}

typedef OpenSource = Future<void> Function(ComicSource source);
typedef OpenComicPage = Future<void> Function(String title, String url, String source);

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.showLiveHome});
  final bool showLiveHome;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;

  Future<void> openSource(ComicSource source) => openPage(source.name, source.url, source.name);

  Future<void> openPage(String title, String url, String source) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => OnlineReader(initialTitle: title, initialUrl: url, sourceName: source),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      child: IndexedStack(index: tab, children: [
        HomePage(onOpen: openSource, live: widget.showLiveHome, onBrowse: () => setState(() => tab = 1)),
        BrowsePage(onOpen: openSource),
        CollectionPage(onOpen: openPage),
      ]),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
        NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Jelajahi'),
        NavigationDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks_rounded), label: 'Koleksi'),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpen, this.live = true, this.onBrowse});
  final OpenSource onOpen;
  final bool live;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    if (live) {
      return HomeLivePage(
        onBrowse: onBrowse ?? () {},
      );
    }
    return HomeCatalogPage(onOpen: onOpen);
  }
}

class HomeLivePage extends StatefulWidget {
  const HomeLivePage({super.key, required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  State<HomeLivePage> createState() => _HomeLivePageState();
}

class _HomeLivePageState extends State<HomeLivePage> {
  late final WebViewController controller;
  String currentUrl = sources.first.url;
  String? errorMessage;
  int progress = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController();
    configure();
  }

  Future<void> configure() async {
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(bg);
      await controller.setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
        onPageStarted: (url) {
          if (!mounted) return;
          setState(() {
            currentUrl = url;
            loading = true;
            progress = 0;
            errorMessage = null;
          });
        },
        onPageFinished: (url) async {
          String title = '';
          try { title = (await controller.getTitle()) ?? ''; } catch (_) {}
          if (!mounted) return;
          setState(() {
            currentUrl = url;
            loading = false;
            progress = 100;
            errorMessage = null;
          });
          await Store.addHistory(PageEntry(
            title: title.trim().isEmpty ? 'WEBTOON' : title.trim(),
            url: url,
            source: 'WEBTOON',
          ));
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            if (!mounted) return;
            setState(() {
              loading = false;
              errorMessage = 'Katalog gagal dimuat. Periksa koneksi atau buka lewat browser.';
            });
          }
        },
      ));
      await controller.loadRequest(Uri.parse(currentUrl));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Situs tidak bisa dibuka di dalam aplikasi.';
      });
    }
  }

  Future<void> openExternal() async {
    final uri = Uri.tryParse(currentUrl);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Browser eksternal tidak tersedia.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(17, top + 7, 9, 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: blue.withValues(alpha: .35)),
                ),
                child: const Icon(Icons.menu_book_rounded, color: blue, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ManhwaKu', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    Text('KATALOG WEBTOON LIVE', style: TextStyle(fontSize: 9, letterSpacing: 1.1, color: muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sumber komik lain',
                onPressed: widget.onBrowse,
                icon: const Icon(Icons.grid_view_rounded, color: blue),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: () => controller.reload(),
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Buka di browser',
                onPressed: openExternal,
                icon: const Icon(Icons.open_in_browser_rounded),
              ),
            ],
          ),
        ),
        if (loading && progress < 100)
          LinearProgressIndicator(
            value: progress == 0 ? null : progress / 100,
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: blue,
          ),
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: controller),
              if (errorMessage != null)
                Positioned.fill(
                  child: Container(
                    color: bg,
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 48, color: blue),
                          const SizedBox(height: 16),
                          const Text('Katalog belum terbuka', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: muted, fontSize: 12, height: 1.45),
                          ),
                          const SizedBox(height: 17),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                errorMessage = null;
                                loading = true;
                                progress = 0;
                              });
                              controller.loadRequest(Uri.parse(currentUrl));
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba lagi'),
                          ),
                          TextButton.icon(
                            onPressed: openExternal,
                            icon: const Icon(Icons.open_in_browser_rounded),
                            label: const Text('Buka di browser'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomeCatalogPage extends StatelessWidget {
  const HomeCatalogPage({super.key, required this.onOpen});
  final OpenSource onOpen;

  @override
  Widget build(BuildContext context) {
    final featured = sources.take(4).toList();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 18),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: .13), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: blue.withValues(alpha: .35)),
            ),
            child: const Icon(Icons.menu_book_rounded, color: blue, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ManhwaKu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5)),
              SizedBox(height: 2),
              Text('SATU TEMPAT UNTUK BACA KOMIK',
                style: TextStyle(fontSize: 9, letterSpacing: 1.3, color: muted, fontWeight: FontWeight.w700)),
            ],
          )),
          IconButton(
            tooltip: 'Buka katalog',
            onPressed: () => onOpen(sources.first),
            icon: const Icon(Icons.search_rounded, color: white),
          ),
        ]),
      )),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF162D46), Color(0xFF101723), Color(0xFF11141D)],
            ),
            border: Border.all(color: blue.withValues(alpha: .2)),
          ),
          child: Stack(children: [
            const Positioned(right: -8, top: -14, child: Icon(
              Icons.auto_stories_rounded, size: 115, color: Color(0x183FB8FF),
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: blue.withValues(alpha: .14), borderRadius: BorderRadius.circular(30)),
                child: const Text('KATALOG ONLINE', style: TextStyle(
                  color: blue, fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w900,
                )),
              ),
              const SizedBox(height: 14),
              const Text('Banyak cerita.\nSatu aplikasi.', style: TextStyle(
                fontSize: 29, height: 1.04, letterSpacing: -.7, fontWeight: FontWeight.w900,
              )),
              const SizedBox(height: 10),
              const Text(
                'Katalog, sampul, dan chapter dimuat langsung dari sumbernya—bukan tiga chapter contoh.',
                style: TextStyle(color: Color(0xFFB9C7D9), height: 1.45, fontSize: 12),
              ),
              const SizedBox(height: 17),
              FilledButton.icon(
                onPressed: () => onOpen(sources.first),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Mulai membaca'),
                style: FilledButton.styleFrom(
                  backgroundColor: blue, foregroundColor: const Color(0xFF05121F),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ]),
          ]),
        ),
      )),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 13),
        child: Row(children: [
          const Expanded(child: Text('Platform komik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          Text(sources.length.toString() + ' sumber', style: const TextStyle(color: muted, fontSize: 11)),
        ]),
      )),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 174,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => SourceCard(source: featured[index], onTap: () => onOpen(featured[index])),
            childCount: featured.length,
          ),
        ),
      ),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sumber lainnya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final source in sources.skip(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SourceListTile(source: source, onTap: () => onOpen(source)),
            ),
          const SizedBox(height: 6),
          const Text(
            'Ketersediaan judul, bahasa, dan chapter mengikuti aturan tiap penerbit. Sebagian cerita gratis, sebagian mungkin memerlukan akun atau akses berbayar.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.45),
          ),
        ]),
      )),
    ]);
  }
}

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key, required this.onOpen});
  final OpenSource onOpen;
  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final search = TextEditingController();
  String category = 'Semua';

  List<ComicSource> get filtered {
    final q = search.text.trim().toLowerCase();
    return sources.where((source) {
      final matchesQuery = q.isEmpty || source.name.toLowerCase().contains(q) ||
          source.subtitle.toLowerCase().contains(q) || source.category.toLowerCase().contains(q);
      final matchesCategory = category == 'Semua' ||
          source.category.toLowerCase().contains(category.toLowerCase());
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final items = filtered;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Jelajahi', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Pilih sumber untuk melihat katalog dan chapter aslinya.',
            style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 18),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari platform atau jenis komik',
              hintStyle: const TextStyle(color: muted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: muted),
              suffixIcon: search.text.isEmpty ? null : IconButton(
                onPressed: () { search.clear(); setState(() {}); },
                icon: const Icon(Icons.close_rounded),
              ),
              filled: true, fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in ['Semua', 'Manga', 'Manhwa', 'Komik'])
              ChoiceChip(
                label: Text(item), selected: category == item,
                onSelected: (_) => setState(() => category = item),
                selectedColor: blue.withValues(alpha: .18),
                labelStyle: TextStyle(
                  color: category == item ? blue : muted, fontSize: 11, fontWeight: FontWeight.w700,
                ),
                side: BorderSide(color: category == item ? blue.withValues(alpha: .6) : line),
                showCheckmark: false,
              ),
          ]),
        ]),
      )),
      if (items.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: EmptyState(
          icon: Icons.search_off_rounded, title: 'Sumber tidak ditemukan',
          message: 'Coba kata kunci atau kategori lain.',
        ))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SourceListTile(source: items[index], onTap: () => widget.onOpen(items[index])),
            ),
            childCount: items.length,
          )),
        ),
    ]);
  }
}

class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.source, required this.onTap});
  final ComicSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: surface, borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: line.withValues(alpha: .8)),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [source.accent.withValues(alpha: .12), surface, surface],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: source.accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)),
              child: Icon(source.icon, color: source.accent, size: 23),
            ),
            const Spacer(),
            const Icon(Icons.north_east_rounded, color: muted, size: 17),
          ]),
          const Spacer(),
          Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(source.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, height: 1.3, fontSize: 10)),
        ]),
      ),
    ),
  );
}

class SourceListTile extends StatelessWidget {
  const SourceListTile({super.key, required this.source, required this.onTap});
  final ComicSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: surface, borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: source.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)),
            child: Icon(source.icon, color: source.accent, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(source.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(source.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 11, height: 1.3)),
            const SizedBox(height: 7),
            Text(source.category + ' • ' + source.language,
              style: TextStyle(color: source.accent, fontSize: 10, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ]),
      ),
    ),
  );
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key, required this.onOpen});
  final OpenComicPage onOpen;
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late Future<List<PageEntry>> saved = Store.entries('savedPages');
  late Future<List<PageEntry>> history = Store.entries('history');

  void reload() {
    if (!mounted) return;
    setState(() {
      saved = Store.entries('savedPages');
      history = Store.entries('history');
    });
  }

  Future<void> openEntry(PageEntry entry) async {
    await widget.onOpen(entry.title, entry.url, entry.source);
    reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<List<PageEntry>>>(
    future: Future.wait([saved, history]),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const EmptyState(
        icon: Icons.error_outline_rounded, title: 'Koleksi gagal dimuat',
        message: 'Coba buka halaman ini kembali.',
      );
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: blue));
      final savedItems = snapshot.data![0];
      final historyItems = snapshot.data![1];
      if (savedItems.isEmpty && historyItems.isEmpty) return const CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 54, 20, 20),
          child: Text('Koleksi', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        )),
        SliverFillRemaining(hasScrollBody: false, child: EmptyState(
          icon: Icons.bookmarks_outlined, title: 'Belum ada koleksi',
          message: 'Buka halaman seri dari sumber komik, lalu tekan ikon bookmark untuk menyimpannya.',
        )),
      ]);
      return CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 54, 20, 20),
          child: Row(children: [
            const Expanded(child: Text('Koleksi', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900))),
            if (historyItems.isNotEmpty) TextButton(
              onPressed: () async { await Store.clearHistory(); reload(); },
              child: const Text('Hapus riwayat'),
            ),
          ]),
        )),
        if (savedItems.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionLabel(title: 'Disimpan')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
              final entry = savedItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: EntryTile(
                  entry: entry, icon: Icons.bookmark_rounded,
                  onTap: () => openEntry(entry),
                  trailing: IconButton(
                    tooltip: 'Hapus bookmark',
                    onPressed: () async { await Store.removeSaved(entry.url); reload(); },
                    icon: const Icon(Icons.bookmark_remove_outlined, color: muted),
                  ),
                ),
              );
            }, childCount: savedItems.length)),
          ),
        ],
        if (historyItems.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionLabel(title: 'Terakhir dibuka')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
              final entry = historyItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: EntryTile(
                  entry: entry, icon: Icons.history_rounded,
                  onTap: () => openEntry(entry),
                ),
              );
            }, childCount: historyItems.length)),
          ),
        ],
      ]);
    },
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
    child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
  );
}

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.icon, required this.onTap, this.trailing});
  final PageEntry entry;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: surface, borderRadius: BorderRadius.circular(15),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: blue.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: blue),
      ),
      title: Text(entry.title.isEmpty ? entry.source : entry.title,
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      subtitle: Text(entry.source, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: muted, fontSize: 10)),
      trailing: trailing,
    ),
  );
}

class OnlineReader extends StatefulWidget {
  const OnlineReader({super.key, required this.initialTitle, required this.initialUrl, required this.sourceName});
  final String initialTitle, initialUrl, sourceName;
  @override
  State<OnlineReader> createState() => _OnlineReaderState();
}

class _OnlineReaderState extends State<OnlineReader> {
  late final WebViewController controller;
  String currentUrl = '';
  String pageTitle = '';
  String? errorMessage;
  int progress = 0;
  bool loading = true, canBack = false, canForward = false, saved = false;

  @override
  void initState() {
    super.initState();
    currentUrl = widget.initialUrl;
    pageTitle = widget.initialTitle;
    controller = WebViewController();
    _configureWebView();
    _refreshSaved();
  }

  Future<void> _configureWebView() async {
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(bg);
    await controller.setNavigationDelegate(NavigationDelegate(
      onProgress: (value) {
        if (!mounted) return;
        setState(() => progress = value);
        _updateNavigationState();
      },
      onPageStarted: (url) {
        if (!mounted) return;
        setState(() { currentUrl = url; loading = true; progress = 0; errorMessage = null; });
      },
      onPageFinished: (url) async {
        String title = '';
        try { title = (await controller.getTitle()) ?? ''; } catch (_) { title = ''; }
        if (!mounted) return;
        setState(() {
          currentUrl = url;
          if (title.trim().isNotEmpty) pageTitle = title.trim();
          loading = false;
          progress = 100;
          errorMessage = null;
        });
        await Store.addHistory(PageEntry(
          title: title.trim().isEmpty ? widget.initialTitle : title.trim(),
          url: url, source: widget.sourceName,
        ));
        _updateNavigationState();
        _refreshSaved();
      },
      onWebResourceError: (error) {
        if (error.isForMainFrame ?? true) {
          if (!mounted) return;
          setState(() {
            loading = false;
            errorMessage = 'Halaman tidak bisa dimuat. Periksa koneksi lalu coba lagi.';
          });
        }
      },
    ));
    try {
      await controller.loadRequest(Uri.parse(widget.initialUrl));
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = 'Alamat sumber tidak bisa dibuka.'; });
    }
  }

  Future<void> _updateNavigationState() async {
    try {
      final back = await controller.canGoBack();
      final forward = await controller.canGoForward();
      if (mounted) setState(() { canBack = back; canForward = forward; });
    } catch (_) {}
  }

  Future<void> _refreshSaved() async {
    final value = await Store.isSaved(currentUrl);
    if (mounted) setState(() => saved = value);
  }

  Future<void> _backOrClose() async {
    try {
      if (await controller.canGoBack()) {
        await controller.goBack();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(currentUrl);
    if (uri == null || !uri.hasScheme) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Browser eksternal tidak tersedia.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka browser eksternal.')),
      );
    }
  }

  Future<void> _toggleSaved() async {
    final title = pageTitle.trim().isEmpty ? widget.initialTitle : pageTitle.trim();
    final result = await Store.toggleSaved(PageEntry(title: title, url: currentUrl, source: widget.sourceName));
    if (!mounted) return;
    setState(() => saved = result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result ? 'Disimpan ke Koleksi' : 'Dihapus dari Koleksi'),
      duration: const Duration(milliseconds: 1200),
    ));
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) { if (!didPop) _backOrClose(); },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Kembali', onPressed: _backOrClose, icon: const Icon(Icons.arrow_back_rounded)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pageTitle.isEmpty ? widget.sourceName : pageTitle, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          Text(widget.sourceName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 10)),
        ]),
        actions: [
          IconButton(
            tooltip: saved ? 'Hapus bookmark' : 'Simpan halaman', onPressed: _toggleSaved,
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? blue : white),
          ),
          IconButton(tooltip: 'Buka di browser', onPressed: _openExternal, icon: const Icon(Icons.open_in_browser_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reload') controller.reload();
              if (value == 'back') controller.goBack();
              if (value == 'forward') controller.goForward();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'reload', child: Text('Muat ulang')),
              PopupMenuItem(value: 'back', enabled: canBack, child: const Text('Halaman sebelumnya')),
              PopupMenuItem(value: 'forward', enabled: canForward, child: const Text('Halaman berikutnya')),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: controller),
        if (loading && progress < 100)
          Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(
            value: progress == 0 ? null : progress / 100, minHeight: 2,
            backgroundColor: Colors.transparent, color: blue,
          )),
        if (errorMessage != null) Positioned.fill(
          child: Container(
            color: bg, padding: const EdgeInsets.all(28),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: blue),
              const SizedBox(height: 17),
              const Text('Koneksi bermasalah', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(errorMessage!, textAlign: TextAlign.center,
                style: const TextStyle(color: muted, height: 1.45, fontSize: 12)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  setState(() { errorMessage = null; loading = true; progress = 0; });
                  controller.loadRequest(Uri.parse(currentUrl));
                },
                icon: const Icon(Icons.refresh_rounded), label: const Text('Coba lagi'),
              ),
              TextButton.icon(onPressed: _openExternal,
                icon: const Icon(Icons.open_in_browser_rounded), label: const Text('Coba browser lain')),
            ])),
          ),
        ),
      ]),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title, message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 50),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(22)),
        child: Icon(icon, color: blue, size: 29),
      ),
      const SizedBox(height: 17),
      Text(title, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      Text(message, textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 12, height: 1.45)),
    ])),
  );
}
