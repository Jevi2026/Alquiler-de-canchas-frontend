import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/cancha.dart';
import '../services/auth_service.dart';
import '../widgets/booking_form_dialog.dart';
import '../widgets/cancha_form_dialog.dart';
import '../widgets/admin_tools_panel.dart';
import '../widgets/admin_reports_panel.dart';

class HomeScreen extends StatefulWidget {
  final AuthService auth;
  const HomeScreen({super.key, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _error;
  List<Cancha> _canchas = [];
  List<Map<String, dynamic>> _reservations = [];
  DateTime _date = DateTime.now();

  bool get _admin => widget.auth.user?.role == 'admin';
  bool get _teller => widget.auth.user?.role == 'teller';
  bool get _cashier => _admin || _teller;
  String get _dateText =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.auth.request('GET', '/canchas?date=$_dateText'),
        if (!_cashier)
          widget.auth.request('GET', '/reservations', authenticated: true),
      ]);
      _canchas = (results.first['canchas'] as List)
          .map((item) => Cancha.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!_cashier) {
        _reservations = (results[1]['reservations'] as List)
            .cast<Map<String, dynamic>>();
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCancha([Cancha? cancha]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CanchaFormDialog(cancha: cancha),
    );
    if (data == null) return;
    try {
      final photo = data['photo_bytes'] as Uint8List?;
      final photoName = data['photo_name'] as String?;
      final fields = <String, String>{
        for (final entry in data.entries)
          if (entry.key != 'photo_bytes' && entry.key != 'photo_name')
            entry.key: entry.value.toString(),
      };
      await widget.auth.requestMultipart(
        cancha == null ? 'POST' : 'PUT',
        cancha == null ? '/canchas' : '/canchas/${cancha.id}',
        fields: fields,
        photo: photo,
        photoName: photoName,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _book(Cancha cancha) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => BookingFormDialog(
        cancha: cancha.name,
        fecha: _dateText,
        opensAt: cancha.opensAt,
        closesAt: cancha.closesAt,
      ),
    );
    if (values == null) return;

    final startsAt = '$_dateText ${values['start']}:00';
    final endsAt = '$_dateText ${values['end']}:00';
    if (values['end']!.compareTo(values['start']!) <= 0) {
      setState(() => _error = 'La hora final debe ser posterior a la inicial.');
      return;
    }

    try {
      final response = await widget.auth.request(
        'POST',
        '/reservations',
        authenticated: true,
        body: {
          'cancha_id': cancha.id,
          'starts_at': startsAt,
          'ends_at': endsAt,
          'payment_method': values['payment_method'],
        },
      );
      if (!mounted) return;
      final invoice = response['reservation'] as Map<String, dynamic>;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reserva y factura'),
          content: Text(
            'Factura: ${invoice['invoice_number']}\n'
            'Cancha: ${cancha.name}\n'
            'Total: L ${invoice['total']}\n'
            'Pago: ${invoice['payment_method']} (pendiente)\n'
            'Horario: ${invoice['starts_at']} - ${invoice['ends_at']}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _deleteCancha(Cancha cancha) async {
    try {
      await widget.auth.request(
        'DELETE',
        '/canchas/${cancha.id}',
        authenticated: true,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _cancelReservation(Map<String, dynamic> reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text('Deseas cancelar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.auth.request(
        'DELETE',
        '/reservations/${reservation['id']}',
        authenticated: true,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _reschedule(Map<String, dynamic> reservation) async {
    final currentStart = DateTime.parse(
      reservation['starts_at'].toString(),
    ).toLocal();
    final currentEnd = DateTime.parse(
      reservation['ends_at'].toString(),
    ).toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentStart.isBefore(DateTime.now())
          ? DateTime.now()
          : currentStart,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    final date =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final court = reservation['cancha'] as Map<String, dynamic>? ?? {};
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => BookingFormDialog(
        cancha: court['name']?.toString() ?? 'Cancha',
        fecha: date,
        opensAt: court['opens_at']?.toString().substring(0, 5) ?? '00:00',
        closesAt: court['closes_at']?.toString().substring(0, 5) ?? '23:59',
        initialStart:
            '${currentStart.hour.toString().padLeft(2, '0')}:${currentStart.minute.toString().padLeft(2, '0')}',
        initialEnd:
            '${currentEnd.hour.toString().padLeft(2, '0')}:${currentEnd.minute.toString().padLeft(2, '0')}',
        includePayment: false,
      ),
    );
    if (values == null) return;
    if (values['end']!.compareTo(values['start']!) <= 0) {
      setState(() => _error = 'La hora final debe ser posterior a la inicial.');
      return;
    }
    try {
      await widget.auth.request(
        'PATCH',
        '/reservations/${reservation['id']}/reschedule',
        authenticated: true,
        body: {
          'starts_at': '$date ${values['start']}:00',
          'ends_at': '$date ${values['end']}:00',
        },
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_soccer, color: Color(0xFFFC5000)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _admin
          ? FloatingActionButton.extended(
              onPressed: _saveCancha,
              icon: const Icon(Icons.add),
              label: const Text('Nueva cancha'),
            )
          : null,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user.name),
                accountEmail: Text('${user.email} - ${user.role}'),
                currentAccountPicture: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: ListTile(
                  tileColor: const Color(0xFFFFE5DF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFFC5000), width: 1.2),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFFC5000), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.logout_rounded, color: Colors.white, size: 21),
                  ),
                  title: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Salir de tu cuenta'),
                  trailing: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFFC5000)),
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.auth.logout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF070607),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF070607), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFADFF02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF070607), width: 1),
                    ),
                  child: Text(_admin ? 'PANEL DE ADMINISTRACION' : _teller ? 'PANEL DE CAJA' : 'TU SIGUIENTE PARTIDO',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF070607))),
                  ),
                  const SizedBox(height: 18),
                  Text(user.greeting.toUpperCase(),
                    style: const TextStyle(fontSize: 38, height: .98, letterSpacing: -.8, fontWeight: FontWeight.w900, color: Color(0xFFF7F6F2))),
                  const SizedBox(height: 10),
                  Text(_admin ? 'Administra tus canchas y mantente al dia con la caja.' : _teller ? 'Revisa reservas, confirma pagos y lleva las cuentas al dia.' : 'Encuentra cancha, arma el equipo y sal a jugar.',
                    style: const TextStyle(color: Color(0xFFE2E2DF), fontSize: 15, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_busy) const LinearProgressIndicator(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFFFFFFF), border: Border.all(color: const Color(0xFF101010), width: 1), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(_cashier ? Icons.point_of_sale_outlined : Icons.event_available_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_cashier ? 'Caja del día' : 'Fecha de juego', style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date.isBefore(DateTime.now())
                            ? DateTime.now()
                            : _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                        await _load();
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_dateText),
                  ),
                ],
              ),
            ),
            Text(
              _admin ? 'Administrar canchas' : _teller ? 'Canchas' : 'Canchas disponibles',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.5),
            ),
            if (_canchas.isEmpty && !_busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Todavia no hay canchas activas.'),
              ),
            _buildCourtGrid(),
            if (_cashier) ...[
              AdminToolsPanel(auth: widget.auth, date: _dateText, canManageUsers: _admin),
              const SizedBox(height: 20),
              AdminReportsPanel(auth: widget.auth),
            ],
            if (!_cashier) ...[
              const SizedBox(height: 16),
              Text(
                'Mis reservas y facturas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_reservations.isEmpty) const Text('Aun no tienes reservas.'),
              ..._reservations.map(
                (reservation) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(
                      '${(reservation['cancha'] as Map?)?['name'] ?? 'Cancha'} - '
                      'L ${reservation['total']}',
                    ),
                    subtitle: Text(
                      '${reservation['starts_at']}\n'
                      'Factura ${reservation['invoice_number']} - '
                      '${reservation['payment_method']} - '
                      'pago ${reservation['payment_status']}',
                    ),
                    trailing:
                        reservation['status'] == 'pending' &&
                            reservation['payment_status'] == 'pending'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Cambiar horario',
                                onPressed: () => _reschedule(reservation),
                                icon: const Icon(Icons.edit_calendar_outlined),
                              ),
                              IconButton(
                                tooltip: 'Cancelar reserva',
                                onPressed: () =>
                                    _cancelReservation(reservation),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
            ],
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtGrid() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 650
          ? 2
          : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _canchas.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: columns == 1 ? .88 : columns == 2 ? 1.02 : 1.34,
        ),
        itemBuilder: (context, index) => _courtCard(_canchas[index]),
      );
    },
  );

  Widget _courtCard(Cancha cancha) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF14532D), Color(0xFF65A30D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.sports_soccer, color: Colors.white70, size: 70),
              ),
              if (cancha.photoUrl != null)
                Image.network(
                  cancha.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.38, 1],
                  ),
                ),
              ),
              Positioned(
                left: 15,
                right: _admin ? 92 : 15,
                bottom: 14,
                child: Text(
                  cancha.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 25, height: 1, fontWeight: FontWeight.w900),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFADFF02), border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(11)),
                  child: const Text('CANCHA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
                ),
              ),
              if (_admin)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'Editar cancha', visualDensity: VisualDensity.compact, onPressed: () => _saveCancha(cancha), icon: const Icon(Icons.edit_outlined, size: 20)),
                      IconButton(tooltip: 'Eliminar cancha', visualDensity: VisualDensity.compact, onPressed: () => _deleteCancha(cancha), icon: const Icon(Icons.delete_outline, size: 20)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF5B5652)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${cancha.opensAt} – ${cancha.closesAt}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5B5652), fontSize: 13, fontWeight: FontWeight.w600))),
                  if (cancha.surface?.isNotEmpty == true) Text(cancha.surface!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5B5652), fontSize: 12)),
                ]),
                const Spacer(),
                Row(children: [
                  Expanded(child: Text('L ${cancha.price.toStringAsFixed(2)} / hora', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFC5000)))),
                  if (!_cashier) FilledButton.icon(onPressed: () => _book(cancha), icon: const Icon(Icons.arrow_forward, size: 17), label: const Text('Reservar')),
                ]),
                if (cancha.reservations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('${cancha.reservations.length} horario(s) reservado(s) hoy', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF5B5652))),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildFooter() => Container(
    margin: const EdgeInsets.only(top: 28, bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
    decoration: BoxDecoration(color: const Color(0xFF101010), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black, width: 1.5)),
    child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFFC5000), border: Border.all(color: Colors.white, width: 1.2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.sports_soccer, color: Colors.white, size: 27)),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Canchas deportivas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        SizedBox(height: 3),
        Text('Tu próximo partido comienza aquí.', style: TextStyle(color: Color(0xFFD6D3D1), fontSize: 13)),
      ])),
      Text('© ${DateTime.now().year}', style: const TextStyle(color: Color(0xFFF5F28E), fontWeight: FontWeight.w800)),
    ]),
  );
}
