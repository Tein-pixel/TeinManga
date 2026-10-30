import 'package:flutter_test/flutter_test.dart';
import 'package:reader/main.dart';

void main() {
  testWidgets('ManhwaKu opens the native discovery interface', (tester) async {
    await tester.pumpWidget(const ManhwaKuApp());
    await tester.pump();

    expect(find.text('ManhwaKu'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('BARU & HOT'), findsOneWidget);
    expect(find.text('CARI'), findsOneWidget);
    expect(find.text('FAVORIT'), findsOneWidget);
    expect(find.text('RIWAYAT'), findsOneWidget);
  });
}
