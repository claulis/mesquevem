import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/confirmar.dart';
import '../../core/salvar.dart';
import '../../state/store.dart';

class CategoriaPage extends StatelessWidget {
  final TipoCategoria tipo;
  const CategoriaPage(this.tipo, {super.key});

  Future<void> _form(BuildContext context, [String? atual]) async {
    final store = context.read<Store>();
    final ctrl = TextEditingController(text: atual ?? '');
    String? erro;
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          void salvar() {
            final e = store.nomeInvalido(tipo, ctrl.text, atual: atual);
            if (e != null) return setD(() => erro = e);
            Navigator.pop(ctx, ctrl.text);
          }

          return AlertDialog(
            title: Text(atual == null ? 'Nova categoria' : 'Editar categoria'),
            content: TextField(
                controller: ctrl,
                autofocus: true,
                onSubmitted: (_) => salvar(),
                onChanged: (_) {
                  if (erro != null) setD(() => erro = null);
                },
                decoration:
                    InputDecoration(labelText: 'Nome', errorText: erro)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(onPressed: salvar, child: const Text('Salvar')),
            ],
          );
        },
      ),
    );
    if (nome == null || !context.mounted) return;
    await avisandoFalha(
        context,
        () => atual == null
            ? store.adicionarCategoria(tipo, nome)
            : store.renomearCategoria(tipo, atual, nome));
  }

  @override
  Widget build(BuildContext context) {
    final lista = context.watch<Store>().categorias(tipo);
    return Scaffold(
      appBar: AppBar(title: Text('Categorias de ${tipo.name}')),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _form(context), child: const Icon(Icons.add)),
      body: ListView(children: [
        for (final nome in lista)
          ListTile(
            title: Text(nome),
            onTap: () => _form(context, nome),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Excluir',
              onPressed: () async {
                final store = context.read<Store>();
                if (!await confirmar(context, 'Excluir "$nome"?')) return;
                if (!context.mounted) return;
                await avisandoFalha(
                    context, () => store.removerCategoria(tipo, nome),
                    falha: 'Não foi possível excluir');
              },
            ),
          ),
      ]),
    );
  }
}
