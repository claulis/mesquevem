import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/confirmar.dart';
import '../../state/store.dart';

class CategoriaPage extends StatelessWidget {
  final TipoCategoria tipo;
  const CategoriaPage(this.tipo, {super.key});

  Future<void> _form(BuildContext context, [String? atual]) async {
    final store = context.read<Store>();
    final ctrl = TextEditingController(text: atual ?? '');
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(atual == null ? 'Nova categoria' : 'Editar categoria'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (nome == null) return;
    if (atual == null) {
      store.adicionarCategoria(tipo, nome);
    } else {
      store.renomearCategoria(tipo, atual, nome);
    }
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
                store.removerCategoria(tipo, nome);
              },
            ),
          ),
      ]),
    );
  }
}
