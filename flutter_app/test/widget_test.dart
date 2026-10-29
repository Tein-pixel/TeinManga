import 'package:flutter_test/flutter_test.dart';
import 'package:reader/main.dart';

void main() {
  testWidgets('ManhwaKu opens home and bundled chapters', (tester) async {
    await tester.pumpWidget(const ManhwaKuApp());
    // Use fixed pumps: progress indicators in async asset loading may animate continuously.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ManhwaKu'), findsWidgets);
    expect(find.text('Daftar Chapter'), findsOneWidget);
  });
}
