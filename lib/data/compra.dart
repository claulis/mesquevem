var _seq = 0;
String novoId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

class Compra {
  final String id;
  DateTime data;
  double valor;
  String descricao, categoria, evento;
  Compra(this.data, this.valor,
      {String? id, this.descricao = '', this.categoria = '', this.evento = ''})
      : id = id ?? novoId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data.toIso8601String(),
        'valor': valor,
        'descricao': descricao,
        'categoria': categoria,
        'evento': evento,
      };
  // campos novos: ler com default (`?? ''`) para aceitar dados antigos
  factory Compra.fromJson(Map<String, dynamic> j) => Compra(
        DateTime.parse(j['data']),
        (j['valor'] as num).toDouble(),
        id: j['id'],
        descricao: j['descricao'] ?? '',
        categoria: j['categoria'] ?? '',
        evento: j['evento'] ?? '',
      );
}
