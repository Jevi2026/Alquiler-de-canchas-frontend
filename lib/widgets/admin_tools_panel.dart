import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdminToolsPanel extends StatefulWidget {
  final AuthService auth;
  final String date;
  final bool canManageUsers;
  const AdminToolsPanel({super.key, required this.auth, required this.date, this.canManageUsers = false});

  @override
  State<AdminToolsPanel> createState() => _AdminToolsPanelState();
}

class _AdminToolsPanelState extends State<AdminToolsPanel> {
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _cash;
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminToolsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.auth.request(
          'GET',
          '/admin/cashier?date=${widget.date}',
          authenticated: true,
        ),
        widget.auth.request(
          'GET',
          '/admin/pending-reservations',
          authenticated: true,
        ),
      ]);
      _cash = results[0];
      _pending = (results[1]['reservations'] as List)
          .cast<Map<String, dynamic>>();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createStaff(String role) async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _StaffFormDialog(role: role),
    );
    if (data == null) return;
    try {
      await widget.auth.request(
        'POST',
        role == 'teller' ? '/tellers' : '/admins',
        body: data,
        authenticated: true,
      );
      if (mounted) _snack(role == 'teller' ? 'Cajero creado.' : 'Administrador creado.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _addExpense() async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ExpenseFormDialog(),
    );
    if (data == null) return;
    try {
      await widget.auth.request(
        'POST',
        '/admin/cashier/expenses',
        body: data,
        authenticated: true,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _pay(Map<String, dynamic> reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cobro'),
        content: Text(
          'Registrar L ${reservation['total']} en caja por la factura ${reservation['invoice_number']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cobrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.auth.request(
        'POST',
        '/admin/reservations/${reservation['id']}/payment',
        body: {'payment_method': reservation['payment_method']},
        authenticated: true,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cash = _cash;
    final byMethod =
        (cash?['by_method'] as Map?)?.cast<String, dynamic>() ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Caja del dia - ${widget.date}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_busy) const LinearProgressIndicator(),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            border: Border.all(color: const Color(0xFF101010), width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RESUMEN DE CAJA', style: TextStyle(color: Color(0xFFF5F28E), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _cashMetric('Ingresos', cash?['income'] ?? '0.00', const Color(0xFF02BBFF), Icons.south_west)),
              const SizedBox(width: 9),
              Expanded(child: _cashMetric('Gastos', cash?['expenses'] ?? '0.00', const Color(0xFFFA00FF), Icons.north_east)),
              const SizedBox(width: 9),
              Expanded(child: _cashMetric('Neto', cash?['net'] ?? '0.00', const Color(0xFFADFF02), Icons.account_balance_wallet_outlined)),
            ]),
            if (byMethod.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: byMethod.entries.map((entry) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(12)),
                child: Text('${_methodName(entry.key)} · L ${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              )).toList()),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF101010), width: 1.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFFC5000)),
              SizedBox(width: 7),
              Text('ACCIONES DE CAJA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: .8)),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Registrar gasto'),
                ),
                if (widget.canManageUsers) ...[
                  OutlinedButton.icon(
                    onPressed: () => _createStaff('admin'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Nuevo administrador'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _createStaff('teller'),
                    icon: const Icon(Icons.point_of_sale_outlined),
                    label: const Text('Crear cajero'),
                  ),
                ],
              ],
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(
          'Facturas pendientes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_pending.isEmpty) const Text('No hay cobros pendientes.'),
        ..._pending.map((reservation) {
          final client = reservation['user'] as Map?;
          final cancha = reservation['cancha'] as Map?;
          return Card(
            child: ListTile(
              title: Text(
                '${cancha?['name'] ?? 'Cancha'} - L ${reservation['total']}',
              ),
              subtitle: Text(
                '${client?['name'] ?? 'Cliente'}${client?['email'] == null ? '' : ' · ${client!['email']}'}\n${reservation['starts_at']} · ${reservation['invoice_number']} · ${_methodName(reservation['payment_method'] as String)}',
              ),
              trailing: FilledButton(
                onPressed: () => _pay(reservation),
                child: const Text('Cobrar'),
              ),
            ),
          );
        }),
        Text(
          'Movimientos del dia',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if ((cash?['transactions'] as List? ?? []).isEmpty)
          const Text('Aun no hay movimientos.'),
        ...((cash?['transactions'] as List? ?? []).cast<Map<String, dynamic>>()).map(
          (transaction) => ListTile(
            dense: true,
            leading: Icon(
              transaction['type'] == 'income'
                  ? Icons.south_west
                  : Icons.north_east,
            ),
            title: Text(
              '${transaction['type'] == 'income' ? 'Ingreso' : 'Gasto'} - L ${transaction['amount']}',
            ),
            subtitle: Text(
              '${transaction['description'] ?? ''} - ${_methodName(transaction['payment_method'] as String)}',
            ),
          ),
        ),
      ],
    );
  }

  String _methodName(String method) => switch (method) {
    'cash' => 'Efectivo',
    'card' => 'Tarjeta',
    'transfer' => 'Transferencia',
    _ => method,
  };

  Widget _cashMetric(String label, Object value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: color, border: Border.all(color: Colors.black, width: 1.2), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 17),
      const SizedBox(height: 9),
      Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
      const SizedBox(height: 3),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('L $value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
    ]),
  );
}

class _StaffFormDialog extends StatefulWidget {
  final String role;
  const _StaffFormDialog({required this.role});
  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _username = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  String? _gender;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _username,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo requerido.' : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.role == 'teller' ? 'Crear perfil de cajero' : 'Crear administrador'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Usuario'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Correo'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Correo no valido.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Genero'),
              items: const [
                DropdownMenuItem(value: 'Female', child: Text('Mujer')),
                DropdownMenuItem(value: 'Male', child: Text('Hombre')),
                DropdownMenuItem(value: 'Other', child: Text('Otro')),
              ],
              onChanged: (value) => setState(() => _gender = value),
              validator: (value) => value == null ? 'Selecciona genero.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contrasena (8 caracteres minimo)',
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Usa al menos 8 caracteres.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contrasena',
              ),
              validator: (value) => value != _password.text
                  ? 'Las contrasenas no coinciden.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, String>{
            'name': _name.text.trim(),
            'username': _username.text.trim(),
            'email': _email.text.trim(),
            'gender': _gender!,
            'password': _password.text,
            'password_confirmation': _confirmation.text,
          });
        },
        child: const Text('Crear'),
      ),
    ],
  );
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog();
  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _description = TextEditingController();
  String _method = 'cash';

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Registrar gasto de caja'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto'),
            validator: (value) =>
                value == null || (double.tryParse(value) ?? 0) <= 0
                ? 'Ingresa un monto valido.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Descripcion'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Campo requerido.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Metodo'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
              DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
              DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _method = value);
            },
          ),
        ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, String>{
            'amount': _amount.text,
            'description': _description.text.trim(),
            'payment_method': _method,
          });
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
