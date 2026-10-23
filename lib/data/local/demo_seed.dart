// lib/data/local/demo_seed.dart
//
// Datos ficticios de arranque -- solo se escriben si el almacenamiento
// local está vacío (primer uso), nunca sobrescriben datos reales del
// usuario. IDs fijos a propósito para que las relaciones cliente/trabajo/
// presupuesto/cita sean estables entre arranques.
import '../models/cita.dart';
import '../models/cliente.dart';
import '../models/concepto_presupuesto.dart';
import '../models/factura.dart';
import '../models/pago_factura.dart';
import '../models/presupuesto.dart';
import '../models/trabajo.dart';

final demoClientes = [
  Cliente(
    id: 'demo-cliente-1',
    esDemo: true,
    nombre: 'Marta Iglesias',
    telefono: '612 345 678',
    email: 'marta.iglesias@email.com',
    direccion: 'Calle Mayor 14, Madrid',
    creadoEl: DateTime.now().subtract(const Duration(days: 40)),
  ),
  Cliente(
    id: 'demo-cliente-2',
    esDemo: true,
    nombre: 'Comunidad Jardines del Sur',
    telefono: '91 234 56 78',
    email: 'administracion@jardinesdelsur.es',
    direccion: 'Av. de la Constitución 22, Getafe',
    notas: 'Contactar siempre con el administrador, Javier.',
    creadoEl: DateTime.now().subtract(const Duration(days: 25)),
  ),
  Cliente(
    id: 'demo-cliente-3',
    esDemo: true,
    nombre: 'Rubén Castaño',
    telefono: '699 112 233',
    direccion: 'Plaza del Olivo 3, Alcorcón',
    creadoEl: DateTime.now().subtract(const Duration(days: 10)),
  ),
];

final demoTrabajos = [
  Trabajo(
    id: 'demo-trabajo-1',
    esDemo: true,
    clienteId: 'demo-cliente-1',
    titulo: 'Reparación de fuga en cocina',
    descripcion: 'Gotea bajo el fregadero, parece el sifón.',
    direccion: 'Calle Mayor 14, Madrid',
    estado: EstadoTrabajo.enCurso,
    creadoEl: DateTime.now().subtract(const Duration(days: 3)),
    fechaProgramada: DateTime.now().add(const Duration(days: 1)),
    presupuestoId: 'demo-presupuesto-1',
  ),
  Trabajo(
    id: 'demo-trabajo-2',
    esDemo: true,
    clienteId: 'demo-cliente-2',
    titulo: 'Revisión anual de instalación eléctrica',
    estado: EstadoTrabajo.pendiente,
    creadoEl: DateTime.now().subtract(const Duration(days: 1)),
    fechaProgramada: DateTime.now().add(const Duration(days: 4)),
  ),
  Trabajo(
    id: 'demo-trabajo-3',
    esDemo: true,
    clienteId: 'demo-cliente-3',
    titulo: 'Instalación de termo eléctrico',
    estado: EstadoTrabajo.finalizado,
    creadoEl: DateTime.now().subtract(const Duration(days: 15)),
  ),
];

final demoPresupuestos = [
  Presupuesto(
    id: 'demo-presupuesto-1',
    esDemo: true,
    clienteId: 'demo-cliente-1',
    trabajoId: 'demo-trabajo-1',
    titulo: 'Presupuesto reparación fuga cocina',
    estado: EstadoPresupuesto.enviado,
    creadoEl: DateTime.now().subtract(const Duration(days: 2)),
    conceptos: const [
      ConceptoPresupuesto(
        id: 'c1',
        descripcion: 'Mano de obra (2h)',
        cantidad: 2,
        precioUnitario: 35,
      ),
      ConceptoPresupuesto(
        id: 'c2',
        descripcion: 'Sifón nuevo',
        cantidad: 1,
        precioUnitario: 18.5,
      ),
    ],
  ),
  Presupuesto(
    id: 'demo-presupuesto-2',
    esDemo: true,
    clienteId: 'demo-cliente-3',
    trabajoId: 'demo-trabajo-3',
    titulo: 'Presupuesto instalación termo',
    estado: EstadoPresupuesto.aceptado,
    creadoEl: DateTime.now().subtract(const Duration(days: 16)),
    conceptos: const [
      ConceptoPresupuesto(
        id: 'c1',
        descripcion: 'Termo eléctrico 80L',
        cantidad: 1,
        precioUnitario: 210,
      ),
      ConceptoPresupuesto(
        id: 'c2',
        descripcion: 'Mano de obra instalación',
        cantidad: 3,
        precioUnitario: 32,
      ),
    ],
  ),
];

final demoFacturas = [
  Factura(
    id: 'demo-factura-1',
    esDemo: true,
    clienteId: 'demo-cliente-3',
    trabajoId: 'demo-trabajo-3',
    presupuestoId: 'demo-presupuesto-2',
    titulo: 'Factura instalación termo',
    estado: EstadoFactura.emitida,
    anio: DateTime.now().subtract(const Duration(days: 10)).year,
    numeroSecuencial: 1,
    creadaEl: DateTime.now().subtract(const Duration(days: 11)),
    fechaEmision: DateTime.now().subtract(const Duration(days: 10)),
    conceptos: const [
      ConceptoPresupuesto(
        id: 'c1',
        descripcion: 'Termo eléctrico 80L',
        cantidad: 1,
        precioUnitario: 210,
      ),
      ConceptoPresupuesto(
        id: 'c2',
        descripcion: 'Mano de obra instalación',
        cantidad: 3,
        precioUnitario: 32,
      ),
    ],
    pagos: [
      PagoFactura(
        id: 'demo-pago-1',
        fecha: DateTime.now().subtract(const Duration(days: 9)),
        importe: 370.26,
        metodo: MetodoPago.transferencia,
        nota: 'Pago único por transferencia',
        registradoEl: DateTime.now().subtract(const Duration(days: 9)),
      ),
    ],
  ),
  Factura(
    id: 'demo-factura-2',
    esDemo: true,
    clienteId: 'demo-cliente-2',
    titulo: 'Anticipo revisión eléctrica',
    estado: EstadoFactura.emitida,
    anio: DateTime.now().subtract(const Duration(days: 40)).year,
    numeroSecuencial: 2,
    creadaEl: DateTime.now().subtract(const Duration(days: 41)),
    fechaEmision: DateTime.now().subtract(const Duration(days: 40)),
    fechaVencimiento: DateTime.now().subtract(const Duration(days: 25)),
    conceptos: const [
      ConceptoPresupuesto(
        id: 'c1',
        descripcion: 'Anticipo revisión instalación eléctrica',
        cantidad: 1,
        precioUnitario: 150,
      ),
    ],
  ),
];

final demoCitas = [
  Cita(
    id: 'demo-cita-1',
    esDemo: true,
    titulo: 'Reparación fuga cocina',
    clienteId: 'demo-cliente-1',
    trabajoId: 'demo-trabajo-1',
    fechaHora: DateTime.now().add(const Duration(days: 1, hours: 2)),
    duracionMinutos: 90,
  ),
  Cita(
    id: 'demo-cita-2',
    esDemo: true,
    titulo: 'Revisión eléctrica comunidad',
    clienteId: 'demo-cliente-2',
    trabajoId: 'demo-trabajo-2',
    fechaHora: DateTime.now().add(const Duration(days: 4, hours: 1)),
    duracionMinutos: 120,
  ),
];
