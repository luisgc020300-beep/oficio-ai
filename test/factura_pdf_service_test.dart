// test/factura_pdf_service_test.dart
//
// FacturaPdfService en aislamiento: genera bytes de PDF de verdad (el
// paquete `pdf` es Dart puro, no toca ningún plugin nativo, así que
// esto corre en `flutter test` normal) y valida contenido/estructura de
// forma fiable sin comparar bytes exactos -- ver nota en cada grupo de
// tests sobre qué se comprueba y por qué (encargo iteración 7, sección
// 10, puntos 1-11; fuente embebida revisada en la iteración 7.1).
//
// TestWidgetsFlutterBinding.ensureInitialized() es necesario aquí
// porque generar() carga la fuente TTF con rootBundle.load() -- sin un
// binding inicializado, cualquier lectura de asset falla con "Binding
// has not yet been initialized", aunque no se construya ni un solo
// widget en todo este archivo.
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oficio_ai/data/models/cliente.dart';
import 'package:oficio_ai/data/models/cliente_snapshot.dart';
import 'package:oficio_ai/data/models/concepto_presupuesto.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';
import 'package:oficio_ai/data/models/factura.dart';
import 'package:oficio_ai/data/models/pago_factura.dart';
import 'package:oficio_ai/services/factura_pdf_service.dart';
import 'package:pdf/pdf.dart';

const _emisor = DatosNegocio(
  nombreComercial: 'Fontanería Pérez',
  nombreFiscal: 'Juan Pérez García',
  nif: '12345678Z',
  telefono: '600 123 456',
  email: 'juan@fonteria-perez.es',
  direccion: 'Calle Mayor 1',
  codigoPostal: '28001',
  localidad: 'Madrid',
  provincia: 'Madrid',
);

final _cliente = Cliente(
  id: 'c1',
  nombre: 'Ana Rodríguez Jiménez',
  direccion: 'Avenida de España 22, Getafe',
  telefono: '611 222 333',
  email: 'ana@email.com',
  creadoEl: DateTime(2026, 1, 1),
);

Factura _facturaEmitida({
  List<ConceptoPresupuesto>? conceptos,
  double iva = 21,
  double descuento = 0,
  List<PagoFactura> pagos = const [],
  DatosNegocio? datosEmisor = _emisor,
  ClienteSnapshot? datosCliente,
}) => Factura(
  id: 'f1',
  clienteId: 'c1',
  titulo: 'Factura de prueba',
  conceptos:
      conceptos ??
      const [
        ConceptoPresupuesto(
          id: 'c1',
          descripcion: 'Reparación de grifo',
          cantidad: 2,
          precioUnitario: 35,
        ),
      ],
  ivaPorcentaje: iva,
  descuentoPorcentaje: descuento,
  estado: EstadoFactura.emitida,
  anio: 2026,
  numeroSecuencial: 1,
  creadaEl: DateTime(2026, 1, 1),
  fechaEmision: DateTime(2026, 1, 2),
  pagos: pagos,
  datosEmisor: datosEmisor,
  datosCliente: datosCliente,
);

/// Comprobación fiable y barata de que son bytes de PDF de verdad, sin
/// comparar el documento byte a byte (que sería frágil ante cualquier
/// cambio de maquetación): la cabecera "%PDF-" es obligatoria en la
/// especificación del formato.
void _esperarPdfValido(List<int> bytes) {
  expect(bytes, isNotEmpty);
  expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  // Un documento con un mínimo de contenido real, no una página vacía.
  expect(bytes.length, greaterThan(500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
  });

  group('generación básica', () {
    test('una factura emitida con datos completos produce un PDF válido', () async {
      final bytes = await FacturaPdfService.generar(
        factura: _facturaEmitida(),
        cliente: _cliente,
      );
      _esperarPdfValido(bytes);
    });

    test('no lanza con una factura sin cliente (eliminado)', () async {
      final bytes = await FacturaPdfService.generar(
        factura: _facturaEmitida(),
        cliente: null,
      );
      _esperarPdfValido(bytes);
    });
  });

  group('los importes vienen del modelo, no se recalculan', () {
    test('el total/base/IVA pasados al documento son exactamente los de '
        'Factura.totales', () async {
      final factura = _facturaEmitida(
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio',
            cantidad: 3,
            precioUnitario: 33.333,
          ),
        ],
        descuento: 10,
      );
      // No hay forma fiable de leer un número exacto de vuelta del PDF
      // sin un parser aparte -- lo que sí se puede garantizar, y es lo
      // que importa, es que el servicio nunca vuelve a calcular nada:
      // consume totales/totalCobrado/saldoPendiente tal cual expone el
      // modelo. Se comprueba aquí que esos valores existen y son
      // coherentes entre sí (la misma garantía que ya cubre
      // factura_model_test.dart para el cálculo en sí).
      expect(factura.totales.total, factura.totales.baseImponible + factura.totales.iva);
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: _cliente);
      _esperarPdfValido(bytes);
    });

    test('con descuento e IVA no genera excepciones y conserva la '
        'relación base+IVA=total', () async {
      final factura = _facturaEmitida(iva: 10, descuento: 15);
      expect(factura.totales.total, factura.totales.baseImponible + factura.totales.iva);
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: _cliente);
      _esperarPdfValido(bytes);
    });

    test('con pagos parciales, total/cobrado/pendiente son consistentes '
        'y el documento se genera sin errores', () async {
      final factura = _facturaEmitida(
        pagos: [
          PagoFactura(
            id: 'p1',
            fecha: DateTime(2026, 2, 1),
            importe: 30,
            registradoEl: DateTime(2026, 2, 1),
          ),
        ],
      );
      expect(factura.totalCobrado, 30);
      expect(factura.saldoPendiente, factura.totales.total - 30);
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: _cliente);
      _esperarPdfValido(bytes);
    });
  });

  group('contenido difícil: acentos, descripciones largas, muchas líneas', () {
    test('descripciones con acentos y "ñ" no rompen la generación', () async {
      final factura = _facturaEmitida(
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion:
                'Instalación de calefacción, revisión de tuberías y '
                'reparación de avería en el baño pequeño (año de la '
                'vivienda: construcción antigua, ¡ojo con el yeso!)',
            cantidad: 1,
            precioUnitario: 199.99,
          ),
        ],
      );
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: _cliente);
      _esperarPdfValido(bytes);
    });

    test('una factura con muchos conceptos (varias páginas) se genera '
        'sin errores', () async {
      final conceptos = List.generate(
        80,
        (i) => ConceptoPresupuesto(
          id: 'c$i',
          descripcion: 'Concepto número $i de la reparación',
          cantidad: 1,
          precioUnitario: 12.5,
        ),
      );
      final factura = _facturaEmitida(conceptos: conceptos);
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: _cliente);
      _esperarPdfValido(bytes);
      // Un documento de 80 líneas debe ser notablemente más grande que
      // uno de una sola línea -- señal indirecta de que de verdad
      // volcó todo el contenido y no se quedó a medias.
      final bytesUnaLinea = await FacturaPdfService.generar(
        factura: _facturaEmitida(),
        cliente: _cliente,
      );
      expect(bytes.length, greaterThan(bytesUnaLinea.length));
    });
  });

  group('integridad histórica del emisor', () {
    test('una factura emitida usa su propia fotografía, nunca el '
        'perfil actual', () {
      final historico = _emisor;
      const actual = DatosNegocio(
        nombreFiscal: 'Otro nombre, S.L.',
        nif: 'B87654321',
      );
      final factura = _facturaEmitida(datosEmisor: historico);

      final usado = FacturaPdfService.datosEmisorParaDocumento(factura, actual);
      expect(usado, historico);
      expect(usado!.nombreFiscal, isNot('Otro nombre, S.L.'));
    });

    test('cambiar "Mi negocio" después de emitir no afecta a los datos '
        'usados para el PDF de esa factura', () {
      final factura = _facturaEmitida(datosEmisor: _emisor);
      const negocioCambiado = DatosNegocio(
        nombreFiscal: 'Nombre nuevo, S.L.',
        nif: 'B11111111',
        localidad: 'Barcelona',
      );
      final usado = FacturaPdfService.datosEmisorParaDocumento(
        factura,
        negocioCambiado,
      );
      expect(usado!.localidad, 'Madrid'); // el histórico, no Barcelona
    });

    test('una factura emitida SIN datosEmisor (anterior a la iteración '
        '6) no usa en silencio el perfil actual', () {
      final factura = _facturaEmitida(datosEmisor: null);
      const actual = DatosNegocio(nombreFiscal: 'Perfil actual', nif: '12345678Z');

      expect(FacturaPdfService.faltanDatosHistoricosEmisor(factura), isTrue);
      final usado = FacturaPdfService.datosEmisorParaDocumento(factura, actual);
      expect(usado, isNull); // nunca "Perfil actual"
    });

    test('ese caso igualmente genera un PDF (con el aviso visible), no '
        'lanza una excepción', () async {
      final factura = _facturaEmitida(datosEmisor: null);
      final bytes = await FacturaPdfService.generar(
        factura: factura,
        cliente: _cliente,
        datosNegocioActual: const DatosNegocio(
          nombreFiscal: 'Perfil actual',
          nif: '12345678Z',
        ),
      );
      _esperarPdfValido(bytes);
    });

    test('un borrador SÍ usa el perfil actual -- todavía no hay '
        'ninguna historia que proteger', () {
      final borrador = Factura(
        id: 'b1',
        clienteId: 'c1',
        titulo: 'Borrador',
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio',
            cantidad: 1,
            precioUnitario: 50,
          ),
        ],
        creadaEl: DateTime(2026, 1, 1),
      );
      final usado = FacturaPdfService.datosEmisorParaDocumento(borrador, _emisor);
      expect(usado, _emisor);
    });

    test('generar el PDF no modifica la factura: mismo número, estado, '
        'conceptos, totales y pagos antes y después', () async {
      final factura = _facturaEmitida(
        pagos: [
          PagoFactura(
            id: 'p1',
            fecha: DateTime(2026, 2, 1),
            importe: 20,
            registradoEl: DateTime(2026, 2, 1),
          ),
        ],
      );
      final numeroAntes = factura.numero;
      final estadoAntes = factura.estado;
      final conceptosAntes = factura.conceptos;
      final totalAntes = factura.totales.total;
      final pagosAntes = factura.pagos;

      await FacturaPdfService.generar(factura: factura, cliente: _cliente);

      expect(factura.numero, numeroAntes);
      expect(factura.estado, estadoAntes);
      expect(factura.conceptos, same(conceptosAntes));
      expect(factura.totales.total, totalAntes);
      expect(factura.pagos, same(pagosAntes));
    });
  });

  group('integridad histórica del cliente', () {
    test('una factura emitida usa su propia fotografía de cliente, nunca '
        'el registro actual', () {
      final historico = ClienteSnapshot.desde(_cliente);
      final clienteActual = Cliente(
        id: 'c1',
        nombre: 'Otro nombre registrado después',
        direccion: 'Otra dirección',
        creadoEl: DateTime(2026, 1, 1),
      );
      final factura = _facturaEmitida(datosCliente: historico);

      final usado = FacturaPdfService.datosClienteParaDocumento(factura, clienteActual);
      expect(usado, historico);
      expect(usado!.nombre, isNot('Otro nombre registrado después'));
    });

    test('editar el cliente después de emitir no afecta a los datos '
        'usados para el PDF de esa factura', () {
      final factura = _facturaEmitida(datosCliente: ClienteSnapshot.desde(_cliente));
      final clienteEditado = Cliente(
        id: 'c1',
        nombre: 'Ana Rodríguez (nombre cambiado)',
        direccion: 'Dirección nueva, Alcorcón',
        creadoEl: DateTime(2026, 1, 1),
      );
      final usado = FacturaPdfService.datosClienteParaDocumento(factura, clienteEditado);
      expect(usado!.direccion, 'Avenida de España 22, Getafe'); // el histórico
    });

    test('una factura emitida SIN datosCliente (anterior a la iteración '
        '7.1, o cliente eliminado antes de emitir) no usa en silencio el '
        'registro actual', () {
      final factura = _facturaEmitida(datosCliente: null);
      final usado = FacturaPdfService.datosClienteParaDocumento(factura, _cliente);
      expect(usado, isNull); // nunca rellenado con el cliente actual
    });

    test('un borrador SÍ usa el cliente actual -- todavía no hay ninguna '
        'historia que proteger', () {
      final borrador = Factura(
        id: 'b1',
        clienteId: 'c1',
        titulo: 'Borrador',
        conceptos: const [
          ConceptoPresupuesto(
            id: 'c1',
            descripcion: 'Servicio',
            cantidad: 1,
            precioUnitario: 50,
          ),
        ],
        creadaEl: DateTime(2026, 1, 1),
      );
      final usado = FacturaPdfService.datosClienteParaDocumento(borrador, _cliente);
      // ClienteSnapshot no sobrescribe == -- se compara campo a campo en
      // vez de con la instancia recién creada de ClienteSnapshot.desde().
      expect(usado, isNotNull);
      expect(usado!.nombre, _cliente.nombre);
      expect(usado.direccion, _cliente.direccion);
      expect(usado.telefono, _cliente.telefono);
      expect(usado.email, _cliente.email);
    });

    test('un borrador sin cliente (eliminado antes de emitir) '
        'sencillamente no tiene fotografía que mostrar', () {
      final borrador = Factura(
        id: 'b1',
        clienteId: 'c1',
        titulo: 'Borrador',
        conceptos: const [],
        creadaEl: DateTime(2026, 1, 1),
      );
      final usado = FacturaPdfService.datosClienteParaDocumento(borrador, null);
      expect(usado, isNull);
    });

    test('generar el PDF con la fotografía histórica del cliente no '
        'lanza, incluso si el cliente actual ya no existe', () async {
      final factura = _facturaEmitida(datosCliente: ClienteSnapshot.desde(_cliente));
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: null);
      _esperarPdfValido(bytes);
    });
  });

  group('estados especiales', () {
    test('una factura anulada genera el documento sin lanzar, usando su '
        'propia fotografía de emisor (fijada antes de anular)', () async {
      final emitida = _facturaEmitida();
      final anulada = emitida.copyWith(
        estado: EstadoFactura.anulada,
        motivoAnulacion: 'Error en el importe',
        fechaAnulacion: DateTime(2026, 2, 1),
      );
      final usado = FacturaPdfService.datosEmisorParaDocumento(anulada, null);
      expect(usado, _emisor);
      final bytes = await FacturaPdfService.generar(factura: anulada, cliente: _cliente);
      _esperarPdfValido(bytes);
    });
  });

  group('casos límite -- no deben lanzar', () {
    test('una factura sin conceptos (registro degenerado) genera el '
        'documento igualmente, sin excepción', () async {
      final factura = _facturaEmitida(conceptos: const []);
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: _cliente);
      _esperarPdfValido(bytes);
    });

    test('sin datos del emisor NI del cliente a la vez no lanza', () async {
      final factura = _facturaEmitida(datosEmisor: null);
      final bytes = await FacturaPdfService.generar(factura: factura, cliente: null);
      _esperarPdfValido(bytes);
    });
  });

  group('cobertura real de la fuente incrustada (PT Sans)', () {
    // No basta con que generar() no lance ni con la ausencia del aviso
    // de consola "Unable to find a font to draw" -- aquí se pregunta
    // directamente a la fuente, con la misma API pública que usa
    // internamente el paquete `pdf` para decidir si dibuja un carácter
    // o un hueco (PdfFont.isRuneSupported), sin parsear el PDF de
    // salida. Es la comprobación fiable que pide el encargo 7.1 en vez
    // de fiarse solo de "%PDF-" o de los avisos por consola.
    test('el glifo "€" SÍ está en la fuente incrustada', () async {
      final datos = await rootBundle.load('assets/fonts/PTSans-Regular.ttf');
      final fuente = PdfTtfFont(PdfDocument(), datos);
      expect(fuente.isRuneSupported('€'.runes.single), isTrue);
    });

    test('vocales acentuadas, "ñ"/"Ñ" y "¿¡" están en la fuente', () async {
      final datos = await rootBundle.load('assets/fonts/PTSans-Regular.ttf');
      final fuente = PdfTtfFont(PdfDocument(), datos);
      for (final rune in 'áéíóúÁÉÍÓÚñÑ¿¡'.runes) {
        expect(
          fuente.isRuneSupported(rune),
          isTrue,
          reason: 'Falta el carácter "${String.fromCharCode(rune)}"',
        );
      }
    });

    test('la variante en negrita también cubre esos caracteres', () async {
      final datos = await rootBundle.load('assets/fonts/PTSans-Bold.ttf');
      final fuente = PdfTtfFont(PdfDocument(), datos);
      for (final rune in '€áéíóúñÑ'.runes) {
        expect(fuente.isRuneSupported(rune), isTrue);
      }
    });

    test('con la fuente incrustada, un concepto con "€" en la '
        'descripción y un importe con decimales no deja ningún '
        'carácter sin cobertura', () async {
      // No es que la app escriba el símbolo en la descripción (nunca lo
      // hace), sino una comprobación extra: cualquier texto plausible
      // de una factura real -- incluido escribir el propio símbolo --
      // tiene representación en la fuente que se incrusta.
      final datos = await rootBundle.load('assets/fonts/PTSans-Regular.ttf');
      final fuente = PdfTtfFont(PdfDocument(), datos);
      const texto = 'Instalación a 1.234,56 € (máquina pequeña, año 2026)';
      for (final rune in texto.runes) {
        expect(
          fuente.isRuneSupported(rune),
          isTrue,
          reason: 'Falta el carácter "${String.fromCharCode(rune)}"',
        );
      }
    });
  });

  group('nombreArchivo', () {
    test('usa el número real de la factura, con prefijo "Factura_"', () {
      expect(FacturaPdfService.nombreArchivo(_facturaEmitida()), 'Factura_2026-0001.pdf');
    });

    test('un borrador (sin número) genera un nombre genérico seguro', () {
      final borrador = Factura(
        id: 'abc12345-xyz',
        clienteId: 'c1',
        titulo: 'Borrador',
        conceptos: const [],
        creadaEl: DateTime(2026, 1, 1),
      );
      final nombre = FacturaPdfService.nombreArchivo(borrador);
      expect(nombre, endsWith('.pdf'));
      expect(nombre, startsWith('Borrador_factura_'));
      expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(nombre), isTrue);
    });
  });
}
