import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:compras/core/dialogo.dart';

void main() {
  testWidgets('diálogo libera os campos depois de sair da tela',
      (tester) async {
    final campo = TextEditingController(text: 'x');
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final r = showDialog<String>(
      context: ctx,
      builder: (_) => DonoDosCampos(
        campos: [campo],
        builder: (c, _) => AlertDialog(
          content: TextField(controller: campo),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, campo.text),
                child: const Text('OK')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    expect(await r, 'x', reason: 'texto lido logo após fechar ainda vale');
    await tester.pumpAndSettle(); // animação de saída termina
    expect(() => campo.addListener(() {}), throwsFlutterError,
        reason: 'controlador liberado');
  });
}
