var _seq = 0;
String novoId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

class Compra {
  // imutável: o Store compartilha compras entre o estado antigo e o novo
  final String id;
  final DateTime data;
  final double valor;
  final String descricao, categoria, evento;
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

  /// Cópia com campos trocados. Campo novo entra aqui e em [toJson]; o teste
  /// "copiaCom preserva todos os campos" acusa se faltar.
  Compra copiaCom({String? id, String? categoria, String? evento}) =>
      Compra(data, valor,
          id: id ?? this.id,
          descricao: descricao,
          categoria: categoria ?? this.categoria,
          evento: evento ?? this.evento);

  // campos novos: ler com default (`?? ''`) para aceitar dados antigos
  factory Compra.fromJson(Map<String, dynamic> j) {
    final valor = (j['valor'] as num).toDouble();
    // valores antigos (zero, negativo, enormes) são aceitos: recusar um só
    // tornaria todos os dados ilegíveis. Só não finito (1e400 num backup
    // editado vira Infinity) é recusado, porque o JSON não o grava.
    if (!valor.isFinite) {
      throw FormatException('valor inválido: $valor');
    }
    return Compra(
      DateTime.parse(j['data']),
      valor,
      id: j['id'],
      descricao: j['descricao'] ?? '',
      // nomes de categoria são comparados sem espaços nas pontas
      categoria: (j['categoria'] as String? ?? '').trim(),
      evento: (j['evento'] as String? ?? '').trim(),
    );
  }
}
