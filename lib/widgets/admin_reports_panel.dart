import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/pdf_download.dart';

class AdminReportsPanel extends StatefulWidget {
  final AuthService auth;
  const AdminReportsPanel({super.key, required this.auth});

  @override
  State<AdminReportsPanel> createState() => _AdminReportsPanelState();
}

class _AdminReportsPanelState extends State<AdminReportsPanel> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  String? _loading;
  String? _error;

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool from) async {
    final initial = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
      _error = null;
    });
  }

  Future<void> _download(String type, String label) async {
    if (_from.isAfter(_to)) {
      setState(() => _error = 'La fecha inicial debe ser anterior a la fecha final.');
      return;
    }
    setState(() {
      _loading = type;
      _error = null;
    });
    try {
      final bytes = await widget.auth.downloadPdf(
        '/admin/reports/$type.pdf?from=${_date(_from)}&to=${_date(_to)}',
      );
      savePdf(bytes, '$type-${_date(_from)}-${_date(_to)}.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label descargado.')));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on UnsupportedError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const reports = [
      ('sales', 'Ventas por fecha', Icons.trending_up),
      ('reservations', 'Reservas', Icons.calendar_month),
      ('courts', 'Uso de canchas', Icons.sports_soccer),
      ('payments', 'Metodos de pago', Icons.payments_outlined),
      ('cash', 'Movimientos de caja', Icons.point_of_sale),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFADFF02), border: Border.all(color: Colors.black, width: 1.2), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.insert_chart_outlined_rounded)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Reportes PDF', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.5))),
            ]),
            const SizedBox(height: 8),
            const Text('Elige un periodo y descarga tus reportes.'),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _loading == null ? () => _pick(true) : null, icon: const Icon(Icons.event_outlined), label: Text('Desde ${_date(_from)}')),
              OutlinedButton.icon(onPressed: _loading == null ? () => _pick(false) : null, icon: const Icon(Icons.event_available_outlined), label: Text('Hasta ${_date(_to)}')),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 12),
            ...reports.map((report) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(report.$3, color: const Color(0xFFFC5000)),
              title: Text(report.$2),
              trailing: _loading == report.$1
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(tooltip: 'Descargar PDF', onPressed: _loading == null ? () => _download(report.$1, report.$2) : null, icon: const Icon(Icons.download_outlined)),
            )),
          ],
        ),
      ),
    );
  }
}
