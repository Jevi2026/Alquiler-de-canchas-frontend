import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../models/cancha.dart';

class CanchaFormDialog extends StatefulWidget {
  final Cancha? cancha;
  const CanchaFormDialog({super.key, this.cancha});

  @override
  State<CanchaFormDialog> createState() => _CanchaFormDialogState();
}

class _CanchaFormDialogState extends State<CanchaFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _surface;
  late final TextEditingController _price;
  late final TextEditingController _opens;
  late final TextEditingController _closes;
  Uint8List? _photoBytes;
  String? _photoName;

  @override
  void initState() {
    super.initState();
    final cancha = widget.cancha;
    _name = TextEditingController(text: cancha?.name ?? '');
    _surface = TextEditingController(text: cancha?.surface ?? '');
    _price = TextEditingController(text: cancha?.price.toString() ?? '500');
    _opens = TextEditingController(text: cancha?.opensAt ?? '06:00');
    _closes = TextEditingController(text: cancha?.closesAt ?? '22:00');
  }

  @override
  void dispose() {
    _name.dispose();
    _surface.dispose();
    _price.dispose();
    _opens.dispose();
    _closes.dispose();
    super.dispose();
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    bool numeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (!required && (value == null || value.isEmpty)) return null;
        if (value == null || value.trim().isEmpty) return 'Campo requerido.';
        if (numeric && double.tryParse(value) == null) {
          return 'Escribe un precio valido.';
        }
        if (label.contains('HH:mm') &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
          return 'Usa HH:mm.';
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      'surface': _surface.text.trim(),
      'price_per_hour': _price.text.trim(),
      'opens_at': _opens.text.trim(),
      'closes_at': _closes.text.trim(),
      if (_photoBytes != null) 'photo_bytes': _photoBytes,
      if (_photoName != null) 'photo_name': _photoName,
    });
  }

  Future<void> _pickPhoto() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final size = await file.length();
    if (size != null && size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen debe pesar 5 MB o menos.')),
        );
      }
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 900, maxHeight: MediaQuery.sizeOf(context).height * .9),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE7E3BF),
          border: Border.all(color: const Color(0xFF101010), width: 1.5),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFF5F28E), border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.sports_soccer)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.cancha == null ? 'Registrar cancha' : 'Editar cancha', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF302825))),
                  const SizedBox(height: 3),
                  const Text('Agrega la imagen y completa los datos de la cancha.', style: TextStyle(fontSize: 13, color: Color(0xFF716963))),
                ])),
              ]),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                return SingleChildScrollView(
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 5, child: _photoPicker(260)),
                          const SizedBox(width: 22),
                          Expanded(flex: 6, child: _fields()),
                        ])
                      : Column(children: [
                          _photoPicker(190),
                          const SizedBox(height: 18),
                          _fields(),
                        ]),
                );
              }),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                const SizedBox(width: 10),
                FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_rounded), label: const Text('Guardar cancha')),
              ]),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _photoPicker(double height) => InkWell(
    onTap: _pickPhoto,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E6E1),
        border: Border.all(color: const Color(0xFF171717), width: 1.2),
        borderRadius: BorderRadius.circular(20),
        image: _photoBytes != null
            ? DecorationImage(image: MemoryImage(_photoBytes!), fit: BoxFit.cover)
            : widget.cancha?.photoUrl != null
                ? DecorationImage(image: NetworkImage(widget.cancha!.photoUrl!), fit: BoxFit.cover)
                : null,
      ),
      child: _photoBytes == null && widget.cancha?.photoUrl == null
          ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_photo_alternate_outlined, size: 40, color: Color(0xFF524AE9)),
              SizedBox(height: 10),
              Text('Agregar foto de la cancha', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Toca aquí para buscar una imagen', style: TextStyle(fontSize: 12, color: Color(0xFF716963))),
            ])
          : Align(alignment: Alignment.bottomRight, child: Padding(
              padding: const EdgeInsets.all(10),
              child: FilledButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.edit_outlined), label: const Text('Cambiar foto')),
            )),
    ),
  );

  Widget _fields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _field(_name, 'Nombre'),
      const SizedBox(height: 12),
      _field(_surface, 'Superficie (opcional)', required: false),
      const SizedBox(height: 12),
      _field(_price, 'Precio por hora', numeric: true),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _field(_opens, 'Abre (HH:mm)')),
        const SizedBox(width: 12),
        Expanded(child: _field(_closes, 'Cierra (HH:mm)')),
      ]),
    ],
  );
}
