import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService auth;
  const LoginScreen({super.key, required this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController(),
      _email = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false, _registering = false, _hidePassword = true;
  String? _error, _notice;
  String? _gender;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_registering) {
        await widget.auth.register(
          username: _username.text,
          name: _name.text,
          email: _email.text,
          gender: _gender!,
          password: _password.text,
          passwordConfirmation: _confirm.text,
        );
        setState(() {
          _registering = false;
          _notice = 'Cuenta creada. Ya puedes iniciar sesion.';
          _password.clear();
          _confirm.clear();
        });
      } else {
        await widget.auth.login(_username.text, _password.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_username, _password, _name, _email, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F2F2),
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.sports_soccer, color: Color(0xFFFC5000)),
        ],
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 168,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF524AE9), Color(0xFFFC5000)],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: CustomPaint(painter: _HalftonePainter()),
                            ),
                          ),
                          const Positioned(
                            left: 22,
                            bottom: 18,
                            child: Icon(Icons.sports_soccer, size: 44, color: Colors.white),
                          ),
                          const Positioned(
                            right: 20,
                            top: 20,
                            child: Icon(Icons.sports, size: 42, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _registering
                          ? 'Registrate como cliente'
                          : 'EL JUEGO\nEMPIEZA AQUI',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: .98,
                        letterSpacing: 1.2,
                        color: const Color(0xFF070607),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Reserva tu cancha. Reune a tu equipo.', style: TextStyle(color: Color(0xFF55534F))),
                    const SizedBox(height: 22),
                    if (_registering) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Escribe tu nombre.'
                            : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: 'Genero'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Mujer'),
                          ),
                          DropdownMenuItem(
                            value: 'Male',
                            child: Text('Hombre'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Otro / Prefiero no decirlo'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _gender = value),
                        validator: (value) =>
                            value == null ? 'Selecciona tu genero.' : null,
                      ),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Correo electronico',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Escribe un correo valido.'
                            : null,
                      ),
                    ],
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                      autofillHints: const [AutofillHints.username],
                      validator: (v) => v == null || v.trim().length < 3
                          ? 'Usa al menos 3 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || (_registering ? v.length < 8 : v.isEmpty)
                          ? (_registering
                                ? 'Usa al menos 8 caracteres.'
                                : 'Escribe tu contrasena.')
                          : null,
                    ),
                    if (_registering)
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contrasena',
                        ),
                        validator: (v) => v != _password.text
                            ? 'Las contrasenas no coinciden.'
                            : null,
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _notice!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Espera...'
                            : _registering
                            ? 'Crear cuenta'
                            : 'Ingresar',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _registering = !_registering;
                              _gender = null;
                              _error = null;
                              _notice = null;
                            }),
                      child: Text(
                        _registering
                            ? 'Ya tengo una cuenta - Iniciar sesion'
                            : 'No tienes cuenta? Crear cuenta',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HalftonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x66F5F28E);
    for (double y = 8; y < size.height; y += 12) {
      for (double x = 8; x < size.width; x += 12) {
        final fade = (x / size.width + y / size.height) / 2;
        if (fade < .68) canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
