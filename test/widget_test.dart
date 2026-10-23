import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_canchas_jlinares/main.dart';

void main() {
  testWidgets('Solicita usuario y contraseña', (tester) async {
    await tester.pumpWidget(const AuthApp());
    expect(find.text('Inicio de sesión'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();
    expect(find.text('Escriba el usuario.'), findsOneWidget);
    expect(find.text('Escriba la contraseña.'), findsOneWidget);
    expect(find.text('Registrarse'), findsNothing);
  });
}
