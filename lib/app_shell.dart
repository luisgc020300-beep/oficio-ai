// lib/app_shell.dart
//
// Shell de navegación -- 5 destinos (dashboard, clients, jobs, invoices,
// calendar) en una única NavigationBar inferior -- el máximo recomendado
// para una barra de móvil (Material/iOS HIG); con 7 no cabían las
// etiquetas sin cortarse. Presupuestos y Asistente ya tenían (o ahora
// tienen) su propio acceso desde Inicio -- ver DashboardScreen -- así que
// no se pierde nada al sacarlos de la barra. IndexedStack mantiene vivo
// el estado de cada pestaña al cambiar entre ellas (no se pierde el
// scroll ni los filtros aplicados).
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/theme_controller.dart';
import 'data/app_data.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/clients/clients_list_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/invoices/invoices_list_screen.dart';
import 'features/jobs/jobs_list_screen.dart';
import 'features/quotes/quotes_list_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.appData, this.themeController, super.key});

  final AppData appData;
  final ThemeController? themeController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indice = 0;

  void _irA(int indice) => setState(() => _indice = indice);

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      DashboardScreen(
        appData: widget.appData,
        themeController: widget.themeController,
        onVerTrabajos: () => _irA(2),
        // Presupuestos ya no es una pestaña propia -- se abre encima,
        // no se cambia de pestaña (ver comentario de cabecera).
        onVerPresupuestos: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuotesListScreen(appData: widget.appData)),
        ),
        onVerFacturas: () => _irA(3),
      ),
      ClientsListScreen(appData: widget.appData),
      JobsListScreen(appData: widget.appData),
      InvoicesListScreen(appData: widget.appData),
      CalendarScreen(appData: widget.appData),
    ];

    return Scaffold(
      body: IndexedStack(index: _indice, children: pantallas),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryTint,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.inkFaint,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: _irA,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Clientes',
            ),
            NavigationDestination(
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build),
              label: 'Trabajos',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Facturas',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Agenda',
            ),
          ],
        ),
      ),
    );
  }
}
