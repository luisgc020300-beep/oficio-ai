// lib/features/settings/settings_screen.dart
//
// Ajustes, con listas agrupadas estilo iOS (CupertinoListSection) -- es
// el patrón que se pidió explícitamente, no una pantalla Material
// reconstruida a mano para parecerse. "Cerrar sesión" es honesto con lo
// que esta app realmente es: un prototipo 100% local sin backend ni
// cuentas, así que lo único que puede "cerrar sesión" de verdad es
// borrar los datos de este dispositivo (ver AppData.cerrarSesion()).
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/app_data.dart';
import 'business_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.appData,
    required this.themeController,
    super.key,
  });

  final AppData appData;
  final ThemeController themeController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cerrandoSesion = false;

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Oficio AI guarda tus datos solo en este dispositivo. Al cerrar '
          'sesión se borrarán clientes, trabajos, presupuestos, facturas, '
          'citas, gastos y los datos de tu negocio. Esta acción no se '
          'puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _cerrandoSesion = true);
    try {
      await widget.appData.cerrarSesion();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada: se han borrado los datos de este dispositivo.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se han podido borrar los datos. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cerrandoSesion = false);
    }
  }

  Widget _cabecera(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.inkFaint,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListenableBuilder(
        listenable: widget.themeController,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.md,
              AppSpace.md,
              AppSpace.xl,
            ),
            children: [
              _cabecera('APARIENCIA'),
              CupertinoListSection.insetGrouped(
                margin: EdgeInsets.zero,
                backgroundColor: AppColors.background,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                children: [
                  CupertinoListTile(
                    leading: Icon(
                      CupertinoIcons.moon_stars_fill,
                      color: AppColors.primary,
                    ),
                    title: const Text('Modo oscuro'),
                    trailing: CupertinoSwitch(
                      value: widget.themeController.oscuro,
                      activeTrackColor: AppColors.primary,
                      onChanged: (valor) => widget.themeController.cambiar(valor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _cabecera('NEGOCIO'),
              CupertinoListSection.insetGrouped(
                margin: EdgeInsets.zero,
                backgroundColor: AppColors.background,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                children: [
                  CupertinoListTile(
                    leading: Icon(
                      CupertinoIcons.briefcase_fill,
                      color: AppColors.primary,
                    ),
                    title: const Text('Mi negocio'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusinessSettingsScreen(appData: widget.appData),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _cabecera('CUENTA'),
              CupertinoListSection.insetGrouped(
                margin: EdgeInsets.zero,
                backgroundColor: AppColors.background,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No hay ninguna cuenta ni servidor: todo vive en este '
                    'dispositivo. "Cerrar sesión" borra esos datos y deja '
                    'la app como recién instalada.',
                    style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.inkFaint),
                  ),
                ),
                children: [
                  CupertinoListTile(
                    leading: _cerrandoSesion
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CupertinoActivityIndicator(),
                          )
                        : Icon(CupertinoIcons.square_arrow_right, color: AppColors.error),
                    title: Text(
                      'Cerrar sesión',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                    onTap: _cerrandoSesion ? null : _confirmarCerrarSesion,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
