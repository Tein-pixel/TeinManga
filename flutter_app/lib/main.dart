import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bg = Color(0xFF080B11), surface = Color(0xFF141A24), surface2 = Color(0xFF1B2431), blue = Color(0xFF48B7FF), white = Color(0xFFF4F8FF), muted = Color(0xFF9AAAC0);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:bg,statusBarIconBrightness:Brightness.light,systemNavigationBarColor:bg,systemNavigationBarIconBrightness:Brightness.light));
  runApp(const ManhwaKuApp());
}
class Chapter {
  const Chapter({required this.id,required this.title,required this.date,required this.description,required this.thumbnail,required this.images});
  final String id,title,date,description,thumbnail; final List<String> images;
  factory Chapter.fromJson(Map<String,dynamic> j)=>Chapter(id:j['id'] as String,title:j['title'] as String,date:j['date'] as String,description:j['description'] as String,thumbnail:(j['thumbnail']??j['thumb']) as String,images:(j['images'] as List<dynamic>).cast<String>());
}
Future<List<Chapter>> loadChapters() async { final raw=await rootBundle.loadString('assets/chapters.json'); return (jsonDecode(raw) as List<dynamic>).map((e)=>Chapter.fromJson(e as Map<String,dynamic>)).toList(); }
class Store {
 static Future<SharedPreferences> get p=>SharedPreferences.getInstance();
 static Future<Set<String>> bookmarks() async => ((await p).getStringList('bookmarks')??<String>[]).toSet();
 static Future<void> toggle(String id) async { final x=await p; final s=(x.getStringList('bookmarks')??<String>[]).toSet(); s.contains(id)?s.remove(id):s.add(id); await x.setStringList('bookmarks',s.toList()); }
 static Future<List<String>> history() async => (await p).getStringList('history')??<String>[];
 static Future<void> read(String id) async { final x=await p; final h=(x.getStringList('history')??<String>[]).where((e)=>e!=id).toList()..insert(0,id); await x.setStringList('history',h.take(50).toList()); await x.setString('resume',id); }
 static Future<int> progress(String id) async => (await p).getInt('progress.$id')??0;
 static Future<void> saveProgress(String id,int n) async => (await p).setInt('progress.$id',n);
}
class ManhwaKuApp extends StatelessWidget { const ManhwaKuApp({super.key}); @override Widget build(BuildContext context)=>MaterialApp(title:'ManhwaKu',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:const ColorScheme.dark(primary:blue,surface:surface),fontFamily:'sans-serif',appBarTheme:const AppBarTheme(backgroundColor:bg,foregroundColor:white,elevation:0),navigationBarTheme:NavigationBarThemeData(backgroundColor:const Color(0xFF0D121B),indicatorColor:blue.withValues(alpha:.16),labelTextStyle:WidgetStateProperty.resolveWith((s)=>TextStyle(fontSize:11,color:s.contains(WidgetState.selected)?blue:muted,fontWeight:FontWeight.w600)))),home:const Splash()); }
class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState()=>_SplashState(); }
class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
 late final AnimationController c=AnimationController(vsync:this,duration:const Duration(milliseconds:1800))..forward();
 @override void initState(){super.initState();Future.delayed(const Duration(milliseconds:2050),(){if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const Shell()));});}
 @override void dispose(){c.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(body:Center(child:FadeTransition(opacity:c,child:ScaleTransition(scale:CurvedAnimation(parent:c,curve:Curves.easeOutBack),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:100,height:100,decoration:BoxDecoration(shape:BoxShape.circle,boxShadow:[BoxShadow(color:blue.withValues(alpha:.22),blurRadius:30)]),child:ClipOval(child:SvgPicture.asset('assets/logo.svg'))),const SizedBox(height:18),const Text('ManhwaKu',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),const SizedBox(height:6),const Text('YOUR STORY. YOUR WORLD.',style:TextStyle(fontSize:10,letterSpacing:2.4,color:muted))])))));
}
class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState()=>_ShellState(); }
class _ShellState extends State<Shell> { int tab=0; late Future<List<Chapter>> chapters=loadChapters(); void refresh()=>setState((){chapters=loadChapters();}); @override Widget build(BuildContext context)=>FutureBuilder<List<Chapter>>(future:chapters,builder:(context,s){if(s.hasError)return Scaffold(body:Center(child:Text('Gagal memuat chapter: ${s.error}')));if(!s.hasData)return const Scaffold(body:Center(child:CircularProgressIndicator(color:blue)));final cs=s.data!;return Scaffold(body:SafeArea(top:false,child:IndexedStack(index:tab,children:[Home(chapters:cs,onChanged:refresh),Library(chapters:cs,bookmarks:true,onChanged:refresh),Library(chapters:cs,bookmarks:false,onChanged:refresh)])),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.explore_outlined),selectedIcon:Icon(Icons.explore),label:'Home'),NavigationDestination(icon:Icon(Icons.bookmark_border_rounded),selectedIcon:Icon(Icons.bookmark_rounded),label:'Bookmark'),NavigationDestination(icon:Icon(Icons.history_rounded),selectedIcon:Icon(Icons.history),label:'History') ]));}); }
class Home extends StatefulWidget {
  const Home({super.key, required this.chapters, required this.onChanged});
  final List<Chapter> chapters;
  final VoidCallback onChanged;
  @override
  State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  Future<void> open(Chapter chapter) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Reader(chapters: widget.chapters, chapter: chapter)));
    widget.onChanged();
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final hero = widget.chapters.first;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _header()),
      SliverToBoxAdapter(child: _heroCard(hero)),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(children: [
          const Expanded(child: Text('Daftar Chapter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Text('${widget.chapters.length} chapter', style: const TextStyle(color: muted, fontSize: 11)),
        ]),
      )),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        sliver: SliverList(delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tile(chapter: widget.chapters[index], onTap: () => open(widget.chapters[index]), onChanged: () { setState(() {}); widget.onChanged(); }),
          ),
          childCount: widget.chapters.length,
        )),
      ),
    ]);
  }
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
    child: Row(children: [
      ClipOval(child: SizedBox(width: 38, height: 38, child: SvgPicture.asset('assets/logo.svg'))),
      const SizedBox(width: 11),
      const Expanded(child: Text('ManhwaKu', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.4))),
      IconButton(onPressed: () async {
        final chapter = await showSearch<Chapter?>(context: context, delegate: SearchChapters(widget.chapters));
        if (chapter != null && mounted) open(chapter);
      }, icon: const Icon(Icons.search_rounded, color: white, size: 25)),
    ]),
  );
  Widget _heroCard(Chapter hero) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(height: 270, child: Stack(fit: StackFit.expand, children: [
        SvgPicture.asset(hero.thumbnail, fit: BoxFit.cover),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, bg.withValues(alpha: .4), bg], stops: const [0, .5, 1],
        ))),
        Positioned(left: 18, right: 18, bottom: 18, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: blue.withValues(alpha: .18), borderRadius: BorderRadius.circular(20), border: Border.all(color: blue.withValues(alpha: .5))),
              child: const Text('MANHWAKU ORIGINAL', style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: blue)),
            ),
            const SizedBox(height: 9),
            const Text('Cahaya Pertama', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 5),
            const Text('Sebuah kisah misteri dengan cahaya yang mengubah segalanya.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFCFD8E6), fontSize: 12, height: 1.35)),
            const SizedBox(height: 12),
            SizedBox(height: 40, child: FilledButton.icon(
              onPressed: () => open(hero), icon: const Icon(Icons.play_arrow_rounded, size: 21),
              label: const Text('Baca sekarang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: blue, foregroundColor: const Color(0xFF06111D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            )),
          ],
        )),
      ])),
    ),
  );
}
class SearchChapters extends SearchDelegate<Chapter?> {
  SearchChapters(this.chapters);
  final List<Chapter> chapters;
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.close))];
  @override Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context) => _results(context);
  @override Widget buildSuggestions(BuildContext context) => _results(context);
  Widget _results(BuildContext context) {
    final matches = chapters.where((chapter) => chapter.title.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(itemCount: matches.length, itemBuilder: (context, index) => Tile(
      chapter: matches[index], onTap: () => close(context, matches[index]), onChanged: () {},
    ));
  }
}
class Tile extends StatefulWidget {
  const Tile({super.key, required this.chapter, required this.onTap, required this.onChanged});
  final Chapter chapter;
  final VoidCallback onTap;
  final VoidCallback onChanged;
  @override
  State<Tile> createState() => _TileState();
}

class _TileState extends State<Tile> {
  bool saved = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final bookmarks = await Store.bookmarks();
    if (mounted) setState(() => saved = bookmarks.contains(widget.chapter.id));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  width: 76,
                  height: 94,
                  child: SvgPicture.asset(widget.chapter.thumbnail, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.chapter.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.25, fontWeight: FontWeight.w700, color: white)),
                    const SizedBox(height: 7),
                    Text(widget.chapter.date, style: const TextStyle(fontSize: 10, color: muted)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.menu_book_rounded, size: 13, color: blue),
                      const SizedBox(width: 5),
                      Text('${widget.chapter.images.length} halaman', style: const TextStyle(fontSize: 10, color: muted)),
                    ]),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Store.toggle(widget.chapter.id);
                  if (mounted) setState(() => saved = !saved);
                  widget.onChanged();
                },
                icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? blue : muted, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Library extends StatefulWidget { const Library({super.key,required this.chapters,required this.bookmarks,required this.onChanged});final List<Chapter> chapters;final bool bookmarks;final VoidCallback onChanged;@override State<Library> createState()=>_LibraryState(); }
class _LibraryState extends State<Library> {
  Future<List<Chapter>> items() async {
    final ids = widget.bookmarks ? (await Store.bookmarks()).toList() : await Store.history();
    return ids.map((id) => widget.chapters.where((chapter) => chapter.id == id)).expand((items) => items).toList();
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Chapter>>(
    key: ValueKey(widget.bookmarks.toString() + widget.chapters.length.toString() + DateTime.now().minute.toString()),
    future: items(),
    builder: (context, snapshot) => CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.bookmarks ? 'Bookmark' : 'Riwayat baca', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          const SizedBox(height: 5),
          Text(widget.bookmarks ? 'Chapter yang kamu simpan' : 'Lanjutkan cerita terakhir', style: const TextStyle(color: muted, fontSize: 12)),
        ]),
      )),
      if (!snapshot.hasData)
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: blue)))),
      if (snapshot.hasData && snapshot.data!.isEmpty)
        SliverToBoxAdapter(child: Empty(
          icon: widget.bookmarks ? Icons.bookmark_border_rounded : Icons.history_rounded,
          title: widget.bookmarks ? 'Belum ada bookmark' : 'Belum ada riwayat',
          subtitle: widget.bookmarks ? 'Simpan chapter lewat ikon bookmark.' : 'Chapter yang kamu baca akan muncul di sini.',
        )),
      if (snapshot.hasData)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final chapter = snapshot.data![index];
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: Tile(
              chapter: chapter,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => Reader(chapters: widget.chapters, chapter: chapter)));
                if (mounted) setState(() {});
                widget.onChanged();
              },
              onChanged: () => setState(() {}),
            ));
          }, childCount: snapshot.data!.length)),
        ),
    ]),
  );
}
class Reader extends StatefulWidget {
  const Reader({super.key, required this.chapters, required this.chapter});
  final List<Chapter> chapters;
  final Chapter chapter;
  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> {
  late Chapter current = widget.chapter;
  final ScrollController scroll = ScrollController();
  int page = 0;
  bool saved = false;
  bool showBar = true;

  double get pageHeight => MediaQuery.sizeOf(context).width * 1600 / 900;

  @override
  void initState() {
    super.initState();
    scroll.addListener(onScroll);
    prepare();
  }

  Future<void> prepare() async {
    await Store.read(current.id);
    final savedPage = await Store.progress(current.id);
    final bookmarks = await Store.bookmarks();
    if (!mounted) return;
    setState(() {
      page = savedPage.clamp(0, current.images.length - 1).toInt();
      saved = bookmarks.contains(current.id);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients && page > 0) {
        scroll.jumpTo((page * pageHeight).clamp(0, scroll.position.maxScrollExtent).toDouble());
      }
    });
  }

  void onScroll() {
    if (!scroll.hasClients) return;
    final nextPage = (scroll.offset / pageHeight).floor().clamp(0, current.images.length - 1).toInt();
    if (nextPage != page) {
      setState(() => page = nextPage);
      Store.saveProgress(current.id, nextPage);
    }
  }

  Future<void> switchChapter(int delta) async {
    final nextIndex = widget.chapters.indexOf(current) + delta;
    if (nextIndex < 0 || nextIndex >= widget.chapters.length) return;
    final nextChapter = widget.chapters[nextIndex];
    await Store.read(nextChapter.id);
    final savedPage = await Store.progress(nextChapter.id);
    if (!mounted) return;
    setState(() {
      current = nextChapter;
      page = savedPage.clamp(0, nextChapter.images.length - 1).toInt();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.jumpTo(0);
      if (page > 0) {
        scroll.jumpTo((page * pageHeight).clamp(0, scroll.position.maxScrollExtent).toDouble());
      }
    });
    final bookmarks = await Store.bookmarks();
    if (mounted) setState(() => saved = bookmarks.contains(nextChapter.id));
  }

  @override
  void dispose() {
    scroll.removeListener(onScroll);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => showBar = !showBar),
            child: ListView.builder(
              controller: scroll,
              padding: EdgeInsets.zero,
              itemCount: current.images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 3,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: SvgPicture.asset(
                    current.images[index],
                    width: MediaQuery.sizeOf(context).width,
                    fit: BoxFit.fitWidth,
                    placeholderBuilder: (_) => const AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Center(child: CircularProgressIndicator(color: blue)),
                    ),
                  ),
                );
              },
            ),
          ),
          if (showBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 4, 14, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: .9), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: white)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (page + 1) / current.images.length,
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                              color: blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${page + 1}/${current.images.length}', style: const TextStyle(fontSize: 11, color: white)),
                  ],
                ),
              ),
            ),
          if (showBar)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xE6141B27),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 22)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => switchChapter(-1),
                      icon: const Icon(Icons.skip_previous_rounded),
                      color: current == widget.chapters.first ? muted : white,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        await Store.toggle(current.id);
                        final bookmarks = await Store.bookmarks();
                        if (mounted) setState(() => saved = bookmarks.contains(current.id));
                      },
                      icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? blue : white),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => switchChapter(1),
                      icon: const Icon(Icons.skip_next_rounded),
                      color: current == widget.chapters.last ? muted : white,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Empty extends StatelessWidget { const Empty({super.key,required this.icon,required this.title,required this.subtitle});final IconData icon;final String title,subtitle;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(horizontal:32,vertical:70),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:66,height:66,decoration:BoxDecoration(color:surface2,borderRadius:BorderRadius.circular(22)),child:Icon(icon,color:blue,size:28)),const SizedBox(height:16),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:muted,fontSize:12,height:1.4))]));}
