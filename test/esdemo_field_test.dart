// test/esdemo_field_test.dart
//
// El campo esDemo (añadido en esta iteración para distinguir datos de
// ejemplo de datos reales) debe: (a) ser false por defecto en cualquier
// dato nuevo, (b) sobrevivir a un ciclo toJson/fromJson, y (c) leerse
// como false -- nunca lanzar -- en datos guardados ANTES de que este
// campo existiera, para no romper la persistencia ya guardada por un
// usuario real.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/models/cita.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/presupuesto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';

void main() {
  group('esDemo', () {
    test('Cliente: false por defecto y persiste en JSON', () {
      final cliente = Cliente(id: '1', nombre: 'Ana', creadoEl: DateTime(2026));
      expect(cliente.esDemo, isFalse);

      final demo = Cliente(
        id: '2',
        nombre: 'Demo',
        creadoEl: DateTime(2026),
        esDemo: true,
      );
      final restaurado = Cliente.fromJson(demo.toJson());
      expect(restaurado.esDemo, isTrue);
    });

    test('Cliente: JSON guardado antes de este campo se lee como false', () {
      final jsonAntiguo = {
        'id': '1',
        'nombre': 'Ana',
        'creadoEl': DateTime(2026).toIso8601String(),
        // sin 'esDemo' -- así se guardaba antes de esta iteración
      };
      expect(Cliente.fromJson(jsonAntiguo).esDemo, isFalse);
    });

    test('Trabajo: persiste en JSON', () {
      final trabajo = Trabajo(
        id: '1',
        clienteId: 'c1',
        titulo: 'Reparación',
        estado: EstadoTrabajo.pendiente,
        creadoEl: DateTime(2026),
        esDemo: true,
      );
      expect(Trabajo.fromJson(trabajo.toJson()).esDemo, isTrue);
    });

    test('Trabajo: JSON antiguo sin el campo no rompe la lectura', () {
      final jsonAntiguo = {
        'id': '1',
        'clienteId': 'c1',
        'titulo': 'Reparación',
        'estado': 'pendiente',
        'creadoEl': DateTime(2026).toIso8601String(),
      };
      expect(Trabajo.fromJson(jsonAntiguo).esDemo, isFalse);
    });

    test('Presupuesto: persiste en JSON', () {
      final presupuesto = Presupuesto(
        id: '1',
        clienteId: 'c1',
        titulo: 'Presupuesto',
        conceptos: const [],
        estado: EstadoPresupuesto.borrador,
        creadoEl: DateTime(2026),
        esDemo: true,
      );
      expect(Presupuesto.fromJson(presupuesto.toJson()).esDemo, isTrue);
    });

    test('Cita: persiste en JSON y por defecto es false', () {
      final cita = Cita(
        id: '1',
        titulo: 'Visita',
        fechaHora: DateTime(2026),
      );
      expect(cita.esDemo, isFalse);

      final demo = Cita(
        id: '2',
        titulo: 'Visita demo',
        fechaHora: DateTime(2026),
        esDemo: true,
      );
      expect(Cita.fromJson(demo.toJson()).esDemo, isTrue);
    });
  });
}
