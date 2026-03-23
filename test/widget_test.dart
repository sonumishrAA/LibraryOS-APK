import 'package:flutter_test/flutter_test.dart';
import 'package:libraryos/main.dart';

void main() {
  testWidgets('LibraryOS home screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LibraryOSApp());

    // Verify that 'LibraryOS' is present.
    expect(find.text('LibraryOS'), findsAtLeastNWidgets(1));
    
    // Verify 'Get Started Free' button is present.
    expect(find.text('Get Started Free'), findsOneWidget);
  });
}
