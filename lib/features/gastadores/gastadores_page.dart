import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/dialogo.dart';
import '../../core/confirmar.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../data/gastador.dart';
import '../../state/store.dart';

/// Núcleo familiar: quem pode ser atribuído a uma compra.
class GastadoresPage extends StatelessWidget {
  const GastadoresPage({super.key});

  Future<void> _form(BuildContext context, [Gastador? g]) async {
    final store = context.read<Store>();
    final nome = TextEditingController(text: g?.nome);
    DateTime? aniversario = g?.aniversario;
    Sexo? sexo = g?.sexo;
    String? erro;

    final novo = await showDialog<Gastador>(
      context: context,
      builder: (ctx) => DonoDosCampos(
        campos: [nome],
        builder: (ctx, setD) => AlertDialog(
          title: Text(g == null ? 'Novo gastador' : 'Editar gastador'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: nome,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.cake),
                label: Text(aniversario == null
                    ? 'Aniversário'
                    : fmtData(aniversario!)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: aniversario ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now());
                  if (d != null) setD(() => aniversario = d);
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<Sexo>(
                emptySelectionAllowed: true,
                segments: [
                  for (final s in Sexo.values)
                    ButtonSegment(value: s, label: Text(s.rotulo)),
                ],
                selected: {if (sexo != null) sexo!},
                onSelectionChanged: (v) =>
                    setD(() => sexo = v.isEmpty ? null : v.first),
              ),
              if (erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(erro!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final n = nome.text.trim();
                final e = n.isEmpty
                    ? 'Informe o nome'
                    : aniversario == null
                        ? 'Informe o aniversário'
                        : sexo == null
                            ? 'Informe o sexo'
                            : null;
                if (e != null) return setD(() => erro = e);
                Navigator.pop(ctx, Gastador(n, aniversario!, sexo!, id: g?.id));
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (novo == null || !context.mounted) return;
    await avisandoFalha(
        context, () => store.salvarGastador(novo, edicao: g != null));
  }

  @override
  Widget build(BuildContext context) {
    final lista = context.watch<Store>().gastadores;
    return Scaffold(
      appBar: AppBar(title: const Text('Gastadores')),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _form(context), child: const Icon(Icons.add)),
      body: lista.isEmpty
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Cadastre as pessoas da família. Sem gastadores, '
                  'as compras ficam como "Todos".'),
            ))
          : ListView(children: [
              for (final g in lista)
                ListTile(
                  title: Text(g.nome),
                  subtitle:
                      Text('${fmtData(g.aniversario)} · ${g.sexo.rotulo}'),
                  onTap: () => _form(context, g),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Excluir',
                    onPressed: () async {
                      final store = context.read<Store>();
                      if (!await confirmar(
                          context,
                          'Excluir "${g.nome}"? As compras dele passam '
                          'para "Todos".')) {
                        return;
                      }
                      if (!context.mounted) return;
                      await avisandoFalha(
                          context, () => store.removerGastador(g.id),
                          falha: 'Não foi possível excluir');
                    },
                  ),
                ),
            ]),
    );
  }
}
