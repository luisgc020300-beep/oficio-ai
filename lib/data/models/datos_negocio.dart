// lib/data/models/datos_negocio.dart
//
// Datos del propio negocio del profesional (el emisor de sus facturas)
// -- un registro único, distinto de Cliente: Cliente modela a quien se
// le factura, esto modela a quien factura. Nunca se usa Cliente como
// sustituto de esto, ni al revés.
//
// Sin credenciales ni secretos aquí -- solo datos identificativos y
// fiscales que van a aparecer impresos en una factura.
enum TipoTitular { autonomo, empresa }

String nombreTipoTitular(TipoTitular t) => switch (t) {
  TipoTitular.autonomo => 'Autónomo / profesional',
  TipoTitular.empresa => 'Empresa / sociedad',
};

/// Según el tipo de titular, lo que la AEAT exige en una factura es el
/// nombre y apellidos (autónomo) o la razón social (empresa) -- mismo
/// campo [DatosNegocio.nombreFiscal], solo cambia la etiqueta que se le
/// muestra al usuario.
String etiquetaNombreFiscal(TipoTitular t) => switch (t) {
  TipoTitular.autonomo => 'Nombre y apellidos *',
  TipoTitular.empresa => 'Razón social *',
};

TipoTitular tipoTitularFromString(String? s) => TipoTitular.values
    .firstWhere((t) => t.name == s, orElse: () => TipoTitular.autonomo);

/// Solo valida FORMATO -- nunca que el número pertenezca de verdad a
/// una persona o empresa dada de alta. Esa comprobación requeriría un
/// servicio oficial externo, fuera del alcance de esta iteración.
final _dniRegex = RegExp(r'^\d{8}[A-Za-z]$');
final _nieRegex = RegExp(r'^[XYZxyz]\d{7}[A-Za-z]$');
// CIF: letra inicial + 7 dígitos + un carácter de control (letra o
// dígito según el tipo de entidad). Se valida el formato -- no se
// verifica el dígito de control del CIF: a diferencia del DNI/NIE, la
// fórmula pública consultada no se pudo confirmar en una fuente oficial
// (ver informe de la iteración), así que no se afirma más de lo que se
// comprueba.
final _cifRegex = RegExp(r'^[A-HJNPQRSUVWabhjnpqrsuvw]\d{7}[0-9A-Za-z]$');
const _letrasDniNie = 'TRWAGMYFPDXBNJZSQVHLCKE';

bool _letraDniNieValida(String numero8, String letra) {
  final idx = int.parse(numero8) % 23;
  return _letrasDniNie[idx].toUpperCase() == letra.toUpperCase();
}

/// null = formato aceptado (o campo vacío -- la obligatoriedad se
/// comprueba aparte, en [DatosNegocio.camposFaltantesParaFacturar]).
/// Si no es null, es el mensaje de error a mostrar junto al campo.
String? validarFormatoNif(String valor) {
  final v = valor.trim().toUpperCase().replaceAll(' ', '');
  if (v.isEmpty) return null;
  if (_dniRegex.hasMatch(v)) {
    final numero = v.substring(0, 8);
    final letra = v.substring(8);
    return _letraDniNieValida(numero, letra)
        ? null
        : 'La letra no coincide con el número de DNI.';
  }
  if (_nieRegex.hasMatch(v)) {
    const prefijos = {'X': '0', 'Y': '1', 'Z': '2'};
    final numero = prefijos[v[0]]! + v.substring(1, 8);
    final letra = v.substring(8);
    return _letraDniNieValida(numero, letra)
        ? null
        : 'La letra no coincide con el número de NIE.';
  }
  if (_cifRegex.hasMatch(v)) return null;
  return 'No parece un NIF, NIE o CIF válido.';
}

String? validarFormatoEmail(String valor) {
  final v = valor.trim();
  if (v.isEmpty) return null;
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  return ok ? null : 'Email no válido.';
}

/// Deliberadamente laxo -- no asume un único formato nacional. Solo
/// descarta lo que claramente no es un teléfono (letras, longitud
/// absurda), sin exigir un prefijo de país concreto.
String? validarFormatoTelefono(String valor) {
  final v = valor.trim();
  if (v.isEmpty) return null;
  final formatoOk = RegExp(r'^[0-9+()\-.\s]+$').hasMatch(v);
  final soloDigitos = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (!formatoOk || soloDigitos.length < 7 || soloDigitos.length > 15) {
    return 'Teléfono no válido.';
  }
  return null;
}

/// Código postal de España: 5 dígitos. Para cualquier otro país no se
/// impone un formato -- cada país tiene el suyo y no es el objetivo de
/// esta iteración modelarlos todos.
String? validarCodigoPostal(String valor, String pais) {
  final v = valor.trim();
  if (v.isEmpty) return null;
  if (pais.trim().toLowerCase() != 'españa') return null;
  return RegExp(r'^\d{5}$').hasMatch(v) ? null : 'Código postal no válido.';
}

class DatosNegocio {
  const DatosNegocio({
    this.nombreComercial,
    required this.nombreFiscal,
    required this.nif,
    this.tipoTitular = TipoTitular.autonomo,
    this.actividad,
    this.telefono,
    this.email,
    this.web,
    this.direccion,
    this.codigoPostal,
    this.localidad,
    this.provincia,
    this.pais = 'España',
    this.logoPath,
  });

  /// Nombre de marca, puede diferir del nombre o razón social legal
  /// (p. ej. "Fontanería Rápida" como nombre comercial de "Juan Pérez
  /// García"). Opcional -- si no se rellena, se usa [nombreFiscal].
  final String? nombreComercial;

  /// Nombre y apellidos (autónomo) o razón social (empresa) -- el dato
  /// que exige la normativa de facturación, no una preferencia visual.
  final String nombreFiscal;
  final String nif;
  final TipoTitular tipoTitular;
  final String? actividad;
  final String? telefono;
  final String? email;
  final String? web;

  final String? direccion;
  final String? codigoPostal;
  final String? localidad;
  final String? provincia;
  final String pais;

  /// Ruta local al logotipo. Preparado para cuando se implemente la
  /// selección/gestión de imagen (ver informe: fuera de alcance de esta
  /// iteración por la complejidad de manejar archivos de forma segura
  /// sin ninguna infraestructura previa en el proyecto para ello).
  final String? logoPath;

  /// Lo mínimo que una factura ordinaria necesita de su emisor según el
  /// RD 1619/2012 (identificación completa + domicilio) -- nombre
  /// comercial, teléfono, email, web, actividad y logo quedan fuera
  /// porque no son exigibles para poder emitir. Vacío == todo lo
  /// necesario está presente.
  List<String> get camposFaltantesParaFacturar => [
    if (nombreFiscal.trim().isEmpty) 'Nombre o razón social',
    if (nif.trim().isEmpty) 'NIF/CIF',
    if ((direccion ?? '').trim().isEmpty) 'Dirección',
    if ((codigoPostal ?? '').trim().isEmpty) 'Código postal',
    if ((localidad ?? '').trim().isEmpty) 'Localidad',
    if ((provincia ?? '').trim().isEmpty) 'Provincia',
  ];

  bool get listoParaFacturar => camposFaltantesParaFacturar.isEmpty;

  DatosNegocio copyWith({
    String? nombreComercial,
    String? nombreFiscal,
    String? nif,
    TipoTitular? tipoTitular,
    String? actividad,
    String? telefono,
    String? email,
    String? web,
    String? direccion,
    String? codigoPostal,
    String? localidad,
    String? provincia,
    String? pais,
    String? logoPath,
  }) => DatosNegocio(
    nombreComercial: nombreComercial ?? this.nombreComercial,
    nombreFiscal: nombreFiscal ?? this.nombreFiscal,
    nif: nif ?? this.nif,
    tipoTitular: tipoTitular ?? this.tipoTitular,
    actividad: actividad ?? this.actividad,
    telefono: telefono ?? this.telefono,
    email: email ?? this.email,
    web: web ?? this.web,
    direccion: direccion ?? this.direccion,
    codigoPostal: codigoPostal ?? this.codigoPostal,
    localidad: localidad ?? this.localidad,
    provincia: provincia ?? this.provincia,
    pais: pais ?? this.pais,
    logoPath: logoPath ?? this.logoPath,
  );

  Map<String, dynamic> toJson() => {
    'nombreComercial': nombreComercial,
    'nombreFiscal': nombreFiscal,
    'nif': nif,
    'tipoTitular': tipoTitular.name,
    'actividad': actividad,
    'telefono': telefono,
    'email': email,
    'web': web,
    'direccion': direccion,
    'codigoPostal': codigoPostal,
    'localidad': localidad,
    'provincia': provincia,
    'pais': pais,
    'logoPath': logoPath,
  };

  factory DatosNegocio.fromJson(Map<String, dynamic> json) => DatosNegocio(
    nombreComercial: json['nombreComercial'] as String?,
    nombreFiscal: json['nombreFiscal'] as String? ?? '',
    nif: json['nif'] as String? ?? '',
    tipoTitular: tipoTitularFromString(json['tipoTitular'] as String?),
    actividad: json['actividad'] as String?,
    telefono: json['telefono'] as String?,
    email: json['email'] as String?,
    web: json['web'] as String?,
    direccion: json['direccion'] as String?,
    codigoPostal: json['codigoPostal'] as String?,
    localidad: json['localidad'] as String?,
    provincia: json['provincia'] as String?,
    pais: json['pais'] as String? ?? 'España',
    logoPath: json['logoPath'] as String?,
  );
}
