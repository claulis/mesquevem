import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/confirmar.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../data/compra.dart';
import '../../state/store.dart';

class ComprasPage extends StatelessWidget {
  const ComprasPage({super.key});

  static Widget _drop(String rotulo, List<String> opcoes, String? valor,
      ValueChanged<String?> onChanged) {
    // inclui o valor atual mesmo que a categoria já tenha sido excluída
    final itens = {...opcoes, if (valor != null) valor};
    return DropdownButton<String>(
      isExpanded: true,
      hint: Text(rotulo),
      value: valor,
      items: [
        for (final o in itens) DropdownMenuItem(value: o, child: Text(o))
      ],
      onChanged: onChanged,
    );
  }

  /// Formulário de nova compra (ou de edição, com [c]). Usado também pelo
  /// botão "+ Compra" da tela principal.
  static Future<void> formulario(BuildContext context, [Compra? c]) async {
    final store = context.read<Store>();
    final desc = TextEditingController(text: c?.descricao);
    final valorInicial = c == null ? '' : fmtNumero(c.valor);
    final valor = TextEditingController(text: valorInicial);
    var data = c?.data ?? DateTime.now();
    String? cat = (c?.categoria ?? '').isEmpty ? null : c!.categoria;
    String? ev = (c?.evento ?? '').isEmpty ? null : c!.evento;
    // '' = Todos; gastador já excluído também volta a Todos
    var gast =
        store.gastadores.any((g) => g.id == c?.gastador) ? c!.gastador : '';
    String? erroValor;

    // o diálogo devolve o valor já validado, ou null se cancelado
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(c == null ? 'Nova compra' : 'Editar compra'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Descrição')),
              TextField(
                  controller: valor,
                  onChanged: (_) {
                    if (erroValor != null) setD(() => erroValor = null);
                  },
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Valor (R\$)', errorText: erroValor)),
              const SizedBox(height: 8),
              _drop(
                  'Categoria da compra',
                  store.categorias(TipoCategoria.compra),
                  cat,
                  (v) => setD(() => cat = v)),
              _drop('Evento', store.categorias(TipoCategoria.evento), ev,
                  (v) => setD(() => ev = v)),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: gast,
                decoration: const InputDecoration(labelText: 'Gastador'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todos')),
                  for (final g in store.gastadores)
                    DropdownMenuItem(value: g.id, child: Text(g.nome)),
                ],
                onChanged: (v) => setD(() => gast = v ?? ''),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(fmtData(data)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: data,
                      // a data atual (ex.: de um backup) tem de caber no intervalo
                      firstDate:
                          data.isBefore(DateTime(2000)) ? data : DateTime(2000),
                      lastDate:
                          data.isAfter(DateTime(2100)) ? data : DateTime(2100));
                  if (d != null) setD(() => data = d);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                try {
                  // valor não mexido: mantém o original, mesmo que hoje
                  // lerValor o recusasse (dados antigos, mais de 2 casas)
                  Navigator.pop(
                      ctx,
                      c != null && valor.text == valorInicial
                          ? c.valor
                          : lerValor(valor.text));
                } on FormatException catch (e) {
                  setD(() => erroValor = e.message);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (v == null || !context.mounted) return;
    await avisandoFalha(
        context,
        () => store.salvarCompra(
            Compra(
              data,
              v,
              id: c?.id,
              descricao: desc.text.trim(),
              categoria: cat ?? '',
              evento: ev ?? '',
              gastador: gast,
            ),
            edicao: c != null));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final compras = store.compras;
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      floatingActionButton: FloatingActionButton(
          heroTag: null, // há outro botão flutuante na aba Início
          onPressed: () => formulario(context),
          child: const Icon(Icons.add)),
      body: compras.isEmpty
          ? const Center(child: Text('Toque em + para adicionar'))
          // builder: só monta as linhas visíveis (lista pode ficar longa)
          : ListView.builder(
              itemCount: compras.length,
              itemBuilder: (context, i) {
                final c = compras[i];
                return ListTile(
                  title: Text(c.descricao.isNotEmpty
                      ? c.descricao
                      : (c.categoria.isNotEmpty ? c.categoria : 'Compra')),
                  subtitle: Text([
                    fmtData(c.data),
                    c.categoria,
                    c.evento,
                    if (c.gastador.isNotEmpty) store.nomeGastador(c.gastador),
                  ].where((t) => t.isNotEmpty).join(' · ')),
                  onTap: () => formulario(context, c),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(fmtValor(c.valor)),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Excluir',
                      onPressed: () async {
                        final store = context.read<Store>();
                        if (!await confirmar(context, 'Excluir esta compra?')) {
                          return;
                        }
                        if (!context.mounted) return;
                        await avisandoFalha(
                            context, () => store.removerCompra(c.id),
                            falha: 'Não foi possível excluir');
                      },
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
