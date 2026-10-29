import 'package:flutter_test/flutter_test.dart';
import 'package:reader/main.dart';

void main() {
  testWidgets('ManhwaKu opens live comic sources without demo chapters', (tester) async {
    await tester.pumpWidget(const ManhwaKuApp(showLiveHome: false));
    await tester.pump();

    expect(find.text('ManhwaKu'), findsOneWidget);
    expect(find.text('Platform komik'), findsOneWidget);
    expect(find.text('WEBTOON'), findsOneWidget);
    expect(find.text('MANGA Plus'), findsOneWidget);
    expect(find.text('Mulai membaca'), findsOneWidget);
  });
}
