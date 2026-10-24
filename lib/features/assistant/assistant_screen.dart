// lib/features/assistant/assistant_screen.dart
//
// Interfaz de asistente lista para una futura integración con un modelo
// real de IA -- hoy responde con sugerencias predefinidas y se identifica
// como demo en todo momento (encargo, sección 4.6): nunca debe parecer
// que hay una IA real respondiendo cuando no la hay.
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/local_engine_badge.dart';
import '../../data/app_data.dart';
import '../quotes/assisted_quote_screen.dart';

class _Mensaje {
  const _Mensaje({required this.texto, required this.deAsistente});
  final String texto;
  final bool deAsistente;
}

const _respuestasDemo = <String, String>{
  'presupuesto':
      'Para crear un presupuesto, ve a la pestaña Presupuestos y pulsa '
      '"Nuevo", o usa el botón "Crear presupuesto con ayuda" de aquí '
      'arriba: describe el trabajo y te propongo unos conceptos de '
      'partida que puedes editar antes de guardar. En ambos casos, el '
      'subtotal, el IVA y el total se calculan solos.',
  'cliente':
      'En la pestaña Clientes puedes dar de alta uno nuevo con el botón '
      '"+". Con el nombre basta -- el resto de datos son opcionales.',
  'cita':
      'Desde Agenda puedes programar una cita y vincularla a un cliente '
      'o a un trabajo concreto, para no tener que buscarlo luego.',
  'trabajo':
      'Los trabajos siempre cuelgan de un cliente. Puedes crear uno '
      'directamente desde la ficha del cliente o desde la pestaña '
      'Trabajos.',
};

const _sugerencias = [
  '¿Cómo creo un presupuesto?',
  '¿Cómo doy de alta un cliente?',
  '¿Cómo programo una cita?',
];

String _responderDemo(String pregunta) {
  final texto = pregunta.toLowerCase();
  for (final entry in _respuestasDemo.entries) {
    if (texto.contains(entry.key)) return entry.value;
  }
  return 'Esta es una respuesta de ejemplo -- el asistente todavía no '
      'tiene una IA real conectada. Prueba a preguntar por "presupuesto", '
      '"cliente", "trabajo" o "cita" para ver una respuesta guiada.';
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({required this.appData, super.key});

  final AppData appData;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Mensaje> _mensajes = [
    const _Mensaje(
      texto:
          'Hola, soy el asistente de Oficio AI. Todavía estoy en modo '
          'demostración -- no tengo una IA real conectada, pero puedo '
          'enseñarte cómo funciona la app.',
      deAsistente: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _enviar([String? textoSugerido]) {
    final texto = (textoSugerido ?? _controller.text).trim();
    if (texto.isEmpty) return;
    setState(() {
      _mensajes.add(_Mensaje(texto: texto, deAsistente: false));
      _mensajes.add(_Mensaje(texto: _responderDemo(texto), deAsistente: true));
    });
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpace.md,
              right: AppSpace.md,
              bottom: AppSpace.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const LocalEngineBadge(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssistedQuoteScreen(appData: widget.appData),
                  ),
                ),
                icon: const Icon(Icons.request_quote_outlined, size: 18),
                label: const Text('Crear presupuesto con ayuda'),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpace.md),
              itemCount: _mensajes.length,
              itemBuilder: (context, i) => _BurbujaMensaje(_mensajes[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              0,
              AppSpace.md,
              AppSpace.sm,
            ),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sugerencias.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(_sugerencias[i]),
                  onPressed: () => _enviar(_sugerencias[i]),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                0,
                AppSpace.md,
                AppSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu pregunta...',
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  IconButton.filled(
                    onPressed: () => _enviar(),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje(this.mensaje);
  final _Mensaje mensaje;

  @override
  Widget build(BuildContext context) {
    final deAsistente = mensaje.deAsistente;
    return Align(
      alignment: deAsistente ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 10,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          // En oscuro, `primary` está aclarado para texto/icono -- como
          // fondo con texto blanco encima se usa `primaryStrong`.
          color: deAsistente
              ? AppColors.surface
              : (AppColors.esOscuro ? AppColors.primaryStrong : AppColors.primary),
          border: deAsistente
              ? Border.all(color: AppColors.border)
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(deAsistente ? 2 : AppRadius.md),
            bottomRight: Radius.circular(deAsistente ? AppRadius.md : 2),
          ),
        ),
        child: Text(
          mensaje.texto,
          style: TextStyle(
            color: deAsistente ? AppColors.ink : Colors.white,
            fontSize: 13.5,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
