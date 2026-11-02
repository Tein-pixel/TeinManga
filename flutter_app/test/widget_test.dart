import 'package:flutter_test/flutter_test.dart';
import 'package:reader/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ManhwaKu loads the initial tab without network calls', (tester) async {
    await tester.pumpWidget(const ManhwaKuApp(testMode: true));
    await tester.pumpAndSettle();

    expect(find.text('ManhwaKu'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('BARU & HOT'), findsOneWidget);
    expect(find.text('CARI'), findsOneWidget);
    expect(find.text('KOLEKSI'), findsOneWidget);
    expect(find.text('RIWAYAT'), findsOneWidget);
    expect(find.text('Baru diperbarui'), findsOneWidget);
    expect(find.text('WEBTOON ORIGINAL'), findsNothing);
  });


  test('MangaBaka v2 parses multilingual title and cover fields', () {
    final item = SeriesItem.fromMangaBakaV2({
      'id': 123,
      'titles': [
        {'language': 'ko', 'title': '룩즘', 'is_primary': true},
        {'language': 'en', 'title': 'Lookism', 'is_primary': true},
      ],
      'type': 'manhwa',
      'canonical_url': 'https://mangabaka.org/series/123',
      'cover': {
        'x350': {
          'x1': 'https://img.example/cover-1x.jpg',
          'x2': 'https://img.example/cover-2x.jpg',
          'x3': 'https://img.example/cover-3x.jpg',
        },
      },
      'description': 'A school drama.',
      'status': 'completed',
      'rating': 86,
      'authors': ['PARK Tae Jun'],
      'original_language': 'ko',
      'content_rating': 'safe',
    });
    expect(item.title, 'Lookism');
    expect(item.cover, 'https://img.example/cover-2x.jpg');
    expect(item.coverLarge, 'https://img.example/cover-3x.jpg');
    expect(item.description, 'A school drama.');
    expect(item.type, 'manhwa');
    expect(item.language, 'ko');
    expect(item.mangaBakaId, 123);
  });

  test('MangaDex synopsis falls back to the original language', () {
    final item = SeriesItem.fromMangaDex({
      'id': '11111111-2222-4333-8444-555555555555',
      'attributes': {
        'title': {'en': 'Test Manhwa', 'ko': '테스트 만화'},
        'description': {'ko': '한국어 시놉시스'},
        'originalLanguage': 'ko',
        'availableTranslatedLanguages': ['en', 'ko'],
        'contentRating': 'safe',
        'status': 'completed',
      },
      'relationships': [],
    });
    expect(item.description, '한국어 시놉시스');
    expect(item.availableTranslatedLanguages, containsAll(['en', 'ko']));
  });

  test('MangaDex keeps a compact cover and an original detail cover', () {
    final item = SeriesItem.fromMangaDex({
      'id': '11111111-2222-4333-8444-555555555555',
      'attributes': {
        'title': {'en': 'Cover test'},
        'description': {},
        'originalLanguage': 'ja',
        'availableTranslatedLanguages': ['id'],
        'contentRating': 'safe',
      },
      'relationships': [
        {'type': 'cover_art', 'attributes': {'fileName': 'cover-file.jpg'}},
      ],
    });
    expect(item.cover, endsWith('cover-file.jpg.512.jpg'));
    expect(item.coverLarge, endsWith('/cover-file.jpg'));
  });

  test('MangaDex marks titles with restricted safety tags as blocked', () {
    final item = SeriesItem.fromMangaDex({
      'id': '11111111-2222-4333-8444-555555555555',
      'attributes': {
        'title': {'en': 'Restricted tag test'},
        'description': {},
        'originalLanguage': 'ko',
        'availableTranslatedLanguages': ['ko'],
        'contentRating': 'safe',
        'tags': [
          {'attributes': {'name': {'en': 'Gore'}}},
        ],
      },
      'relationships': [],
    });
    expect(item.contentRating, 'blocked');
  });


  test('MangaBaka records without a rating are not considered safe', () {
    final item = SeriesItem.fromMangaBakaV2({
      'id': 124,
      'titles': [
        {'language': 'en', 'title': 'Unrated sample', 'is_primary': true},
      ],
      'type': 'manga',
      'original_language': 'ja',
    });
    expect(item.contentRating, 'unknown');
  });

  test('Publisher URLs must be HTTPS and explicitly marked publisher', () {
    final item = SeriesItem.fromMangaBakaV2({
      'id': 125,
      'titles': [
        {'language': 'en', 'title': 'Publisher sample', 'is_primary': true},
      ],
      'type': 'manga',
      'original_language': 'ja',
      'content_rating': 'safe',
      'links_v2': [
        {'type': 'webplatform', 'trust_level': 'official', 'status': 'active', 'url': 'https://reader.example/series/1'},
        {'type': 'publisher', 'trust_level': 'neutral', 'status': 'active', 'url': 'https://unverified.example/work/1'},
        {'type': 'publisher', 'trust_level': 'official', 'status': 'active', 'url': 'http://publisher.example/work/1'},
      ],
    });
    expect(item.publisherUrl, 'https://reader.example/series/1');
  });

  test('Indonesian is the first chapter-language preference', () {
    expect(MangaDexChapterPage.preferredLanguage, 'id');
  });

  test('MangaDex records without an explicit rating remain unknown', () {
    final item = SeriesItem.fromMangaDex({
      'id': '11111111-2222-4333-8444-555555555555',
      'attributes': {
        'title': {'en': 'Unrated MangaDex sample'},
        'description': {},
        'originalLanguage': 'ja',
        'availableTranslatedLanguages': ['en'],
      },
      'relationships': [],
    });
    expect(item.contentRating, 'unknown');
  });

  test('Reading status is exclusive and persists locally', () async {
    final item = SeriesItem(
      id: 77,
      title: 'Test series',
      type: 'manga',
      url: 'https://example.invalid/series/77',
      cover: '',
      description: '',
      status: 'releasing',
      rating: null,
      author: '',
      language: 'ja',
      contentRating: 'safe',
      source: 'unit-test',
    );

    await LocalLibrary.setStatus(item, 'planned');
    expect(await LocalLibrary.statusFor(item.id), 'planned');
    await LocalLibrary.setStatus(item, 'reading');
    expect(await LocalLibrary.statusFor(item.id), 'reading');
    expect((await LocalLibrary.read('planned')), isEmpty);
    expect((await LocalLibrary.read('reading')).single.id, item.id);
    await LocalLibrary.setStatus(item, 'none');
    expect(await LocalLibrary.statusFor(item.id), 'none');
  });
}
