import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/dialogo.dart';
import '../../core/confirmar.dart';
import '../../core/format.dart';
import '../../core/salvar.dart';
import '../../data/compra.dart';
import '../../data/divisao.dart';
import '../../data/recorrente.dart';
import '../../state/privacidade.dart';
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

  /// Formulário de gasto recorrente (novo, ou edição de [r]): o mesmo do
  /// gasto, com o dia do mês no lugar da data e sem parcelas.
  static Future<void> formularioRecorrente(BuildContext context,
          [Recorrente? r]) =>
      formulario(context, null, true, r);

  /// Formulário de nova compra (ou de edição, com [c]). Usado também pelo
  /// botão "+ Gasto" da tela principal e, com [recorrente], pelos gastos
  /// recorrentes ([formularioRecorrente]).
  static Future<void> formulario(BuildContext context,
      [Compra? c, bool recorrente = false, Recorrente? r]) async {
    final store = context.read<Store>();
    final desc = TextEditingController(text: c?.descricao ?? r?.descricao);
    final original = c?.valor ?? r?.valor;
    final valorInicial = original == null ? '' : fmtNumero(original);
    final valor = TextEditingController(text: valorInicial);
    var data = c?.data ?? DateTime.now();
    final diaCampo = TextEditingController(text: r == null ? '' : '${r.dia}');
    String? erroDia;
    var dia = 1;
    final categoria = c?.categoria ?? r?.categoria ?? '';
    final evento = c?.evento ?? r?.evento ?? '';
    String? cat = categoria.isEmpty ? null : categoria;
    String? ev = evento.isEmpty ? null : evento;
    // '' = Todos; gastador já excluído também volta a Todos
    var gast =
        store.gastadores.any((g) => g.id == c?.gastador) ? c!.gastador : '';
    String? erroValor, erroParcelas;
    // só em gasto novo: parcelas e divisão entre os gastadores marcados
    final parcelasCampo = TextEditingController(text: '1');
    final divididos = <String>{...?r?.gastadores};
    var parcelas = 1;

    // o diálogo devolve o valor já validado, ou null se cancelado
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => DonoDosCampos(
        campos: [desc, valor, parcelasCampo, diaCampo],
        builder: (ctx, setD) => AlertDialog(
          title: Text(recorrente
              ? (r == null ? 'Novo gasto recorrente' : 'Editar gasto recorrente')
              : (c == null ? 'Novo gasto' : 'Editar gasto')),
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
                  'Categoria do gasto',
                  store.categorias(TipoCategoria.compra),
                  cat,
                  (v) => setD(() => cat = v)),
              _drop('Evento', store.categorias(TipoCategoria.evento), ev,
                  (v) => setD(() => ev = v)),
              if (c == null) ...[
                if (!recorrente)
                TextField(
                    controller: parcelasCampo,
                    onChanged: (_) {
                      if (erroParcelas != null) {
                        setD(() => erroParcelas = null);
                      }
                    },
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Parcelas (1 a $maxParcelas)',
                        helperText: 'O valor é o total; vira uma parcela por mês',
                        errorText: erroParcelas)),
                if (store.gastadores.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Gastadores (marque "Todos" ou mais de um para dividir)')),
                  if (store.gastadores.length > 1)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      tristate: true,
                      title: const Text('Todos'),
                      // parte marcada: traço
                      value: divididos.isEmpty
                          ? false
                          : store.gastadores
                                  .every((g) => divididos.contains(g.id))
                              ? true
                              : null,
                      onChanged: (_) => setD(() {
                        final todos = store.gastadores
                            .every((g) => divididos.contains(g.id));
                        divididos.clear();
                        if (!todos) {
                          divididos.addAll(store.gastadores.map((g) => g.id));
                        }
                      }),
                    ),
                  for (final g in store.gastadores)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(g.nome),
                      value: divididos.contains(g.id),
                      onChanged: (x) => setD(() =>
                          x == true ? divididos.add(g.id) : divididos.remove(g.id)),
                    ),
                ],
              ] else
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
              if (recorrente)
                TextField(
                    controller: diaCampo,
                    onChanged: (_) {
                      if (erroDia != null) setD(() => erroDia = null);
                    },
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Dia do mês (1 a 31)',
                        helperText: 'Lançado todo mês nesse dia',
                        errorText: erroDia))
              else
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
                  if (recorrente) {
                    final n = int.tryParse(diaCampo.text.trim());
                    if (n == null || n < 1 || n > 31) {
                      setD(() => erroDia = 'Informe de 1 a 31');
                      return;
                    }
                    dia = n;
                  } else if (c == null) {
                    final n = int.tryParse(parcelasCampo.text.trim());
                    if (n == null || n < 1 || n > maxParcelas) {
                      setD(() => erroParcelas = 'Informe de 1 a $maxParcelas');
                      return;
                    }
                    parcelas = n;
                  }
                  // valor não mexido: mantém o original, mesmo que hoje
                  // lerValor o recusasse (dados antigos, mais de 2 casas)
                  Navigator.pop(
                      ctx,
                      original != null && valor.text == valorInicial
                          ? original
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
    // lido já: o diálogo libera o campo quando termina de sair da tela
    final descricao = desc.text.trim();
    if (c == null) {
      // ids na ordem da lista de gastadores; excluído no meio do caminho = fora
      final ids = [
        for (final g in store.gastadores)
          if (divididos.contains(g.id)) g.id
      ];
      if (recorrente) {
        await avisandoFalha(
            context,
            () => store.salvarRecorrente(
                Recorrente(dia, v,
                    r?.proximo ?? Recorrente.inicio(dia, DateTime.now()),
                    id: r?.id,
                    descricao: descricao,
                    categoria: cat ?? '',
                    evento: ev ?? '',
                    gastadores: ids),
                edicao: r != null));
        return;
      }
      await avisandoFalha(
          context,
          () => store.salvarCompras(gerarGastos(
              data: data,
              total: v,
              parcelas: parcelas,
              gastadores: ids,
              descricao: descricao,
              categoria: cat ?? '',
              evento: ev ?? '')));
      return;
    }
    await avisandoFalha(
        context,
        () => store.salvarCompra(
            Compra(
              data,
              v,
              id: c.id,
              descricao: descricao,
              categoria: cat ?? '',
              evento: ev ?? '',
              gastador: gast,
            ),
            edicao: true));
  }

  /// Linha de um gasto: toque edita, lixeira exclui. Usada também na lista
  /// de gastos de uma categoria.
  static Widget linha(BuildContext context, Store store, Compra c) => ListTile(
        title: Text(c.descricao.isNotEmpty
            ? c.descricao
            : (c.categoria.isNotEmpty ? c.categoria : 'Gasto')),
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
              if (!await confirmar(context, 'Excluir este gasto?')) {
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

  @override
  Widget build(BuildContext context) {
    context.watch<Privacidade?>(); // redesenha ao ocultar/mostrar valores
    final store = context.watch<Store>();
    final compras = store.compras;
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      floatingActionButton: FloatingActionButton(
          heroTag: null, // há outro botão flutuante na aba Início
          onPressed: () => formulario(context),
          child: const Icon(Icons.add)),
      body: compras.isEmpty
          ? const Center(child: Text('Toque em + para adicionar'))
          // builder: só monta as linhas visíveis (lista pode ficar longa)
          : ListView.builder(
              itemCount: compras.length,
              itemBuilder: (context, i) => linha(context, store, compras[i]),
            ),
    );
  }
}
