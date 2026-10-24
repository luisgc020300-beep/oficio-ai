// test/gasto_model_test.dart
//
// Modelo Gasto en aislamiento: ciclo toJson/fromJson, categorías,
// estado de anulación y compatibilidad con JSON guardado antes de
// que existiera este modelo o alguno de sus campos opcionales
// (encargo iteración 9, secciones 1 y 2).
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/models/gasto.dart';

Gasto _gastoBase({
  String id = 'g1',
  String descripcion = 'Material de fontanería',
  double importe = 45.5,
  DateTime? fecha,
  CategoriaGasto categoria = CategoriaGasto.materiales,
  String? proveedor,
  String? notas,
  String? trabajoId,
  EstadoGasto estado = EstadoGasto.activo,
  String? motivoAnulacion,
  DateTime? fechaAnulacion,
}) => Gasto(
  id: id,
  descripcion: descripcion,
  importe: importe,
  fecha: fecha ?? DateTime(2026, 3, 1),
  categoria: categoria,
  proveedor: proveedor,
  notas: notas,
  trabajoId: trabajoId,
  creadoEl: DateTime(2026, 3, 1),
  estado: estado,
  motivoAnulacion: motivoAnulacion,
  fechaAnulacion: fechaAnulacion,
);

void main() {
  group('categorías', () {
    test('las 6 categorías iniciales existen con nombre legible', () {
      expect(CategoriaGasto.values, hasLength(6));
      expect(nombreCategoriaGasto(CategoriaGasto.materiales), 'Materiales');
      expect(nombreCategoriaGasto(CategoriaGasto.desplazamiento), 'Desplazamiento');
      expect(nombreCategoriaGasto(CategoriaGasto.herramientas), 'Herramientas');
      expect(nombreCategoriaGasto(CategoriaGasto.subcontratacion), 'Subcontratación');
      expect(nombreCategoriaGasto(CategoriaGasto.suministros), 'Suministros');
      expect(nombreCategoriaGasto(CategoriaGasto.otros), 'Otros');
    });

    test('categoriaGastoFromString cae a "otros" ante un valor '
        'desconocido o nulo', () {
      expect(categoriaGastoFromString(null), CategoriaGasto.otros);
      expect(categoriaGastoFromString('inventada'), CategoriaGasto.otros);
      expect(categoriaGastoFromString('materiales'), CategoriaGasto.materiales);
    });
  });

  group('ciclo toJson/fromJson', () {
    test('todos los campos, incluidos los opcionales, sobreviven', () {
      final g = _gastoBase(
        proveedor: 'Ferretería Central',
        notas: 'Pagado en efectivo',
        trabajoId: 't1',
      );
      final restaurado = Gasto.fromJson(g.toJson());
      expect(restaurado.id, g.id);
      expect(restaurado.descripcion, g.descripcion);
      expect(restaurado.importe, g.importe);
      expect(restaurado.fecha, g.fecha);
      expect(restaurado.categoria, g.categoria);
      expect(restaurado.proveedor, 'Ferretería Central');
      expect(restaurado.notas, 'Pagado en efectivo');
      expect(restaurado.trabajoId, 't1');
      expect(restaurado.estado, EstadoGasto.activo);
    });

    test('un gasto anulado conserva el motivo y la fecha de anulación', () {
      final g = _gastoBase(
        estado: EstadoGasto.anulado,
        motivoAnulacion: 'Registrado por error',
        fechaAnulacion: DateTime(2026, 3, 5),
      );
      final restaurado = Gasto.fromJson(g.toJson());
      expect(restaurado.estado, EstadoGasto.anulado);
      expect(restaurado.estaAnulado, isTrue);
      expect(restaurado.motivoAnulacion, 'Registrado por error');
      expect(restaurado.fechaAnulacion, DateTime(2026, 3, 5));
    });
  });

  group('compatibilidad con registros antiguos', () {
    test('un JSON con solo los campos imprescindibles se lee sin '
        'lanzar, con los opcionales en null y estado activo por '
        'defecto', () {
      final jsonMinimo = {
        'id': 'g1',
        'descripcion': 'Gasto mínimo',
        'importe': 10.0,
        'fecha': DateTime(2026, 1, 1).toIso8601String(),
      };
      final g = Gasto.fromJson(jsonMinimo);
      expect(g.categoria, CategoriaGasto.otros);
      expect(g.proveedor, isNull);
      expect(g.notas, isNull);
      expect(g.trabajoId, isNull);
      expect(g.estado, EstadoGasto.activo);
      expect(g.estaAnulado, isFalse);
      expect(g.motivoAnulacion, isNull);
      expect(g.fechaAnulacion, isNull);
      expect(g.esDemo, isFalse);
    });

    test('sin "creadoEl" (campo que podría faltar en un registro muy '
        'antiguo) no lanza -- usa la fecha del gasto como mejor '
        'aproximación en vez de fallar', () {
      final jsonSinCreadoEl = {
        'id': 'g1',
        'descripcion': 'Gasto antiguo',
        'importe': 20.0,
        'fecha': DateTime(2026, 2, 1).toIso8601String(),
      };
      final g = Gasto.fromJson(jsonSinCreadoEl);
      expect(g.creadoEl, DateTime(2026, 2, 1));
    });
  });

  group('copyWith', () {
    test('preserva los campos no indicados, incluido el estado de '
        'anulación', () {
      final g = _gastoBase(
        estado: EstadoGasto.anulado,
        motivoAnulacion: 'Motivo',
        fechaAnulacion: DateTime(2026, 3, 2),
      );
      final editado = g.copyWith(descripcion: 'Descripción nueva');
      expect(editado.descripcion, 'Descripción nueva');
      expect(editado.estado, EstadoGasto.anulado);
      expect(editado.motivoAnulacion, 'Motivo');
      expect(editado.importe, g.importe);
    });
  });
}
