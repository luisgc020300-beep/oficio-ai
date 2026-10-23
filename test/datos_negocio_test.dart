// test/datos_negocio_test.dart
//
// Modelo DatosNegocio en aislamiento: compatibilidad JSON con
// configuraciones antiguas o incompletas, qué hace falta para poder
// facturar, y los validadores de formato (NIF/NIE/CIF, email, teléfono,
// código postal) -- sin repositorio ni widgets (encargo iteración 6,
// sección 10, puntos 4, 6 y 7).
import 'package:flutter_test/flutter_test.dart';
import 'package:oficio_ai/data/models/datos_negocio.dart';

void main() {
  group('camposFaltantesParaFacturar / listoParaFacturar', () {
    test('todo vacío: faltan los 6 campos exigibles', () {
      const d = DatosNegocio(nombreFiscal: '', nif: '');
      expect(d.camposFaltantesParaFacturar, hasLength(6));
      expect(d.listoParaFacturar, isFalse);
    });

    test('completo: no falta nada', () {
      const d = DatosNegocio(
        nombreFiscal: 'Juan Pérez García',
        nif: '12345678Z',
        direccion: 'Calle Mayor 1',
        codigoPostal: '28001',
        localidad: 'Madrid',
        provincia: 'Madrid',
      );
      expect(d.camposFaltantesParaFacturar, isEmpty);
      expect(d.listoParaFacturar, isTrue);
    });

    test('nombre comercial, teléfono, email, web, actividad y logo NO '
        'son exigibles para facturar -- solo identificación y domicilio', () {
      const d = DatosNegocio(
        nombreFiscal: 'Juan Pérez García',
        nif: '12345678Z',
        direccion: 'Calle Mayor 1',
        codigoPostal: '28001',
        localidad: 'Madrid',
        provincia: 'Madrid',
        // Resto deliberadamente sin rellenar.
      );
      expect(d.listoParaFacturar, isTrue);
    });

    test('falta un único campo: solo ese aparece en la lista', () {
      const d = DatosNegocio(
        nombreFiscal: 'Juan Pérez García',
        nif: '12345678Z',
        direccion: 'Calle Mayor 1',
        codigoPostal: '28001',
        localidad: 'Madrid',
        // provincia sin rellenar
      );
      expect(d.camposFaltantesParaFacturar, ['Provincia']);
    });
  });

  group('JSON: compatibilidad con configuraciones antiguas/incompletas', () {
    test('ciclo toJson/fromJson conserva todos los campos', () {
      const d = DatosNegocio(
        nombreComercial: 'Fontanería Rápida',
        nombreFiscal: 'Juan Pérez García',
        nif: '12345678Z',
        tipoTitular: TipoTitular.empresa,
        actividad: 'Fontanería',
        telefono: '600 000 000',
        email: 'juan@email.com',
        web: 'https://juanfontanero.es',
        direccion: 'Calle Mayor 1',
        codigoPostal: '28001',
        localidad: 'Madrid',
        provincia: 'Madrid',
        pais: 'España',
      );
      final restaurado = DatosNegocio.fromJson(d.toJson());
      expect(restaurado.nombreComercial, 'Fontanería Rápida');
      expect(restaurado.tipoTitular, TipoTitular.empresa);
      expect(restaurado.nif, '12345678Z');
      expect(restaurado.codigoPostal, '28001');
    });

    test('un JSON con solo nombre y NIF (todo lo demás ausente) no '
        'rompe la lectura -- el resto queda null y el país por defecto', () {
      final json = {'nombreFiscal': 'Juan Pérez', 'nif': '12345678Z'};
      final d = DatosNegocio.fromJson(json);
      expect(d.nombreFiscal, 'Juan Pérez');
      expect(d.direccion, isNull);
      expect(d.pais, 'España');
      expect(d.tipoTitular, TipoTitular.autonomo);
      expect(d.listoParaFacturar, isFalse);
    });

    test('un JSON completamente vacío no lanza', () {
      final d = DatosNegocio.fromJson(const {});
      expect(d.nombreFiscal, '');
      expect(d.nif, '');
      expect(d.listoParaFacturar, isFalse);
    });
  });

  group('validarFormatoNif', () {
    test('DNI válido (letra correcta) no da error', () {
      expect(validarFormatoNif('12345678Z'), isNull);
      // Minúsculas y con espacio -- se normaliza antes de comprobar.
      expect(validarFormatoNif('1234 5678 z'), isNull);
    });

    test('DNI con la letra equivocada da error', () {
      expect(validarFormatoNif('12345678A'), isNotNull);
    });

    test('NIE válido (X/Y/Z + letra correcta) no da error', () {
      expect(validarFormatoNif('X1234567L'), isNull);
    });

    test('NIE con la letra equivocada da error', () {
      expect(validarFormatoNif('X1234567A'), isNotNull);
    });

    test('CIF: se acepta el formato sin verificar el dígito de control', () {
      // Documentado en datos_negocio.dart: solo formato, no checksum.
      expect(validarFormatoNif('B12345678'), isNull);
    });

    test('vacío no da error -- la obligatoriedad se comprueba aparte', () {
      expect(validarFormatoNif(''), isNull);
      expect(validarFormatoNif('   '), isNull);
    });

    test('algo que no tiene forma de NIF/NIE/CIF da error', () {
      expect(validarFormatoNif('abc'), isNotNull);
      expect(validarFormatoNif('123456789'), isNotNull);
    });
  });

  group('validarFormatoEmail', () {
    test('vacío no da error', () => expect(validarFormatoEmail(''), isNull));
    test(
      'email con forma válida no da error',
      () => expect(validarFormatoEmail('juan@email.com'), isNull),
    );
    test(
      'sin arroba da error',
      () => expect(validarFormatoEmail('juanemail.com'), isNotNull),
    );
  });

  group('validarFormatoTelefono', () {
    test('vacío no da error', () => expect(validarFormatoTelefono(''), isNull));
    test(
      'número español normal no da error',
      () => expect(validarFormatoTelefono('600 123 456'), isNull),
    );
    test(
      'con prefijo internacional no da error -- no asume un único país',
      () => expect(validarFormatoTelefono('+34 600 123 456'), isNull),
    );
    test(
      'con letras da error',
      () => expect(validarFormatoTelefono('abcdefg'), isNotNull),
    );
    test(
      'demasiado corto da error',
      () => expect(validarFormatoTelefono('123'), isNotNull),
    );
  });

  group('validarCodigoPostal', () {
    test('vacío no da error', () => expect(validarCodigoPostal('', 'España'), isNull));
    test(
      '5 dígitos en España no da error',
      () => expect(validarCodigoPostal('28001', 'España'), isNull),
    );
    test(
      '4 dígitos en España da error',
      () => expect(validarCodigoPostal('2800', 'España'), isNotNull),
    );
    test(
      'fuera de España no se impone el formato de 5 dígitos',
      () => expect(validarCodigoPostal('SW1A 1AA', 'Reino Unido'), isNull),
    );
  });
}
