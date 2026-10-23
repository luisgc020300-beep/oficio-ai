// test/factura_repository_test.dart
//
// Reglas de negocio de FacturaRepository: numeración al emitir (sin
// huecos ni duplicados, no reutilizable tras anular), trazabilidad de
// una factura ya emitida (no se edita ni se borra por las vías
// genéricas), validación de cobros (parcial, total, rechazo de
// importes inválidos) y persistencia (encargo iteración 5, sección 12,
// puntos 4, 6, 7, 9, 10, 11 y 18).
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/repositories/factura_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// emitir() exige datos del emisor completos (encargo iteración 6,
// sección 6) -- este fixture se reutiliza en todos los tests de este
// archivo, que no son sobre esa validación en sí (esa vive en
// factura_negocio_integration_test.dart) sino sobre numeración/pagos.
const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

Factura _borrador({
  String id = 'f1',
  String clienteId = 'c1',
  String? trabajoId,
  String? presupuestoId,
  double precio = 100,
}) => Factura(
  id: id,
  clienteId: clienteId,
  trabajoId: trabajoId,
  presupuestoId: presupuestoId,
  titulo: 'Factura $id',
  conceptos: [
    ConceptoPresupuesto(
      id: 'c1',
      descripcion: 'Servicio',
      cantidad: 1,
      precioUnitario: precio,
    ),
  ],
  creadaEl: DateTime(2026, 1, 1),
);

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  group('add()', () {
    test('guarda un borrador', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador());
      expect(repo.facturas, hasLength(1));
      expect(repo.byId('f1')!.estado, EstadoFactura.borrador);
    });

    test('rechaza crear directamente una factura que no sea borrador', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      expect(
        () => repo.add(_borrador().copyWith(estado: EstadoFactura.emitida)),
        throwsStateError,
      );
    });
  });

  group('emitir() -- numeración', () {
    test('asigna año y el primer correlativo del año', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador());
      final emitida = await repo.emitir('f1', datosEmisor: _datosCompletos);
      expect(emitida.estado, EstadoFactura.emitida);
      expect(emitida.numeroSecuencial, 1);
      expect(emitida.numero, '${DateTime.now().year}-0001');
      expect(emitida.fechaEmision, isNotNull);
    });

    test('el correlativo avanza sin huecos ni duplicados entre varias '
        'facturas emitidas', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'f1'));
      await repo.add(_borrador(id: 'f2'));
      await repo.add(_borrador(id: 'f3'));

      final e1 = await repo.emitir('f1', datosEmisor: _datosCompletos);
      final e2 = await repo.emitir('f2', datosEmisor: _datosCompletos);
      final e3 = await repo.emitir('f3', datosEmisor: _datosCompletos);

      expect([e1.numeroSecuencial, e2.numeroSecuencial, e3.numeroSecuencial], [1, 2, 3]);
    });

    test('descartar un borrador nunca numerado no deja un hueco en la '
        'numeración de las facturas que sí se emiten', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'f1'));
      await repo.add(_borrador(id: 'f2'));
      await repo.delete('f2'); // nunca llegó a emitirse, nunca tuvo número
      await repo.add(_borrador(id: 'f3'));

      final e1 = await repo.emitir('f1', datosEmisor: _datosCompletos);
      final e3 = await repo.emitir('f3', datosEmisor: _datosCompletos);
      expect(e1.numeroSecuencial, 1);
      expect(e3.numeroSecuencial, 2); // no 3: f2 nunca contó
    });

    test('no se puede emitir una factura ya emitida, ni una sin conceptos', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'f1'));
      await repo.emitir('f1', datosEmisor: _datosCompletos);
      expect(() => repo.emitir('f1', datosEmisor: _datosCompletos), throwsStateError);

      await repo.add(
        Factura(
          id: 'vacia',
          clienteId: 'c1',
          titulo: 'Sin conceptos',
          conceptos: const [],
          creadaEl: DateTime(2026),
        ),
      );
      expect(() => repo.emitir('vacia', datosEmisor: _datosCompletos), throwsStateError);
    });
  });

  group('update()/delete() -- trazabilidad de una factura emitida', () {
    test('update() permite editar un borrador', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador());
      await repo.update(repo.byId('f1')!.copyWith(titulo: 'Editada'));
      expect(repo.byId('f1')!.titulo, 'Editada');
    });

    test('update() rechaza cambiar una factura ya emitida', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador());
      await repo.emitir('f1', datosEmisor: _datosCompletos);
      expect(
        () => repo.update(repo.byId('f1')!.copyWith(titulo: 'Intento de editar')),
        throwsStateError,
      );
      // Y el título original sigue intacto -- no se aplicó a medias.
      expect(repo.byId('f1')!.titulo, 'Factura f1');
    });

    test('delete() borra un borrador pero rechaza borrar una factura '
        'emitida -- se conserva siempre, como mucho se anula', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'f1'));
      await repo.add(_borrador(id: 'f2'));
      await repo.delete('f1');
      expect(repo.byId('f1'), isNull);

      await repo.emitir('f2', datosEmisor: _datosCompletos);
      expect(() => repo.delete('f2'), throwsStateError);
      expect(repo.byId('f2'), isNotNull);
    });
  });

  group('anular()', () {
    test('pasa a anulada, exige motivo y conserva el número -- nunca se '
        'reutiliza en la siguiente factura emitida', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'f1'));
      await repo.add(_borrador(id: 'f2'));
      await repo.emitir('f1', datosEmisor: _datosCompletos);
      final anulada = await repo.anular('f1', 'Error en el importe');

      expect(anulada.estado, EstadoFactura.anulada);
      expect(anulada.motivoAnulacion, 'Error en el importe');
      expect(anulada.numero, '${DateTime.now().year}-0001');

      final siguiente = await repo.emitir('f2', datosEmisor: _datosCompletos);
      expect(siguiente.numeroSecuencial, 2); // nunca reutiliza el 1
    });

    test('rechaza anular sin motivo y rechaza anular un borrador', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'f1'));
      await repo.emitir('f1', datosEmisor: _datosCompletos);
      expect(() => repo.anular('f1', ''), throwsArgumentError);

      await repo.add(_borrador(id: 'f2'));
      expect(() => repo.anular('f2', 'motivo'), throwsStateError);
    });
  });

  group('registrarPago()', () {
    test('un pago parcial reduce el saldo sin saldarla', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador()); // total 121 con IVA 21%
      await repo.emitir('f1', datosEmisor: _datosCompletos);
      final f = await repo.registrarPago(
        'f1',
        fecha: DateTime(2026, 2),
        importe: 50,
      );
      expect(f.saldoPendiente, 71);
      expect(f.pagadaCompleta, isFalse);
    });

    test('el pago final deja el saldo exactamente en cero', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador());
      await repo.emitir('f1', datosEmisor: _datosCompletos);
      await repo.registrarPago('f1', fecha: DateTime(2026, 2, 1), importe: 50);
      final f = await repo.registrarPago(
        'f1',
        fecha: DateTime(2026, 2, 5),
        importe: 71,
      );
      expect(f.saldoPendiente, 0);
      expect(f.pagadaCompleta, isTrue);
      expect(f.pagos, hasLength(2));
    });

    test('rechaza importe cero, negativo o mayor que el saldo pendiente', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador());
      await repo.emitir('f1', datosEmisor: _datosCompletos);

      expect(
        () => repo.registrarPago('f1', fecha: DateTime(2026), importe: 0),
        throwsArgumentError,
      );
      expect(
        () => repo.registrarPago('f1', fecha: DateTime(2026), importe: -10),
        throwsArgumentError,
      );
      expect(
        () => repo.registrarPago('f1', fecha: DateTime(2026), importe: 999),
        throwsArgumentError,
      );
      // Ninguno de los rechazados dejó rastro en el historial.
      expect(repo.byId('f1')!.pagos, isEmpty);
    });

    test('solo se pueden registrar cobros sobre una factura emitida, no '
        'sobre un borrador ni sobre una anulada', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'f1'));
      expect(
        () => repo.registrarPago('f1', fecha: DateTime(2026), importe: 10),
        throwsStateError,
      );

      await repo.add(_borrador(id: 'f2'));
      await repo.emitir('f2', datosEmisor: _datosCompletos);
      await repo.anular('f2', 'motivo');
      expect(
        () => repo.registrarPago('f2', fecha: DateTime(2026), importe: 10),
        throwsStateError,
      );
    });

    test('dos llamadas a registrarPago nunca se pisan entre sí: dos '
        'pagos "a la vez" (secuenciales, como dos reintentos) se anexan '
        'los dos sin perder ninguno', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(precio: 50)); // total 60.5
      await repo.emitir('f1', datosEmisor: _datosCompletos);
      await Future.wait([
        repo.registrarPago('f1', fecha: DateTime(2026, 2, 1), importe: 20),
        repo.registrarPago('f1', fecha: DateTime(2026, 2, 1), importe: 20),
      ]);
      expect(repo.byId('f1')!.pagos, hasLength(2));
      expect(repo.byId('f1')!.totalCobrado, 40);
    });
  });

  group('relaciones', () {
    test('porCliente/porTrabajo/porPresupuesto filtran correctamente', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(
        _borrador(id: 'f1', clienteId: 'c1', trabajoId: 't1', presupuestoId: 'p1'),
      );
      await repo.add(_borrador(id: 'f2', clienteId: 'c2'));

      expect(repo.porCliente('c1').map((f) => f.id), ['f1']);
      expect(repo.porTrabajo('t1').map((f) => f.id), ['f1']);
      expect(repo.porPresupuesto('p1').map((f) => f.id), ['f1']);
      expect(repo.porCliente('c2').map((f) => f.id), ['f2']);
    });
  });

  group('persistencia', () {
    test('facturas, su número y sus pagos sobreviven a un repositorio '
        'nuevo sobre el mismo almacenamiento', () async {
      final repo1 = FacturaRepository(store);
      await repo1.load();
      await repo1.add(_borrador());
      await repo1.emitir('f1', datosEmisor: _datosCompletos);
      await repo1.registrarPago('f1', fecha: DateTime(2026, 2), importe: 30);

      final repo2 = FacturaRepository(store);
      await repo2.load();

      final f = repo2.byId('f1')!;
      expect(f.estado, EstadoFactura.emitida);
      expect(f.numeroSecuencial, 1);
      expect(f.pagos, hasLength(1));
      expect(f.pagos.first.importe, 30);
    });
  });

  group('seedIfEmpty()', () {
    test('no sobrescribe facturas ya existentes', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'real'));

      await repo.seedIfEmpty([_borrador(id: 'demo')]);

      expect(repo.facturas, hasLength(1));
      expect(repo.facturas.first.id, 'real');
    });
  });
}
