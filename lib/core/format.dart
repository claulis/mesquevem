String fmtData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String fmtValor(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
