import 'package:flutter_test/flutter_test.dart';
import 'package:reader/main.dart';

void main() {
  testWidgets('ManhwaKu opens home and bundled chapters', (tester) async {
    await tester.pumpWidget(const ManhwaKuApp());
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
    expect(find.text('ManhwaKu'), findsWidgets);
    expect(find.text('Daftar Chapter'), findsOneWidget);
  });
}
