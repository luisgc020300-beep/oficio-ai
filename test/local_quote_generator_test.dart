// test/local_quote_generator_test.dart
//
// Cobertura mínima exigida (sección 8 del encargo) para el generador
// local de propuestas de presupuesto.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/assistant/local_quote_generator.dart';
import 'package:oficio_ai/data/assistant/propuesta_presupuesto.dart';
import 'package:oficio_ai/data/repositories/presupuesto_repository.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final generador = LocalQuoteGenerator();

  group('LocalQuoteGenerator', () {
    test('descripción reconocible de fontanería', () async {
      final propuesta = await generador.generar(
        'Necesito cambiar el grifo de la cocina',
      );

      expect(propuesta.confianza, NivelConfianza.alta);
      expect(propuesta.conceptos, isNotEmpty);
      expect(
        propuesta.conceptos.any(
          (c) => c.descripcion.toLowerCase().contains('grifo'),
        ),
        isTrue,
      );
    });

    test('descripción reconocible de electricidad', () async {
      final propuesta = await generador.generar(
        'Quiero instalar una lámpara nueva en el salón',
      );

      expect(propuesta.confianza, NivelConfianza.alta);
      expect(
        propuesta.conceptos.any(
          (c) => c.descripcion.toLowerCase().contains('lámpara'),
        ),
        isTrue,
      );
    });

    test('descripción con varios conceptos reconoce ambos', () async {
      final propuesta = await generador.generar(
        'Cambiar el grifo de la cocina y revisar una fuga en el baño',
      );

      expect(propuesta.confianza, NivelConfianza.alta);
      // Grifo (2 líneas) + fuga (2 líneas) -- al menos 3 para no acoplar
      // el test al número exacto de líneas del catálogo.
      expect(propuesta.conceptos.length, greaterThanOrEqualTo(3));
      expect(
        propuesta.conceptos.any((c) => c.descripcion.toLowerCase().contains('grifo')),
        isTrue,
      );
      expect(
        propuesta.conceptos.any((c) => c.descripcion.toLowerCase().contains('fuga')),
        isTrue,
      );
    });

    test('descripción vacía lanza ArgumentError', () {
      expect(() => generador.generar(''), throwsArgumentError);
    });

    test('descripción formada solo por espacios lanza ArgumentError', () {
      expect(() => generador.generar('    '), throwsArgumentError);
    });

    test('descripción desconocida o ambigua da confianza baja y propuesta genérica editable', () async {
      final propuesta = await generador.generar(
        'Necesito que vengas a ver una cosa rara que me pasa en casa',
      );

      expect(propuesta.confianza, NivelConfianza.baja);
      expect(propuesta.conceptos, isNotEmpty);
      expect(propuesta.mensaje, isNotEmpty);
      // Nunca debe presentarse como un precio real verificado.
      expect(propuesta.conceptos.first.precioUnitario, 0);
    });

    test('las cantidades y precios generados son válidos (finitos y no negativos)', () async {
      final propuesta = await generador.generar('Cambiar el grifo de la cocina');

      for (final c in propuesta.conceptos) {
        expect(c.cantidad.isFinite, isTrue);
        expect(c.cantidad, greaterThan(0));
        expect(c.precioUnitario.isFinite, isTrue);
        expect(c.precioUnitario, greaterThanOrEqualTo(0));
      }
    });

    test('generar() no guarda nada -- no toca ningún repositorio', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final repo = PresupuestoRepository(store);
      await repo.load();
      expect(repo.presupuestos, isEmpty);

      await generador.generar('Cambiar el grifo de la cocina');

      // El generador ni siquiera conoce el repositorio -- confirmamos
      // que uno nuevo, nunca usado, sigue vacío tras generar.
      expect(repo.presupuestos, isEmpty);
    });

    test('el resultado se puede editar antes de guardarlo (conceptos son copiables)', () async {
      final propuesta = await generador.generar('Cambiar el grifo de la cocina');
      final original = propuesta.conceptos.first;

      final editado = original.copyWith(
        descripcion: 'Grifo de cocina (modelo elegido por el cliente)',
        cantidad: 2,
        precioUnitario: 60,
      );

      expect(editado.descripcion, 'Grifo de cocina (modelo elegido por el cliente)');
      expect(editado.cantidad, 2);
      expect(editado.precioUnitario, 60);
      // El original no cambia -- son objetos inmutables, como el resto
      // del modelo de datos de la app.
      expect(original.cantidad, isNot(2));
    });
  });
}
