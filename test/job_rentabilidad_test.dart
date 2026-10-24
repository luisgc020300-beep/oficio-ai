// test/job_rentabilidad_test.dart
//
// Rentabilidad por trabajo (iteración 9, sección 4): facturado,
// cobrado, gastos y margen estimado, con varias facturas por trabajo,
// una factura parcialmente cobrada, una anulada, una rectificativa
// "por diferencias" y otra "importe resultante", y gastos atribuidos o
// no al trabajo -- todos los valores esperados se calculan aquí a
// mano, nunca copiados de job_detail_screen.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/core/utils/formatters.dart';
import 'package:oficio_ai/data/app_data.dart';
import 'package:oficio_ai/data/local/local_store.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/gasto.dart';
import 'package:oficio_ai/data/models/trabajo.dart';
import 'package:oficio_ai/features/jobs/job_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _datosCompletos = DatosNegocio(
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

Factura _facturaOrdinaria({
  required String id,
  required String trabajoId,
  required double precio,
}) => Factura(
  id: id,
  clienteId: 'c1',
  trabajoId: trabajoId,
  titulo: 'Factura $id',
  conceptos: [
    ConceptoPresupuesto(id: 'c1', descripcion: 'Servicio', cantidad: 1, precioUnitario: precio),
  ],
  creadaEl: DateTime(2026, 1, 1),
);

Future<void> _scrollHastaRentabilidad(WidgetTester tester) => tester.scrollUntilVisible(
  find.text('Margen estimado'),
  300,
  scrollable: find.byType(Scrollable).first,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  testWidgets(
    'rentabilidad de un trabajo con varias facturas (una parcialmente '
    'cobrada, otra totalmente, una anulada), una rectificativa "por '
    'diferencias" y otra "importe resultante", y gastos propios y de '
    'otro trabajo',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final appData = AppData(store);
      await Future.wait([
        appData.clientes.load(),
        appData.trabajos.load(),
        appData.presupuestos.load(),
        appData.citas.load(),
        appData.facturas.load(),
        appData.gastos.load(),
        appData.negocio.load(),
      ]);
      await appData.negocio.guardar(_datosCompletos);
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Reforma de baño',
          estado: EstadoTrabajo.finalizado,
          creadoEl: DateTime(2026, 1, 1),
        ),
      );
      await appData.trabajos.add(
        Trabajo(
          id: 't2',
          clienteId: 'c1',
          titulo: 'Otro trabajo, no debe mezclarse',
          estado: EstadoTrabajo.finalizado,
          creadoEl: DateTime(2026, 1, 1),
        ),
      );

      // f1: 200 + 21% = 242, cobrada parcialmente (100).
      await appData.facturas.add(_facturaOrdinaria(id: 'f1', trabajoId: 't1', precio: 200));
      final f1 = await appData.facturas.emitir('f1', datosEmisor: _datosCompletos);
      await appData.facturas.registrarPago('f1', fecha: DateTime(2026, 2, 1), importe: 100);

      // f2: 100 + 21% = 121, cobrada en su totalidad.
      await appData.facturas.add(_facturaOrdinaria(id: 'f2', trabajoId: 't1', precio: 100));
      final f2 = await appData.facturas.emitir('f2', datosEmisor: _datosCompletos);
      await appData.facturas.registrarPago('f2', fecha: DateTime(2026, 2, 2), importe: 121);

      // f3: 50 + 21% = 60,50, pero ANULADA -- no debe contar en nada.
      await appData.facturas.add(_facturaOrdinaria(id: 'f3', trabajoId: 't1', precio: 50));
      await appData.facturas.emitir('f3', datosEmisor: _datosCompletos);
      await appData.facturas.anular('f3', 'Presupuesto duplicado por error');

      // r1: rectificativa "por diferencias" de f1, -20 de base ->
      // -20*1,21 = -24,20. Hereda trabajoId de f1 (t1).
      await appData.facturas.add(
        Factura(
          id: 'r1',
          clienteId: 'c1',
          trabajoId: f1.trabajoId,
          titulo: 'Rectificativa de f1',
          conceptos: const [
            ConceptoPresupuesto(id: 'c1', descripcion: 'Corrección', cantidad: 1, precioUnitario: -20),
          ],
          creadaEl: DateTime(2026, 2, 5),
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: f1.id,
          motivoRectificacion: 'Cantidad facturada por error',
          modalidadRectificacion: ModalidadRectificacion.porDiferencias,
        ),
      );
      await appData.facturas.emitir('r1', datosEmisor: _datosCompletos);

      // r2: rectificativa "importe resultante" de f2, el importe real
      // era 90 de base (90*1,21=108,90); importeRectificacion =
      // 108,90 - 121 = -12,10. Hereda trabajoId de f2 (t1).
      await appData.facturas.add(
        Factura(
          id: 'r2',
          clienteId: 'c1',
          trabajoId: f2.trabajoId,
          titulo: 'Rectificativa de f2',
          conceptos: const [
            ConceptoPresupuesto(
              id: 'c1',
              descripcion: 'Servicio (importe corregido)',
              cantidad: 1,
              precioUnitario: 90,
            ),
          ],
          creadaEl: DateTime(2026, 2, 6),
          tipoDocumento: TipoDocumentoFactura.rectificativa,
          serie: serieRectificativas,
          facturaOriginalId: f2.id,
          motivoRectificacion: 'Precio pactado inferior al facturado',
          modalidadRectificacion: ModalidadRectificacion.importeResultante,
        ),
      );
      await appData.facturas.emitir('r2', datosEmisor: _datosCompletos);

      // Factura de OTRO trabajo -- control de que no se mezcla.
      await appData.facturas.add(_facturaOrdinaria(id: 'f_otro', trabajoId: 't2', precio: 500));
      await appData.facturas.emitir('f_otro', datosEmisor: _datosCompletos);

      // Gastos: uno activo de t1, uno anulado de t1 (no debe contar),
      // uno de t2 (no debe mezclarse) y uno sin trabajo (no debe
      // asignarse a t1).
      await appData.gastos.add(
        Gasto(
          id: 'g1',
          descripcion: 'Material de fontanería',
          importe: 30,
          fecha: DateTime(2026, 2, 1),
          trabajoId: 't1',
          creadoEl: DateTime(2026, 2, 1),
        ),
      );
      await appData.gastos.add(
        Gasto(
          id: 'g2',
          descripcion: 'Gasto registrado por error',
          importe: 999,
          fecha: DateTime(2026, 2, 1),
          trabajoId: 't1',
          creadoEl: DateTime(2026, 2, 1),
        ),
      );
      await appData.gastos.anular('g2', 'Duplicado por error');
      await appData.gastos.add(
        Gasto(
          id: 'g_otro_trabajo',
          descripcion: 'Gasto de otro trabajo',
          importe: 777,
          fecha: DateTime(2026, 2, 1),
          trabajoId: 't2',
          creadoEl: DateTime(2026, 2, 1),
        ),
      );
      await appData.gastos.add(
        Gasto(
          id: 'g_sin_trabajo',
          descripcion: 'Gasto general del negocio',
          importe: 15,
          fecha: DateTime(2026, 2, 1),
          creadoEl: DateTime(2026, 2, 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: JobDetailScreen(appData: appData, trabajoId: 't1')),
      );
      await tester.pumpAndSettle();
      await _scrollHastaRentabilidad(tester);

      // Cálculo independiente, no tomado del código de producción:
      // Facturado = 242 (f1) + 121 (f2) + (-24,20) (r1) + (-12,10) (r2)
      //           = 326,70
      // Cobrado   = 100 (f1) + 121 (f2) = 221,00 (r1/r2 nunca cobran)
      // Pendiente = (242-100) (f1) + (121-121) (f2) + 0 (r1) + 0 (r2)
      //           = 142,00
      // Gastos    = 30,00 (solo g1 -- g2 anulado, g_otro_trabajo es de
      //             t2, g_sin_trabajo no tiene trabajo asociado)
      // Margen    = 326,70 - 30,00 = 296,70
      expect(find.text(formatCurrency(326.7)), findsWidgets); // Facturado
      expect(find.text(formatCurrency(221.0)), findsWidgets); // Cobrado
      expect(find.text(formatCurrency(142.0)), findsWidgets); // Pendiente de cobro
      expect(find.text(formatCurrency(-30.0)), findsWidgets); // Gastos (mostrado en negativo)
      expect(find.text(formatCurrency(296.7)), findsWidgets); // Margen estimado

      // Controles negativos: ninguno de los importes de t2 ni del
      // gasto sin trabajo debe aparecer en esta pantalla.
      expect(find.text(formatCurrency(777.0)), findsNothing);
      expect(find.text(formatCurrency(605.0)), findsNothing); // 500*1.21 de f_otro
      expect(find.text('Gasto de otro trabajo'), findsNothing);
      expect(find.text('Gasto general del negocio'), findsNothing);
      // El gasto anulado se ve en la lista (no se esconde el rastro)
      // pero tachado -- comprobado aparte en el test de la lista de
      // gastos de la pantalla. Está más abajo que la tarjeta de
      // rentabilidad, hace falta seguir desplazándose para que el
      // ListView llegue a construirlo.
      await tester.scrollUntilVisible(
        find.text('Gasto registrado por error'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Gasto registrado por error'), findsOneWidget);
    },
  );

  testWidgets(
    'un trabajo sin facturas ni gastos no muestra la sección de '
    'rentabilidad -- no inventa un margen de cero',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final appData = AppData(store);
      await Future.wait([
        appData.clientes.load(),
        appData.trabajos.load(),
        appData.presupuestos.load(),
        appData.citas.load(),
        appData.facturas.load(),
        appData.gastos.load(),
      ]);
      await appData.clientes.add(Cliente(id: 'c1', nombre: 'Ana Pérez', creadoEl: DateTime(2026)));
      await appData.trabajos.add(
        Trabajo(
          id: 't1',
          clienteId: 'c1',
          titulo: 'Trabajo sin facturar aún',
          estado: EstadoTrabajo.pendiente,
          creadoEl: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: JobDetailScreen(appData: appData, trabajoId: 't1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rentabilidad'), findsNothing);
      expect(find.text('Margen estimado'), findsNothing);
    },
  );
}
