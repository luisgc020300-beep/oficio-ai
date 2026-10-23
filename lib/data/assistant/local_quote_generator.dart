// lib/data/assistant/local_quote_generator.dart
//
// Implementación local de QuoteGenerator -- reglas de palabras clave
// sobre un pequeño catálogo de fontanería/electricidad/instalaciones,
// nada de IA ni de red. Precios orientativos, pensados para que el
// profesional los ajuste a los suyos reales antes de guardar: NUNCA se
// presentan como tarifas verificadas de mercado ni como resultado de
// consultar a ningún proveedor.
import 'package:uuid/uuid.dart';

import '../models/concepto_presupuesto.dart';
import 'propuesta_presupuesto.dart';
import 'quote_generator.dart';

class _Patron {
  const _Patron({
    required this.categoria,
    required this.palabrasClave,
    required this.conceptos,
  });

  final String categoria;
  final List<String> palabrasClave;
  final List<ConceptoPresupuesto> Function() conceptos;
}

String _normalizar(String texto) {
  const conTilde = 'áéíóúÁÉÍÓÚñÑ';
  const sinTilde = 'aeiouAEIOUnN';
  var resultado = texto.toLowerCase();
  for (var i = 0; i < conTilde.length; i++) {
    resultado = resultado.replaceAll(conTilde[i].toLowerCase(), sinTilde[i].toLowerCase());
  }
  return resultado;
}

List<ConceptoPresupuesto> _lineas(List<(String, double, double)> datos) =>
    datos
        .map(
          (d) => ConceptoPresupuesto(
            id: const Uuid().v4(),
            descripcion: d.$1,
            cantidad: d.$2,
            precioUnitario: d.$3,
          ),
        )
        .toList();

/// Catálogo de patrones reconocidos -- fontanería, electricidad e
/// instalaciones, los tres oficios que pide el encargo. Precios
/// orientativos de referencia (no verificados, no de mercado real).
final _catalogo = <_Patron>[
  _Patron(
    categoria: 'cambio de grifo',
    palabrasClave: ['grifo'],
    conceptos: () => _lineas([
      ('Mano de obra -- cambio de grifo', 1, 30),
      ('Grifo nuevo', 1, 45),
    ]),
  ),
  _Patron(
    categoria: 'reparación de fuga',
    palabrasClave: ['fuga', 'gotea', 'goteo'],
    conceptos: () => _lineas([
      ('Diagnóstico y reparación de fuga', 1.5, 35),
      ('Material de sellado/piezas', 1, 12),
    ]),
  ),
  _Patron(
    categoria: 'desatasco',
    palabrasClave: ['atasco', 'atascad', 'desatasc'],
    conceptos: () => _lineas([('Desatasco de tubería', 1, 45)]),
  ),
  _Patron(
    categoria: 'instalación de termo',
    palabrasClave: ['termo'],
    conceptos: () => _lineas([
      ('Termo eléctrico', 1, 180),
      ('Mano de obra -- instalación', 2, 32),
    ]),
  ),
  _Patron(
    categoria: 'cisterna/WC',
    palabrasClave: ['cisterna', 'inodoro', ' wc', 'water'],
    conceptos: () => _lineas([
      ('Mecanismo de cisterna', 1, 25),
      ('Mano de obra', 1, 30),
    ]),
  ),
  _Patron(
    categoria: 'cambio de enchufe',
    palabrasClave: ['enchufe'],
    conceptos: () => _lineas([
      ('Enchufe nuevo', 1, 8),
      ('Mano de obra', 0.5, 30),
    ]),
  ),
  _Patron(
    categoria: 'cambio de interruptor',
    palabrasClave: ['interruptor'],
    conceptos: () => _lineas([
      ('Interruptor nuevo', 1, 6),
      ('Mano de obra', 0.5, 30),
    ]),
  ),
  _Patron(
    categoria: 'instalación de lámpara',
    palabrasClave: ['lampara', 'foco', 'plafon'],
    conceptos: () => _lineas([
      ('Lámpara / material eléctrico', 1, 20),
      ('Mano de obra -- instalación', 1, 30),
    ]),
  ),
  _Patron(
    categoria: 'revisión de cuadro eléctrico',
    palabrasClave: ['cuadro electrico', 'diferencial', 'automatico'],
    conceptos: () => _lineas([
      ('Revisión de cuadro eléctrico', 2, 35),
      ('Material eléctrico', 1, 50),
    ]),
  ),
  _Patron(
    categoria: 'instalación de aire acondicionado',
    palabrasClave: ['aire acondicionado', 'climatizador'],
    conceptos: () => _lineas([
      ('Unidad de aire acondicionado', 1, 450),
      ('Mano de obra -- instalación', 4, 35),
    ]),
  ),
  _Patron(
    categoria: 'reparación de persiana',
    palabrasClave: ['persiana'],
    conceptos: () => _lineas([
      ('Reparación de persiana', 1, 30),
      ('Material', 1, 20),
    ]),
  ),
  _Patron(
    categoria: 'cambio de cerradura',
    palabrasClave: ['cerradura', 'bombin', 'bombín'],
    conceptos: () => _lineas([
      ('Mano de obra -- cambio de cerradura', 1, 35),
      ('Cerradura nueva', 1, 40),
    ]),
  ),
  _Patron(
    categoria: 'revisión de caldera',
    palabrasClave: ['caldera'],
    conceptos: () => _lineas([('Revisión de caldera', 1.5, 38)]),
  ),
];

String _tituloGenerico(String descripcion) {
  final palabras = descripcion.trim().split(RegExp(r'\s+')).take(6).join(' ');
  final capitalizado = palabras.isEmpty
      ? 'nuevo trabajo'
      : palabras[0].toUpperCase() + palabras.substring(1);
  return 'Presupuesto: $capitalizado';
}

class LocalQuoteGenerator implements QuoteGenerator {
  @override
  Future<PropuestaPresupuesto> generar(String descripcion) async {
    final texto = descripcion.trim();
    if (texto.isEmpty) {
      throw ArgumentError('Describe el trabajo antes de generar una propuesta.');
    }

    final normalizado = _normalizar(texto);
    final patronesReconocidos = _catalogo
        .where((p) => p.palabrasClave.any((k) => normalizado.contains(k)))
        .toList();

    if (patronesReconocidos.isEmpty) {
      return PropuestaPresupuesto(
        tituloSugerido: _tituloGenerico(texto),
        conceptos: _lineas([('Mano de obra', 1, 0)]),
        confianza: NivelConfianza.baja,
        mensaje:
            'No he reconocido ningún trabajo concreto en tu descripción. '
            'Te dejo una línea genérica -- complétala tú mismo con el '
            'concepto, la cantidad y el precio reales antes de guardar.',
      );
    }

    final conceptos = [
      for (final patron in patronesReconocidos) ...patron.conceptos(),
    ];
    final categorias = patronesReconocidos.map((p) => p.categoria).toList();
    final titulo = categorias.first[0].toUpperCase() + categorias.first.substring(1);

    return PropuestaPresupuesto(
      tituloSugerido: categorias.length > 1
          ? '$titulo y ${categorias.length - 1} más'
          : titulo,
      conceptos: conceptos,
      confianza: NivelConfianza.alta,
      mensaje:
          'He reconocido: ${categorias.join(', ')}. Los precios son '
          'orientativos (no son tarifas de mercado verificadas ni vienen '
          'de ningún proveedor) -- revisa cantidades y precios antes de '
          'guardar.',
    );
  }
}
