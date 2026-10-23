// test/widget_test.dart
//
// Smoke test de arranque: la app construye sin errores con los datos de
// ejemplo cargados, y la navegación inferior cambia de pestaña.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('arranca en el dashboard y navega a Clientes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es_ES', null);
    final appData = await AppData.bootstrap();

    await tester.pumpWidget(OficioAiApp(appData: appData));
    await tester.pumpAndSettle();

    expect(find.text('Hola de nuevo'), findsOneWidget);

    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();

    expect(find.text('Marta Iglesias'), findsOneWidget);
  });
}
