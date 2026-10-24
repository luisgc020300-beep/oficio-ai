// lib/data/repositories/gasto_repository.dart
//
// Mismo criterio que FacturaRepository para no perder el historial:
// anular() en vez de borrar, nunca se edita un gasto ya anulado. A
// diferencia de las facturas, un gasto no tiene numeración ni "emisión"
// -- se crea directamente activo, así que no hace falta un estado de
// borrador aparte.
import 'package:flutter/foundation.dart';

import '../local/local_store.dart';
import '../models/gasto.dart';

class GastoRepository extends ChangeNotifier {
  GastoRepository(this._store);

  static const _key = 'oficio_ai.gastos';

  final LocalStore _store;
  List<Gasto> _gastos = [];

  List<Gasto> get gastos => List.unmodifiable(_gastos);

  /// Los únicos que deben entrar en cualquier total -- un gasto
  /// anulado nunca computa (encargo, sección 1).
  List<Gasto> get activos =>
      _gastos.where((g) => g.estado == EstadoGasto.activo).toList();

  Gasto? byId(String id) {
    for (final g in _gastos) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Todos los gastos de [trabajoId], vigentes o anulados -- igual que
  /// FacturaRepository.porTrabajo(), quien necesite solo los activos
  /// filtra sobre el resultado (ver job_detail_screen.dart).
  List<Gasto> porTrabajo(String trabajoId) =>
      _gastos.where((g) => g.trabajoId == trabajoId).toList();

  Future<void> load() async {
    final raw = _store.readList(_key);
    _gastos = raw.map(Gasto.fromJson).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    notifyListeners();
  }

  Future<void> seedIfEmpty(List<Gasto> seed) async {
    if (_gastos.isNotEmpty) return;
    _gastos = [...seed]..sort((a, b) => b.fecha.compareTo(a.fecha));
    await _persist();
    notifyListeners();
  }

  void _validar(Gasto gasto) {
    if (gasto.descripcion.trim().isEmpty) {
      throw ArgumentError('La descripción del gasto es obligatoria.');
    }
    if (gasto.importe <= 0) {
      throw ArgumentError('El importe del gasto debe ser mayor que cero.');
    }
  }

  Future<void> add(Gasto gasto) async {
    _validar(gasto);
    if (gasto.estado != EstadoGasto.activo) {
      throw StateError('Un gasto nuevo solo puede crearse como activo.');
    }
    await _guardar([..._gastos, gasto]);
  }

  /// Solo se puede editar mientras está activo -- un gasto anulado se
  /// conserva tal cual se registró, igual que una factura emitida (ver
  /// FacturaRepository.update()).
  Future<void> update(Gasto gasto) async {
    final actual = byId(gasto.id);
    if (actual == null) {
      throw StateError('Este gasto ya no existe.');
    }
    if (actual.estado != EstadoGasto.activo) {
      throw StateError('No se puede editar un gasto anulado.');
    }
    if (gasto.estado != EstadoGasto.activo) {
      throw StateError('Usa anular() para anular un gasto.');
    }
    _validar(gasto);
    await _guardar(_gastos.map((g) => g.id == gasto.id ? gasto : g).toList());
  }

  /// Anula sin borrar -- el gasto y su importe se conservan para el
  /// rastro, pero deja de computar en cualquier total activo. Si se
  /// registró de más por error, se anula y, si procede, se crea uno
  /// nuevo correcto -- no hay delete().
  Future<Gasto> anular(String id, String motivo) async {
    if (motivo.trim().isEmpty) {
      throw ArgumentError('El motivo de anulación es obligatorio.');
    }
    final actual = byId(id);
    if (actual == null) {
      throw StateError('Este gasto ya no existe.');
    }
    if (actual.estado != EstadoGasto.activo) {
      throw StateError('Este gasto ya está anulado.');
    }
    final anulado = actual.copyWith(
      estado: EstadoGasto.anulado,
      motivoAnulacion: motivo.trim(),
      fechaAnulacion: DateTime.now(),
    );
    await _guardar(_gastos.map((g) => g.id == id ? anulado : g).toList());
    return anulado;
  }

  /// Mismo mecanismo que FacturaRepository._guardar(): si falla la
  /// escritura en disco, la memoria vuelve a como estaba, para que
  /// memoria y disco nunca diverjan.
  Future<void> _guardar(List<Gasto> nuevaLista) async {
    final anterior = _gastos;
    _gastos = nuevaLista..sort((a, b) => b.fecha.compareTo(a.fecha));
    try {
      await _persist();
    } catch (_) {
      _gastos = anterior;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.writeList(_key, _gastos.map((g) => g.toJson()).toList());

  /// Borra todos los gastos del dispositivo -- usado al "cerrar sesión"
  /// (ver settings_screen.dart).
  Future<void> limpiar() async {
    _gastos = [];
    await _store.remove(_key);
    notifyListeners();
  }
}
