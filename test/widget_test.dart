import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/main.dart';

void main() {
  testWidgets('Verifica inicio de la aplicación del Reproductor MP4', (WidgetTester tester) async {
    // Construir la aplicación y verificar inicialización
    await tester.pumpWidget(const AplicacionReproductorMP4());

    // Verificar que el título de la aplicación se encuentra en el árbol de widgets
    expect(find.text('Reproductor MP4'), findsWidgets);
  });
}
