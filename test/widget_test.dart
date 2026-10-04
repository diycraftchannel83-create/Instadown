import 'package:flutter_test/flutter_test.dart';
import 'package:instadown/main.dart';

void main() {
  testWidgets('InstaDown renders', (tester) async {
    await tester.pumpWidget(const InstaDownApp());
    expect(find.text('InstaDown'), findsOneWidget);
    expect(find.text('Download video publik'), findsOneWidget);
  });
}
