import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/confirmar.dart';
import '../../core/format.dart';
import '../../data/compra.dart';
import '../../state/store.dart';

class ComprasPage extends StatelessWidget {
  const ComprasPage({super.key});

  Widget _drop(String rotulo, List<String> opcoes, String? valor,
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

  Future<void> _form(BuildContext context, [Compra? c]) async {
    final store = context.read<Store>();
    final desc = TextEditingController(text: c?.descricao);
    final valor = TextEditingController(
        text: c?.valor.toStringAsFixed(2).replaceAll('.', ',') ?? '');
    var data = c?.data ?? DateTime.now();
    String? cat = (c?.categoria ?? '').isEmpty ? null : c!.categoria;
    String? ev = (c?.evento ?? '').isEmpty ? null : c!.evento;

    final ok = await showDialog<bool>(
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)')),
              const SizedBox(height: 8),
              _drop('Categoria da compra',
                  store.categorias(TipoCategoria.compra), cat,
                  (v) => setD(() => cat = v)),
              _drop('Evento', store.categorias(TipoCategoria.evento), ev,
                  (v) => setD(() => ev = v)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(fmtData(data)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: data,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100));
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
                final v = double.tryParse(valor.text.replaceAll(',', '.'));
                if (v == null || v <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    store.salvarCompra(Compra(
      data,
      double.parse(valor.text.replaceAll(',', '.')),
      id: c?.id,
      descricao: desc.text.trim(),
      categoria: cat ?? '',
      evento: ev ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final compras = context.watch<Store>().compras;
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _form(context), child: const Icon(Icons.add)),
      body: compras.isEmpty
          ? const Center(child: Text('Toque em + para adicionar'))
          : ListView(children: [
              for (final c in compras)
                ListTile(
                  title: Text(c.descricao.isNotEmpty
                      ? c.descricao
                      : (c.categoria.isNotEmpty ? c.categoria : 'Compra')),
                  subtitle: Text([fmtData(c.data), c.categoria, c.evento]
                      .where((t) => t.isNotEmpty)
                      .join(' · ')),
                  onTap: () => _form(context, c),
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
                        store.removerCompra(c.id);
                      },
                    ),
                  ]),
                ),
            ]),
    );
  }
}
