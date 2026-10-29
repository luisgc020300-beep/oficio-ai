// lib/features/settings/business_settings_screen.dart
//
// "Mi negocio": datos del emisor de las facturas. Guarda en cuanto se
// pulsa "Guardar" -- no exige rellenarlo todo de golpe, solo valida el
// FORMATO de lo que sí se ha escrito (ver datos_negocio.dart). La
// obligatoriedad real para poder facturar se comprueba aparte, al
// intentar emitir (ver invoice_detail_screen.dart), no aquí.
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_data.dart';
import '../../data/models/datos_negocio.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  DatosNegocio? get _actual => widget.appData.negocio.datos;

  late final _nombreComercialCtrl =
      TextEditingController(text: _actual?.nombreComercial ?? '');
  late final _nombreFiscalCtrl =
      TextEditingController(text: _actual?.nombreFiscal ?? '');
  late final _nifCtrl = TextEditingController(text: _actual?.nif ?? '');
  late final _actividadCtrl = TextEditingController(text: _actual?.actividad ?? '');
  late final _telefonoCtrl = TextEditingController(text: _actual?.telefono ?? '');
  late final _emailCtrl = TextEditingController(text: _actual?.email ?? '');
  late final _webCtrl = TextEditingController(text: _actual?.web ?? '');
  late final _direccionCtrl = TextEditingController(text: _actual?.direccion ?? '');
  late final _codigoPostalCtrl =
      TextEditingController(text: _actual?.codigoPostal ?? '');
  late final _localidadCtrl = TextEditingController(text: _actual?.localidad ?? '');
  late final _provinciaCtrl = TextEditingController(text: _actual?.provincia ?? '');
  late final _paisCtrl = TextEditingController(text: _actual?.pais ?? 'España');

  late TipoTitular _tipoTitular = _actual?.tipoTitular ?? TipoTitular.autonomo;
  bool _guardando = false;
  bool _tocado = false;

  /// Evita dos diálogos de "¿Descartar los cambios?" apilados si llegan
  /// dos intentos de navegación seguidos (p. ej. doble toque en atrás)
  /// antes de que el primero se haya cerrado (iteración 6.1).
  bool _confirmandoDescarte = false;

  @override
  void dispose() {
    _nombreComercialCtrl.dispose();
    _nombreFiscalCtrl.dispose();
    _nifCtrl.dispose();
    _actividadCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _webCtrl.dispose();
    _direccionCtrl.dispose();
    _codigoPostalCtrl.dispose();
    _localidadCtrl.dispose();
    _provinciaCtrl.dispose();
    _paisCtrl.dispose();
    super.dispose();
  }

  String? _opcional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_nombreFiscalCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe al menos el nombre o razón social.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.appData.negocio.guardar(
        DatosNegocio(
          nombreComercial: _opcional(_nombreComercialCtrl),
          nombreFiscal: _nombreFiscalCtrl.text.trim(),
          nif: _nifCtrl.text.trim(),
          tipoTitular: _tipoTitular,
          actividad: _opcional(_actividadCtrl),
          telefono: _opcional(_telefonoCtrl),
          email: _opcional(_emailCtrl),
          web: _opcional(_webCtrl),
          direccion: _opcional(_direccionCtrl),
          codigoPostal: _opcional(_codigoPostalCtrl),
          localidad: _opcional(_localidadCtrl),
          provincia: _opcional(_provinciaCtrl),
          pais: _paisCtrl.text.trim().isEmpty ? 'España' : _paisCtrl.text.trim(),
        ),
      );
      _tocado = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos guardados.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se han podido guardar los datos. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarDescartar() async {
    if (_confirmandoDescarte) return;
    _confirmandoDescarte = true;
    try {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Descartar los cambios?'),
          content: const Text('Se perderán los cambios que no has guardado.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (descartar == true && mounted) Navigator.pop(context);
    } finally {
      _confirmandoDescarte = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_tocado,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmarDescartar();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mi negocio')),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_tocado) setState(() => _tocado = true);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.md,
              AppSpace.md,
              140,
            ),
            children: [
              if (_actual == null)
                Container(
                  padding: const EdgeInsets.all(AppSpace.sm + 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          'Todavía no has configurado los datos de tu negocio. '
                          'Hacen falta para poder emitir facturas.',
                          style: const TextStyle(fontSize: 12, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_actual == null) const SizedBox(height: AppSpace.md),
              Text('Identificación', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<TipoTitular>(
                initialValue: _tipoTitular,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de titular'),
                items: TipoTitular.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          nombreTipoTitular(t),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _tipoTitular = v);
                  _tocado = true;
                },
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _nombreComercialCtrl,
                decoration: const InputDecoration(labelText: 'Nombre comercial'),
                textCapitalization: TextCapitalization.words,
                maxLines: null,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _nombreFiscalCtrl,
                decoration: InputDecoration(
                  labelText: etiquetaNombreFiscal(_tipoTitular),
                ),
                textCapitalization: TextCapitalization.words,
                maxLines: null,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _nifCtrl,
                decoration: const InputDecoration(labelText: 'NIF/CIF *'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null ? null : validarFormatoNif(v),
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _actividadCtrl,
                decoration: const InputDecoration(labelText: 'Actividad profesional'),
                maxLines: null,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null ? null : validarFormatoTelefono(v),
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null ? null : validarFormatoEmail(v),
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _webCtrl,
                decoration: const InputDecoration(labelText: 'Sitio web'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSpace.lg),
              Text('Domicilio fiscal', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección *'),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codigoPostalCtrl,
                      decoration: const InputDecoration(labelText: 'Código postal *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null
                          ? null
                          : validarCodigoPostal(v, _paisCtrl.text),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _localidadCtrl,
                      decoration: const InputDecoration(labelText: 'Localidad *'),
                      textCapitalization: TextCapitalization.words,
                      maxLines: null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _provinciaCtrl,
                decoration: const InputDecoration(labelText: 'Provincia *'),
                textCapitalization: TextCapitalization.words,
                maxLines: null,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: _paisCtrl,
                decoration: const InputDecoration(labelText: 'País'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpace.lg),
              Text('Imagen de marca', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpace.sm),
              Container(
                padding: const EdgeInsets.all(AppSpace.sm + 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: AppColors.inkFaint,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        'El logotipo para las facturas llegará en una próxima '
                        'actualización.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomSheet: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
