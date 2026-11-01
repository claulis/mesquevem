import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../state/store.dart';
import '../backup/backup_page.dart';
import 'fundo_page.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  Future<void> _teto(BuildContext context) async {
    final store = context.read<Store>();
    final atual = store.teto;
    final inicial = atual == null ? '' : fmtNumero(atual);
    final ctrl = TextEditingController(text: inicial);
    String? erro;
    // (valor,) para distinguir "remover" (null) de cancelar (diálogo null)
    final r = await showDialog<(double?,)>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        void salvar() {
          try {
            Navigator.pop(ctx, (
              ctrl.text.trim().isEmpty
                  ? null
                  : ctrl.text == inicial
                      ? atual
                      : lerValor(ctrl.text),
            ));
          } on FormatException catch (e) {
            setD(() => erro = e.message);
          }
        }

        return AlertDialog(
          title: const Text('Teto de gastos'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            onSubmitted: (_) => salvar(),
            onChanged: (_) {
              if (erro != null) setD(() => erro = null);
            },
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Total que pode gastar por mês (R\$)',
                helperText: 'Vazio = sem teto',
                errorText: erro),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(onPressed: salvar, child: const Text('Salvar')),
          ],
        );
      }),
    );
    if (r == null || !context.mounted) return;
    await avisandoFalha(context, () => store.definirTeto(r.$1));
  }

  @override
  Widget build(BuildContext context) {
    final teto = context.watch<Store>().teto;
    void abrir(Widget p) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => p));
    return Scaffold(
      appBar: AppBar(title: const Text('Config')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.import_export),
          title: const Text('Backup e compartilhamento'),
          onTap: () => abrir(const BackupPage()),
        ),
        ListTile(
          leading: const Icon(Icons.wallpaper),
          title: const Text('Personalização do fundo'),
          onTap: () => abrir(const FundoPage()),
        ),
        ListTile(
          leading: const Icon(Icons.savings),
          title: const Text('Teto de gastos'),
          subtitle: Text(teto == null ? 'Não cadastrado' : fmtValor(teto)),
          onTap: () => _teto(context),
        ),
      ]),
    );
  }
}
