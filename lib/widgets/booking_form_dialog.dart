import 'package:flutter/material.dart';

class BookingFormDialog extends StatefulWidget {
  final String cancha;
  final String fecha;
  final String opensAt;
  final String closesAt;
  final String? initialStart;
  final String? initialEnd;
  final bool includePayment;
  const BookingFormDialog({
    super.key,
    required this.cancha,
    required this.fecha,
    required this.opensAt,
    required this.closesAt,
    this.initialStart,
    this.initialEnd,
    this.includePayment = true,
  });

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _start;
  late final TextEditingController _end;
  String _payment = 'cash';

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: widget.initialStart ?? widget.opensAt);
    _end = TextEditingController(text: widget.initialEnd ?? '');
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  String? _validateTime(String? value) {
    if (value == null || !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
      return 'Escribe la hora en formato HH:mm.';
    }
    if (value.compareTo(widget.opensAt) < 0 || value.compareTo(widget.closesAt) > 0) {
      return 'Horario disponible: ${widget.opensAt} a ${widget.closesAt}.';
    }
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (_end.text.compareTo(_start.text) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La hora de fin debe ser posterior a la de inicio.')),
      );
      return;
    }
    Navigator.pop(context, <String, String>{
      'start': _start.text,
      'end': _end.text,
      'payment_method': _payment,
    });
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFFFFFFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF111111), width: 1)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF111111), width: 1)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFC5000), width: 2)),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFFE7E3BF),
    insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Color(0xFF101010), width: 1.5)),
    child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 20),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 74,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Color(0xFF524AE9), Color(0xFFFC5000)])),
                child: Stack(children: [
                  const Positioned(left: 16, bottom: 10, child: Icon(Icons.sports_soccer, color: Colors.white, size: 28)),
                  Positioned(right: 14, top: 10, child: Text(widget.fecha, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ]),
              ),
              const SizedBox(height: 16),
              Text(
                widget.includePayment ? 'Reservar ${widget.cancha}' : 'Cambiar horario',
                style: const TextStyle(fontSize: 27, height: 1.05, fontWeight: FontWeight.w700, color: Color(0xFF302825)),
              ),
              const SizedBox(height: 22),
              Text('Fecha: ${widget.fecha}', style: const TextStyle(fontSize: 15, color: Color(0xFF514943))),
              Text('Horario disponible: ${widget.opensAt}–${widget.closesAt}', style: const TextStyle(fontSize: 13, color: Color(0xFF716963))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: const Color(0xFFE9E7FF), borderRadius: BorderRadius.circular(15)),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF524AE9)),
                  const SizedBox(width: 9),
                  Expanded(child: Text('Reserva en ${widget.opensAt} a ${widget.closesAt}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF393387)))),
                ]),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _start,
                keyboardType: TextInputType.datetime,
                decoration: _decoration('Hora de inicio (HH:mm)'),
                validator: _validateTime,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _end,
                keyboardType: TextInputType.datetime,
                decoration: _decoration('Hora de fin (HH:mm)'),
                validator: _validateTime,
              ),
              if (widget.includePayment) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _payment,
                  decoration: _decoration('Metodo de pago'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _payment = value);
                  },
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: const Text('Continuar')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
