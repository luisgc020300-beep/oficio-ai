// test/rectificativa_ambiguedad_test.dart
//
// Iteración 8.2: la auditoría 8.1 documentó que varias rectificativas
// "importe resultante" contra el mismo documento, sin encadenar a la
// última vigente, descuadran el agregado económico. Este archivo
// prueba la validación que ahora lo impide en el propio repositorio
// (FacturaRepository.add()), no solo en la pantalla -- y los casos
// que esa validación debe seguir permitiendo: una rectificativa
// anulada libera el hueco, y la modalidad "por diferencias" nunca se
// ve afectada.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/repositories/factura_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  double precio = 100,
  TipoDocumentoFactura tipoDocumento = TipoDocumentoFactura.ordinaria,
  String serie = '',
  String? facturaOriginalId,
  String? motivoRectificacion,
  ModalidadRectificacion? modalidadRectificacion,
}) => Factura(
  id: id,
  clienteId: 'c1',
  titulo: 'Factura $id',
  conceptos: [
    ConceptoPresupuesto(id: 'c1', descripcion: 'Servicio', cantidad: 1, precioUnitario: precio),
  ],
  creadaEl: DateTime(2026, 1, 1),
  tipoDocumento: tipoDocumento,
  serie: serie,
  facturaOriginalId: facturaOriginalId,
  motivoRectificacion: motivoRectificacion,
  modalidadRectificacion: modalidadRectificacion,
);

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  group('rectificativaResultanteVigenteDe()', () {
    test('null cuando no hay ninguna rectificativa "importe resultante" '
        'sobre el documento', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      expect(repo.rectificativaResultanteVigenteDe(original.id), isNull);
    });

    test('devuelve la rectificativa cuando existe una vigente (emitida)', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r',
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Motivo',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final r = await repo.emitir('r', datosEmisor: _datosCompletos);
      expect(repo.rectificativaResultanteVigenteDe(original.id)?.id, r.id);
    });

    test('también cuenta un borrador sin emitir todavía -- ya reserva '
        'la posición', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r',
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Motivo',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      expect(repo.rectificativaResultanteVigenteDe(original.id)?.id, 'r');
    });

    test('una rectificativa ANULADA no cuenta como vigente -- libera el '
        'hueco para una corrección nueva', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r1',
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Motivo equivocado',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      await repo.emitir('r1', datosEmisor: _datosCompletos);
      await repo.anular('r1', 'Se emitió con datos erróneos');
      expect(repo.rectificativaResultanteVigenteDe(original.id), isNull);
    });
  });

  group('FacturaRepository.add() rechaza la ambigüedad (iteración 8.2)', () {
    test('rechaza una segunda "importe resultante" contra un documento '
        'que ya tiene una vigente', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r1',
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Primera',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      await repo.emitir('r1', datosEmisor: _datosCompletos);

      expect(
        () => repo.add(
          _borrador(
            id: 'r2',
            tipoDocumento: TipoDocumentoFactura.rectificativa,
            serie: serieRectificativas,
            facturaOriginalId: original.id, // debería ser r1
            motivoRectificacion: 'Segunda, mal dirigida',
            modalidadRectificacion: ModalidadRectificacion.importeResultante,
          ),
        ),
        throwsStateError,
      );
      // No queda ningún borrador huérfano del intento rechazado.
      expect(repo.byId('r2'), isNull);
    });

    test('rechaza incluso si la primera rectificativa sigue como '
        'BORRADOR sin emitir -- ya reserva el hueco', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r1',
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Primera, todavía sin emitir',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      // r1 sigue en borrador -- no se emite.

      expect(
        () => repo.add(
          _borrador(
            id: 'r2',
            tipoDocumento: TipoDocumentoFactura.rectificativa,
            serie: serieRectificativas,
            facturaOriginalId: original.id,
            motivoRectificacion: 'Segunda, duplicada mientras r1 sigue en borrador',
            modalidadRectificacion: ModalidadRectificacion.importeResultante,
          ),
        ),
        throwsStateError,
      );
    });

    test('tras ANULAR la primera, sí se permite crear una segunda '
        '"importe resultante" contra el mismo documento', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r1',
          precio: 80,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Primera, emitida por error',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      await repo.emitir('r1', datosEmisor: _datosCompletos);
      await repo.anular('r1', 'Importe equivocado');

      // Ahora sí se puede -- r1 ya no cuenta como vigente.
      await repo.add(
        _borrador(
          id: 'r2',
          precio: 90,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Segunda, la correcta',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final r2 = await repo.emitir('r2', datosEmisor: _datosCompletos);
      // Correcta: se mide contra la ORIGINAL (121), porque la primera
      // corrección quedó anulada y ya no es la base vigente.
      // 90*1.21=108,90; 108,90-121=-12,10.
      expect(r2.importeRectificacion, closeTo(-12.1, 0.001));
      expect(repo.rectificativaResultanteVigenteDe(original.id)?.id, 'r2');
    });

    test('la modalidad "por diferencias" nunca se bloquea por esta '
        'regla -- se pueden crear varias independientes sin '
        'encadenar', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r1',
          precio: -10,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Primera diferencia',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      await repo.emitir('r1', datosEmisor: _datosCompletos);

      // No lanza -- "por diferencias" contra el mismo documento,
      // aunque ya exista otra "por diferencias" previa.
      await repo.add(
        _borrador(
          id: 'r2',
          precio: -5,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Segunda diferencia, independiente',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      expect(repo.byId('r2'), isNotNull);
    });

    test('no se puede mezclar: si ya hay una "por diferencias" vigente, '
        'una "importe resultante" contra el MISMO documento sigue '
        'permitida -- solo se bloquean dos "importe resultante" entre '
        'sí, no las dos modalidades combinadas', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r1',
          precio: -10,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Diferencia independiente',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      await repo.emitir('r1', datosEmisor: _datosCompletos);

      await repo.add(
        _borrador(
          id: 'r2',
          precio: 80,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Corrección resultante, no choca con r1',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      expect(repo.byId('r2'), isNotNull);
    });
  });

  group('autorreferencia y ciclos (iteración 8.2)', () {
    test('rechaza una rectificativa que se referencia a sí misma', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      expect(original.id, isNotEmpty);

      expect(
        () => repo.add(
          _borrador(
            id: 'r-self',
            tipoDocumento: TipoDocumentoFactura.rectificativa,
            serie: serieRectificativas,
            facturaOriginalId: 'r-self', // se referencia a sí misma
            motivoRectificacion: 'Motivo',
          ),
        ),
        throwsStateError,
      );
    });

    test('rechaza crear una rectificativa contra una relación ya '
        'circular en los datos (defensivo, no debería poder ocurrir '
        'por esta misma API, pero no debe colgarse ni guardarse si '
        'los datos ya vinieran corruptos)', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      // Se siembra directamente un ciclo A -> B -> A, algo que add()
      // nunca permitiría crear por este camino pero que unos datos
      // antiguos corruptos podrían traer.
      await repo.seedIfEmpty([
        Factura(
          id: 'A',
          clienteId: 'c1',
          titulo: 'A',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
          ],
          estado: EstadoFactura.emitida,
          anio: 2026,
          numeroSecuencial: 1,
          creadaEl: DateTime(2026, 1, 1),
          fechaEmision: DateTime(2026, 1, 1),
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: 'B',
          motivoRectificacion: 'x',
        ),
        Factura(
          id: 'B',
          clienteId: 'c1',
          titulo: 'B',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'x', cantidad: 1, precioUnitario: 10),
          ],
          estado: EstadoFactura.emitida,
          anio: 2026,
          numeroSecuencial: 2,
          serie: serieRectificativas,
          creadaEl: DateTime(2026, 1, 1),
          fechaEmision: DateTime(2026, 1, 1),
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          facturaOriginalId: 'A',
          motivoRectificacion: 'x',
        ),
      ]);

      expect(
        () => repo.add(
          _borrador(
            id: 'C',
            tipoDocumento: TipoDocumentoFactura.rectificativa,
            serie: serieRectificativas,
            facturaOriginalId: 'A',
            motivoRectificacion: 'Intenta colgarse de un ciclo ya corrupto',
          ),
        ),
        throwsStateError,
      );
    });
  });
}
