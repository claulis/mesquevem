import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/dialogo.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../state/store.dart';
import '../backup/backup_page.dart';
import '../categorias/categoria_page.dart';
import '../gastadores/gastadores_page.dart';
import 'atualizar_page.dart';
import 'fundo_page.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  /// Diálogo do teto de gastos. Usado também pelas boas-vindas da Home.
  static Future<void> definirTeto(BuildContext context) async {
    final store = context.read<Store>();
    final atual = store.teto;
    final inicial = atual == null ? '' : fmtNumero(atual);
    final ctrl = TextEditingController(text: inicial);
    String? erro;
    // (valor,) para distinguir "remover" (null) de cancelar (diálogo null)
    final r = await showDialog<(double?,)>(
      context: context,
      builder: (ctx) => DonoDosCampos(
          campos: [ctrl],
          builder: (ctx, setD) {
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
        // cadastros que mudam pouco (antes ocupavam a barra de baixo)
        ListTile(
          leading: const Icon(Icons.label),
          title: const Text('Categorias de compra'),
          onTap: () => abrir(const CategoriaPage(TipoCategoria.compra)),
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('Categorias de evento'),
          onTap: () => abrir(const CategoriaPage(TipoCategoria.evento)),
        ),
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('Gastadores'),
          onTap: () => abrir(const GastadoresPage()),
        ),
        const Divider(),
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
          onTap: () => definirTeto(context),
        ),
        ListTile(
          leading: const Icon(Icons.system_update),
          title: const Text('Atualizar'),
          onTap: () => abrir(const AtualizarPage()),
        ),
      ]),
    );
  }
}
