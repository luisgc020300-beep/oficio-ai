// test/rectificativa_calculos_test.dart
//
// Auditoría de la iteración 8 (iteración 8.1): ejemplos numéricos con
// el resultado esperado derivado A MANO de las reglas ya implementadas
// (calcularTotalesFactura: base = subtotal - descuento, cuota = base *
// IVA%, total = base + cuota; calcularImporteRectificacion: resta de
// dos totales) y del art. 15 RD 1619/2012 -- nunca copiados de lo que
// devuelve el código, para poder detectar una discrepancia real.
//
// Cubre, en este orden: los 6 escenarios numéricos pedidos (puntos 1-6
// del encargo), cobros/devoluciones (7-8), numeración/integridad (9),
// y el caso de varias rectificativas sobre la misma original (10) --
// incluida la limitación real que documenta el informe: en modalidad
// "importe resultante", una segunda rectificativa debe referenciar la
// ÚLTIMA rectificativa (encadenar), no la original directamente, o el
// agregado económico no coincide con el importe final verdadero.
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/core/utils/formatters.dart';
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
  double iva = 21,
  double descuento = 0,
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
  ivaPorcentaje: iva,
  descuentoPorcentaje: descuento,
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

  group('1-6: ejemplos numéricos (valores esperados calculados a mano)', () {
    test('1. original 100€+21% rectificada a 80€+21% (importe resultante): '
        'base=80, IVA=21%, cuota=16,80, total corregido=96,80, '
        'importe de la rectificación=-24,20', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100)); // base 100, cuota 21, total 121
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      expect(original.totales.total, 121); // control del punto de partida

      await repo.add(
        _borrador(
          id: 'r',
          precio: 80,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Precio pactado inferior al facturado',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final rectificativa = repo.byId('r')!;

      expect(rectificativa.totales.baseImponible, 80);
      expect(rectificativa.ivaPorcentaje, 21);
      expect(rectificativa.totales.iva, closeTo(16.8, 0.001));
      expect(rectificativa.totales.total, closeTo(96.8, 0.001)); // total corregido
      expect(rectificativa.importeRectificacion, closeTo(-24.2, 0.001));
    });

    test('2. rectificación que AUMENTA el importe (por diferencias): '
        'una diferencia de +50 de base sobre una factura de 100 a 21% '
        'da el mismo total que recalcular 150 desde cero menos el '
        'original (60,50)', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);

      await repo.add(
        _borrador(
          id: 'r',
          precio: 50, // la diferencia, no el total
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Se facturó de menos una unidad adicional',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      final rectificativa = repo.byId('r')!;

      // Control cruzado: 150 € de base a 21% = 181,50 €; 181,50 - 121
      // (el original) = 60,50 € -- debe coincidir con el propio total
      // de la rectificativa "por diferencias".
      const totalRecalculadoDesdeCero = 150 * 1.21;
      expect(rectificativa.totales.total, closeTo(totalRecalculadoDesdeCero - 121, 0.001));
      expect(rectificativa.totales.baseImponible, 50);
      expect(rectificativa.totales.iva, closeTo(10.5, 0.001));
      expect(rectificativa.totales.total, closeTo(60.5, 0.001));
    });

    test('3. rectificación que reduce el importe a CERO (importe '
        'resultante): base=0, cuota=0, total corregido=0, importe de '
        'la rectificación = -121 (se anula económicamente el original)', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);

      await repo.add(
        _borrador(
          id: 'r',
          precio: 0,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'El servicio no llegó a prestarse',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final rectificativa = repo.byId('r')!;

      expect(rectificativa.totales.baseImponible, 0);
      expect(rectificativa.totales.iva, 0);
      expect(rectificativa.totales.total, 0);
      expect(rectificativa.importeRectificacion, -121);
    });

    test('4. rectificación con una diferencia NEGATIVA (por '
        'diferencias): base=-30, cuota=-6,30, total=-36,30 -- el signo '
        'se conserva en todos los componentes, no solo en el total', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);

      await repo.add(
        _borrador(
          id: 'r',
          precio: -30,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Devolución parcial de material',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      final rectificativa = repo.byId('r')!;

      expect(rectificativa.totales.baseImponible, -30);
      expect(rectificativa.totales.iva, closeTo(-6.3, 0.001));
      expect(rectificativa.totales.total, closeTo(-36.3, 0.001));
    });

    test('5. modalidad "por diferencias" con descuento heredado del '
        'original: aplicar el mismo % de descuento y de IVA a la '
        'diferencia da el mismo resultado que recalcular el total '
        'completo y restar -- por la linealidad de ambas fórmulas', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      // Original: 100 de base, 10% descuento, 21% IVA.
      // base = 100 - 10 = 90; cuota = 18,9; total = 108,9.
      await repo.add(_borrador(id: 'o', precio: 100, descuento: 10));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      expect(original.totales.total, closeTo(108.9, 0.001));

      // Se corrige: el precio real era 80, no 100 -- diferencia de -20,
      // con el MISMO descuento y DEL MISMO IVA heredados.
      await repo.add(
        _borrador(
          id: 'r',
          precio: -20,
          descuento: 10,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Precio unitario incorrecto',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      final rectificativa = repo.byId('r')!;

      // Control cruzado: recalcular desde cero con 80 de base, 10%
      // descuento, 21% IVA: base=72, cuota=15,12, total=87,12. Diferencia
      // frente al original (108,9): 87,12 - 108,9 = -21,78.
      const totalRecalculado = 80 * 0.9 * 1.21; // 72 * 1.21
      expect(rectificativa.totales.total, closeTo(totalRecalculado - 108.9, 0.001));
      expect(rectificativa.totales.total, closeTo(-21.78, 0.001));
    });

    test('6. modalidad "importe resultante": el total del documento es '
        'el importe YA corregido, nunca la diferencia -- son dos '
        'números distintos y ninguno debe confundirse con el otro', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);

      await repo.add(
        _borrador(
          id: 'r',
          precio: 80,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Precio pactado inferior',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final rectificativa = repo.byId('r')!;

      expect(rectificativa.totales.total, closeTo(96.8, 0.001)); // el resultante
      expect(rectificativa.importeRectificacion, closeTo(-24.2, 0.001)); // la diferencia
      expect(rectificativa.totales.total, isNot(rectificativa.importeRectificacion));
      // Ninguno de los dos es negativo-como-si-fuera-un-cobro: la
      // rectificativa nunca tiene saldo pendiente (ver más abajo).
      expect(rectificativa.saldoPendiente, 0);
    });
  });

  group('7-8: cobros y devoluciones', () {
    test('7. factura original PARCIALMENTE cobrada: emitir una '
        'rectificativa no altera ni el importe cobrado ni el saldo '
        'pendiente de la original', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100)); // total 121
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.registrarPago('o', fecha: DateTime(2026, 2), importe: 50);
      final antesDeRectificar = repo.byId('o')!;
      expect(antesDeRectificar.totalCobrado, 50);
      expect(antesDeRectificar.saldoPendiente, closeTo(71, 0.001));

      await repo.add(
        _borrador(
          id: 'r',
          precio: 80,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Corrección de precio',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      await repo.emitir('r', datosEmisor: _datosCompletos);

      final despues = repo.byId('o')!;
      expect(despues.totalCobrado, 50); // sin cambios
      expect(despues.saldoPendiente, closeTo(71, 0.001)); // sin cambios
      expect(despues.pagos, antesDeRectificar.pagos);
      // La app NO da por hecho ningún reembolso: el saldo pendiente de
      // la original sigue siendo el de SU PROPIO cobro, no se ajusta
      // automáticamente por la rectificación. Es una limitación
      // deliberada, documentada en el informe -- no una devolución que
      // la app finja haber tramitado.
    });

    test('8. factura original TOTALMENTE cobrada: sigue "pagada" tras '
        'rectificarla, y la rectificativa nunca aparece como un cobro '
        'ni como saldo pendiente', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.registrarPago('o', fecha: DateTime(2026, 2), importe: 121);
      expect(repo.byId('o')!.pagadaCompleta, isTrue);

      await repo.add(
        _borrador(
          id: 'r',
          precio: 50, // reduce muy por debajo de lo ya cobrado
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Servicio parcialmente no prestado',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final rectificativa = await repo.emitir('r', datosEmisor: _datosCompletos);

      final despues = repo.byId('o')!;
      expect(despues.pagadaCompleta, isTrue); // sin cambios
      expect(despues.totalCobrado, 121); // sin cambios

      // El importe negativo de la rectificación (50*1,21 - 121 =
      // -60,50) NO se presenta en ningún sitio como un pago: la
      // rectificativa no tiene pagos propios, ni saldo pendiente.
      expect(rectificativa.pagos, isEmpty);
      expect(rectificativa.saldoPendiente, 0);
      expect(
        () => repo.registrarPago(rectificativa.id, fecha: DateTime(2026, 3), importe: 1),
        throwsStateError,
      );
      // La diferencia real (que el negocio le debe 60,50 € al cliente)
      // solo es visible leyendo el importe de la rectificativa -- la
      // app no la registra ni la presenta como una devolución tramitada.
      expect(rectificativa.importeRectificacion, closeTo(-60.5, 0.001));
    });
  });

  group('9: factura original anulada', () {
    test('el flujo NO permite rectificar una factura anulada -- '
        'rechazada en la misma validación que una no emitida, por '
        'diseño: una anulada ya no tiene efecto fiscal que corregir', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.anular(original.id, 'Error del cliente');
      expect(repo.byId('o')!.estado, EstadoFactura.anulada);

      expect(
        () => repo.add(
          _borrador(
            id: 'r',
            tipoDocumento: TipoDocumentoFactura.rectificativa,
            serie: serieRectificativas,
            facturaOriginalId: original.id,
            motivoRectificacion: 'Intento sobre una anulada',
            modalidadRectificacion: ModalidadRectificacion.porDiferencias,
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('10: varias rectificativas sobre la misma factura original', () {
    test('dos rectificativas "por diferencias" INDEPENDIENTES (cada '
        'una corrige un error distinto) se suman correctamente sin '
        'encadenarlas -- cada una declara su propia diferencia real', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100)); // total 121
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);

      await repo.add(
        _borrador(
          id: 'r1',
          precio: -10, // error de cantidad
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Cantidad facturada por error',
        ),
      );
      final r1 = await repo.emitir('r1', datosEmisor: _datosCompletos);

      await repo.add(
        _borrador(
          id: 'r2',
          precio: -5, // error de precio, independiente del anterior
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id, // referencia la ORIGINAL, no r1 -- correcto aquí
          motivoRectificacion: 'Precio unitario erróneo, error distinto al de r1',
        ),
      );
      final r2 = await repo.emitir('r2', datosEmisor: _datosCompletos);

      expect(repo.rectificativasDe(original.id).map((f) => f.id), containsAll(['r1', 'r2']));
      // Efecto neto correcto: 121 - 12,10 - 6,05 = 102,85.
      final efectoNeto =
          repo.byId('o')!.importeFacturacion + r1.importeFacturacion + r2.importeFacturacion;
      expect(efectoNeto, closeTo(102.85, 0.001));
      // Control cruzado: recalcular con 100-10-5=85 de base desde cero.
      expect(efectoNeto, closeTo(85 * 1.21, 0.001));
    });

    test('LIMITACIÓN REAL: en modalidad "importe resultante", una '
        'segunda rectificativa que reemplaza a la primera debe '
        'referenciarla A ELLA (encadenar), no a la factura original '
        'directamente -- si no, el agregado económico no coincide con '
        'el importe final verdadero', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o', precio: 100)); // total 121
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);

      // Primera corrección: el precio real era 80 (total 96,80).
      await repo.add(
        _borrador(
          id: 'r1',
          precio: 80,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Primera corrección de precio',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final r1 = await repo.emitir('r1', datosEmisor: _datosCompletos);
      expect(r1.totales.total, closeTo(96.8, 0.001));

      // Segunda corrección, hecha BIEN: encadenada a r1 (el valor
      // definitivo real es 90, no 80).
      await repo.add(
        _borrador(
          id: 'r2-bien',
          precio: 90,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: r1.id, // <- encadenada a la ÚLTIMA rectificativa
          motivoRectificacion: 'Segunda corrección, encadenada correctamente',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final r2Bien = await repo.emitir('r2-bien', datosEmisor: _datosCompletos);
      final totalFinalReal = 90 * 1.21; // 108,90
      final efectoNetoBien =
          repo.byId('o')!.importeFacturacion + r1.importeFacturacion + r2Bien.importeFacturacion;
      expect(efectoNetoBien, closeTo(totalFinalReal, 0.001)); // CORRECTO: coincide

      // La misma segunda corrección, hecha MAL: referenciando la
      // ORIGINAL directamente en vez de a r1, aunque el valor pretenda
      // ser igualmente el definitivo (90). Mismo repositorio, ids
      // distintos -- no hace falta un almacenamiento aparte.
      await repo.add(
        _borrador(
          id: 'o2',
          precio: 100,
        ),
      );
      final original2 = await repo.emitir('o2', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r1-2',
          precio: 80,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original2.id,
          motivoRectificacion: 'Primera corrección',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final r1b = await repo.emitir('r1-2', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r2-mal',
          precio: 90,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original2.id, // <- MAL: debería ser r1b.id
          motivoRectificacion: 'Segunda corrección, sin encadenar (caso defectuoso)',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      final r2Mal = await repo.emitir('r2-mal', datosEmisor: _datosCompletos);
      final efectoNetoMal =
          repo.byId('o2')!.importeFacturacion + r1b.importeFacturacion + r2Mal.importeFacturacion;
      // INCORRECTO a propósito: no coincide con 108,90 -- demuestra la
      // limitación documentada en el informe. r2-mal se mide contra el
      // ORIGINAL (121), no contra r1b (96,80): su propia
      // importeRectificacion es 108,90 - 121 = -12,10, no los -3,30
      // que daría si estuviera bien encadenada (108,90 - 96,80). Total:
      // 121 - 24,20 - 12,10 = 84,70, no 108,90. Si esta aserción
      // empezara a fallar porque alguien "arregló" el cálculo, hay que
      // revisar el informe de la iteración 8.1 antes de tocar nada:
      // puede que el arreglo imponga una regla de negocio
      // (encadenamiento obligatorio) que nadie ha decidido todavía.
      expect(efectoNetoMal, isNot(closeTo(totalFinalReal, 0.001)));
      expect(efectoNetoMal, closeTo(84.7, 0.001));
    });

    test('registrarPago() rechaza cualquier intento sobre una '
        'rectificativa, sea cual sea su importe o modalidad', () async {
      final repo = FacturaRepository(store);
      await repo.load();
      await repo.add(_borrador(id: 'o'));
      final original = await repo.emitir('o', datosEmisor: _datosCompletos);
      await repo.add(
        _borrador(
          id: 'r',
          precio: -10,
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: original.id,
          motivoRectificacion: 'Motivo',
        ),
      );
      await repo.emitir('r', datosEmisor: _datosCompletos);
      expect(
        () => repo.registrarPago('r', fecha: DateTime(2026, 2), importe: 5),
        throwsStateError,
      );
    });

    test('un doble "emitir()" sobre la misma rectificativa (ya '
        'emitida) se rechaza, igual que en una factura ordinaria', () async {
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
        ),
      );
      await repo.emitir('r', datosEmisor: _datosCompletos);
      expect(() => repo.emitir('r', datosEmisor: _datosCompletos), throwsStateError);
    });

    test('un borrador de rectificativa no tiene numeración definitiva '
        'hasta que se emite', () async {
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
        ),
      );
      final borrador = repo.byId('r')!;
      expect(borrador.numero, isNull);
      expect(borrador.numeroSecuencial, isNull);
      expect(borrador.anio, isNull);
    });

    test('anular una rectificativa no altera su relación con la '
        'original ni la elimina de rectificativasDe()', () async {
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
        ),
      );
      await repo.emitir('r', datosEmisor: _datosCompletos);
      await repo.anular('r', 'Rectificativa emitida por error');

      final rectificativaAnulada = repo.byId('r')!;
      expect(rectificativaAnulada.estado, EstadoFactura.anulada);
      expect(rectificativaAnulada.facturaOriginalId, original.id);
      expect(repo.rectificativasDe(original.id).map((f) => f.id), ['r']);
    });
  });

  group('formato de importes negativos', () {
    test('formatCurrency() no oculta ni invierte el signo de un '
        'importe negativo', () {
      expect(formatCurrency(-24.2), contains('-'));
      expect(formatCurrency(-24.2), isNot(formatCurrency(24.2)));
    });
  });
}
