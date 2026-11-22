import 'package:flutter/material.dart' show DateTimeRange;
import '../../data/compra.dart';

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'ê': 'e',
  'è': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o',
  'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u',
  'ü': 'u', 'ç': 'c', 'ñ': 'n',
};

/// Minúsculas e sem acento: "Pão" e "pao" se acham.
String semAcento(String s) =>
    s.toLowerCase().split('').map((c) => _acentos[c] ?? c).join();

/// Gastos que passam em todos os filtros preenchidos (E). [texto] procura na
/// descrição e na categoria; [periodo] inclui os dois dias; [gastador] ''
/// são os sem gastador ("Todos"); null/vazio não filtra.
List<Compra> filtrar(List<Compra> cs,
    {String texto = '',
    DateTimeRange? periodo,
    String? evento,
    String? gastador}) {
  final t = semAcento(texto.trim());
  final ini = periodo?.start, fim = periodo?.end;
  final depois = fim == null ? null : DateTime(fim.year, fim.month, fim.day + 1);
  return [
    for (final c in cs)
      if ((t.isEmpty ||
              semAcento(c.descricao).contains(t) ||
              semAcento(c.categoria).contains(t)) &&
          (ini == null ||
              !c.data.isBefore(DateTime(ini.year, ini.month, ini.day))) &&
          (depois == null || c.data.isBefore(depois)) &&
          (evento == null || c.evento == evento) &&
          (gastador == null || c.gastador == gastador))
        c
  ];
}
