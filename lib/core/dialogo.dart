import 'package:flutter/material.dart';

/// Mesmo uso do [StatefulBuilder], mas dono de [campos]: libera os
/// controladores quando o diálogo sai da tela. Liberar logo depois do
/// `showDialog` quebraria o campo, ainda desenhado na animação de saída; aqui
/// o dispose vem depois dela. Ler `.text` logo após o `await showDialog` é
/// seguro: o diálogo ainda não saiu da árvore.
class DonoDosCampos extends StatefulWidget {
  final List<TextEditingController> campos;
  final StatefulWidgetBuilder builder;
  const DonoDosCampos({required this.campos, required this.builder, super.key});

  @override
  State<DonoDosCampos> createState() => _DonoDosCamposState();
}

class _DonoDosCamposState extends State<DonoDosCampos> {
  @override
  void dispose() {
    for (final c in widget.campos) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
}
