// lib/app_shell.dart
//
// Shell de navegación -- 5 destinos (dashboard, clients, jobs, invoices,
// calendar) en una única NavigationBar inferior -- el máximo recomendado
// para una barra de móvil (Material/iOS HIG); con 7 no cabían las
// etiquetas sin cortarse. Presupuestos y Asistente ya tenían (o ahora
// tienen) su propio acceso desde Inicio -- ver DashboardScreen -- así que
// no se pierde nada al sacarlos de la barra.
//
// PageView (no IndexedStack) para que las 5 pestañas también se puedan
// cambiar deslizando el dedo horizontalmente, no solo tocando la barra.
// PageView, a diferencia de IndexedStack, por defecto NO mantiene vivas
// las páginas que quedan fuera de su cacheExtent (0 por defecto, ver
// package:flutter/src/widgets/page_view.dart) -- así que cada pestaña se
// envuelve en _KeepAlivePage (AutomaticKeepAliveClientMixin) para
// conservar exactamente la misma garantía que tenía IndexedStack: no se
// pierde el scroll ni los filtros aplicados al cambiar de pestaña, deslizando
// o tocando la barra.
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
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Usado por la barra inferior -- anima hasta la página tocada. El
  // deslizamiento con el dedo no pasa por aquí: lo gestiona PageView
  // directamente y notifica el cambio a _onPageChanged.
  void _irA(int indice) => _pageController.animateToPage(
    indice,
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
  );

  void _onPageChanged(int indice) => setState(() => _indice = indice);

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
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [for (final p in pantallas) _KeepAlivePage(child: p)],
      ),
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

/// Fuerza a PageView a mantener viva una página aunque quede fuera de su
/// cacheExtent (0 por defecto) -- ver nota de cabecera de este archivo.
/// AutomaticKeepAlive es el mecanismo soportado por Flutter para esto
/// (el mismo que usa TabBarView internamente): basta con que
/// wantKeepAlive devuelva true y con llamar a super.build().
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
