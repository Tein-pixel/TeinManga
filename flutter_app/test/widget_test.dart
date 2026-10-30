import 'package:flutter_test/flutter_test.dart';
import 'package:reader/main.dart';

void main() {
  testWidgets('ManhwaKu shows main navigation and official WEBTOON picks', (tester) async {
    await tester.pumpWidget(const ManhwaKuApp());
    await tester.pump();

    expect(find.text('ManhwaKu'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('BARU & HOT'), findsOneWidget);
    expect(find.text('CARI'), findsOneWidget);
    expect(find.text('FAVORIT'), findsOneWidget);
    expect(find.text('RIWAYAT'), findsOneWidget);
    expect(find.text('WEBTOON ORIGINAL'), findsOneWidget);
    expect(find.text('LOOKISM'), findsOneWidget);
    expect(find.text('Eleceed'), findsOneWidget);
  });
}
