import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../data/compra.dart';
import '../../state/privacidade.dart';
import '../../state/store.dart';
import 'compras_page.dart';

/// Gastos de uma categoria, evento ou gastador, aberta pelo toque na tela
/// principal: os do mês que estava na tela ou, no segundo botão, os de todos
/// os meses.
class GastosDaCategoriaPage extends StatefulWidget {
  final String nome;
  final DateTime mes;
  final bool Function(Compra) pertence;
  GastosDaCategoriaPage(TipoCategoria tipo, this.nome, this.mes, {super.key})
      : pertence = ((c) =>
            (tipo == TipoCategoria.compra ? c.categoria : c.evento) == nome);

  /// Gastos do gastador [id] ('' = "Todos", os sem gastador).
  GastosDaCategoriaPage.doGastador(String id, this.nome, this.mes,
      {super.key})
      : pertence = ((c) => c.gastador == id);

  @override
  State<GastosDaCategoriaPage> createState() => _GastosDaCategoriaPageState();
}

class _GastosDaCategoriaPageState extends State<GastosDaCategoriaPage> {
  var _todos = false;

  @override
  Widget build(BuildContext context) {
    context.watch<Privacidade?>();
    final store = context.watch<Store>();
    final m = widget.mes;
    final lista = store.compras
        .where((c) =>
            widget.pertence(c) &&
            (_todos || (c.data.year == m.year && c.data.month == m.month)))
        .toList();
    final total = lista.fold(0.0, (s, c) => s + c.valor);
    return Scaffold(
      appBar: AppBar(title: Text(widget.nome)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false, label: Text('${meses[m.month - 1]}/${m.year}')),
              const ButtonSegment(value: true, label: Text('Todos os meses')),
            ],
            selected: {_todos},
            onSelectionChanged: (v) => setState(() => _todos = v.first),
          ),
        ),
        Text('${lista.length} ${lista.length == 1 ? 'gasto' : 'gastos'} · '
            '${fmtValor(total)}',
            style: Theme.of(context).textTheme.titleMedium),
        const Divider(),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Nenhum gasto aqui'))
              : ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) =>
                      ComprasPage.linha(context, store, lista[i]),
                ),
        ),
      ]),
    );
  }
}
