import 'package:flutter/material.dart';

Future<bool> confirmar(BuildContext context, String msg,
        {String acao = 'Excluir'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(acao)),
        ],
      ),
    ) ??
    false;
