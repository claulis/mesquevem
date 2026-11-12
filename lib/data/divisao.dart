import '../core/format.dart';
import 'compra.dart';

/// Máximo de parcelas aceito no formulário.
const maxParcelas = 48;

/// [cents] repartidos em [n] partes; os centavos que sobram vão, um a um, para
/// as primeiras (a soma das partes é sempre [cents]).
List<int> _partes(int cents, int n) =>
    [for (var i = 0; i < n; i++) cents ~/ n + (i < cents % n ? 1 : 0)];

/// Gastos de uma compra parcelada e/ou dividida: [parcelas] meses a partir de
/// [data] (dia limitado ao fim do mês) e, em cada parcela, um gasto por id de
/// [gastadores] (vazio = um gasto "Todos"). [total] é o valor da compra inteira.
List<Compra> gerarGastos({
  required DateTime data,
  required double total,
  int parcelas = 1,
  List<String> gastadores = const [],
  String descricao = '',
  String categoria = '',
  String evento = '',
}) {
  if (parcelas < 1 || parcelas > maxParcelas) {
    throw ArgumentError.value(parcelas, 'parcelas', 'entre 1 e $maxParcelas');
  }
  final donos = gastadores.isEmpty ? [''] : gastadores;
  final porParcela = _partes((total * 100).round(), parcelas);
  return [
    for (var p = 0; p < parcelas; p++)
      for (final (g, centavos) in _partes(porParcela[p], donos.length)
          .indexed
          .map((e) => (donos[e.$1], e.$2)))
        Compra(
          p == 0
              ? data
              : DateTime(data.year, data.month + p,
                  data.day.clamp(1, diasNoMes(data.year, data.month + p))),
          centavos / 100,
          descricao: parcelas == 1
              ? descricao
              : '${descricao.isEmpty ? '' : '$descricao '}(${p + 1}/$parcelas)',
          categoria: categoria,
          evento: evento,
          gastador: g,
        ),
  ];
}
