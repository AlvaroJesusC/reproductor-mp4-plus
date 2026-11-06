import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/servicios/servicio_actualizador.dart';

void main() {
  group('ServicioActualizador - Comparación de versiones', () {
    test('Detecta correctamente versiones superiores en parches y menores', () {
      expect(ServicioActualizador.esVersionMayor('1.0.1', '1.0.0'), isTrue);
      expect(ServicioActualizador.esVersionMayor('1.1.0', '1.0.9'), isTrue);
      expect(ServicioActualizador.esVersionMayor('2.0.0', '1.9.9'), isTrue);
    });

    test('Descarta versiones iguales o inferiores', () {
      expect(ServicioActualizador.esVersionMayor('1.0.0', '1.0.0'), isFalse);
      expect(ServicioActualizador.esVersionMayor('1.0.0', '1.0.1'), isFalse);
      expect(ServicioActualizador.esVersionMayor('0.9.9', '1.0.0'), isFalse);
    });

    test('Maneja correctamente sufijos y prefijos (ej: v1.0.2 vs 1.0.1)', () {
      expect(ServicioActualizador.esVersionMayor('v1.0.2', '1.0.1'), isTrue);
      expect(ServicioActualizador.esVersionMayor('1.0.2+3', '1.0.2+1'), isTrue);
      expect(ServicioActualizador.esVersionMayor('1.0.2+1', '1.0.2+3'), isFalse);
    });
  });
}

