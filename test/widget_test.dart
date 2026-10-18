import 'package:flutter_test/flutter_test.dart';

import 'package:reset_app/main.dart';

void main() {
  testWidgets('shows setup page when supabase is not configured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ResetApp(configured: false));

    expect(find.text('RESET.'), findsOneWidget);
    expect(find.text('Supabase belum dikonfigurasi.'), findsOneWidget);
  });
}
