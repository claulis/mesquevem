import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/confirmar.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../state/privacidade.dart';
import '../../state/store.dart';
import '../compras/compras_page.dart';

/// Gastos que entram sozinhos todo mês, no dia configurado.
class RecorrentesPage extends StatelessWidget {
  const RecorrentesPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<Privacidade?>(); // redesenha ao ocultar/mostrar valores
    final store = context.watch<Store>();
    final lista = store.recorrentes;
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos recorrentes')),
      floatingActionButton: FloatingActionButton(
          tooltip: 'Novo gasto recorrente',
          onPressed: () => ComprasPage.formularioRecorrente(context),
          child: const Icon(Icons.add)),
      body: lista.isEmpty
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Toque em + para adicionar um gasto que se repete '
                  'todo mês (aluguel, escola, assinaturas). Ele é lançado '
                  'sozinho no dia escolhido.'),
            ))
          : ListView(children: [
              for (final r in lista)
                ListTile(
                  title: Text(r.descricao.isNotEmpty
                      ? r.descricao
                      : (r.categoria.isNotEmpty ? r.categoria : 'Gasto')),
                  subtitle: Text('Todo dia ${r.dia} · próximo '
                      '${fmtData(r.dataNoMes(r.proximo))}'),
                  onTap: () => ComprasPage.formularioRecorrente(context, r),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(fmtValor(r.valor)),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Excluir',
                      onPressed: () async {
                        if (!await confirmar(
                            context,
                            'Excluir este gasto recorrente? Os gastos já '
                            'lançados ficam.')) {
                          return;
                        }
                        if (!context.mounted) return;
                        await avisandoFalha(
                            context, () => store.removerRecorrente(r.id),
                            falha: 'Não foi possível excluir');
                      },
                    ),
                  ]),
                ),
            ]),
    );
  }
}
