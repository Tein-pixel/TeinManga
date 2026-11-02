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
    expect(find.text('MULTI-SOURCE CATALOG'), findsOneWidget);
    expect(find.text('WEBTOON ORIGINAL'), findsNothing);
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
