import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/dialogo.dart';
import '../../core/confirmar.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../state/privacidade.dart';
import '../../state/store.dart';

class CategoriaPage extends StatelessWidget {
  final TipoCategoria tipo;
  const CategoriaPage(this.tipo, {super.key});

  Future<void> _form(BuildContext context, [String? atual]) async {
    final store = context.read<Store>();
    final ctrl = TextEditingController(text: atual ?? '');
    final limAtual = atual == null ? null : store.limite(tipo, atual);
    final limInicial = limAtual == null ? '' : fmtNumero(limAtual);
    final lim = TextEditingController(text: limInicial);
    String? erro, erroLim;
    final r = await showDialog<(String, double?)>(
      context: context,
      builder: (ctx) => DonoDosCampos(
        campos: [ctrl, lim],
        builder: (ctx, setD) {
          void salvar() {
            final e = store.nomeInvalido(tipo, ctrl.text, atual: atual);
            if (e != null) return setD(() => erro = e);
            double? limite;
            try {
              // vazio = sem limite; não mexido mantém o original
              limite = lim.text.trim().isEmpty
                  ? null
                  : lim.text == limInicial
                      ? limAtual
                      : lerValor(lim.text);
            } on FormatException catch (e) {
              return setD(() => erroLim = e.message);
            }
            Navigator.pop(ctx, (ctrl.text, limite));
          }

          return AlertDialog(
            title: Text(atual == null ? 'Nova categoria' : 'Editar categoria'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (_) {
                    if (erro != null) setD(() => erro = null);
                  },
                  decoration:
                      InputDecoration(labelText: 'Nome', errorText: erro)),
              TextField(
                  controller: lim,
                  onSubmitted: (_) => salvar(),
                  onChanged: (_) {
                    if (erroLim != null) setD(() => erroLim = null);
                  },
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Limite mensal (R\$)',
                      helperText: 'Vazio = sem limite',
                      errorText: erroLim)),
            ]),
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
    if (r == null || !context.mounted) return;
    final (nome, limite) = r;
    await avisandoFalha(
        context,
        () => atual == null
            ? store.adicionarCategoria(tipo, nome, limite: limite)
            : store.editarCategoria(tipo, atual, nome, limite));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Privacidade?>(); // redesenha ao ocultar/mostrar valores
    final store = context.watch<Store>();
    final lista = store.categorias(tipo);
    return Scaffold(
      appBar: AppBar(title: Text('Categorias de ${tipo.name}')),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _form(context), child: const Icon(Icons.add)),
      body: ListView(children: [
        for (final nome in lista)
          ListTile(
            title: Text(nome),
            subtitle: switch (store.limite(tipo, nome)) {
              null => null,
              final l => Text('Limite: ${fmtValor(l)}'),
            },
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
