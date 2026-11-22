import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:compras/core/drive.dart';
import 'package:compras/core/erros.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/features/backup/backup_page.dart';
import 'package:compras/state/nuvem.dart';
import 'package:compras/state/store.dart';
import 'store_test.dart' show RepositorioMemoria;

class ContaFalsa implements Conta {
  String? conectada;
  @override
  Future<String?> retomar() async => conectada;
  @override
  Future<String> entrar() async => conectada = 'ana@exemplo.com';
  @override
  Future<String> token(bool novo) async => 't';
  @override
  Future<void> sair() async => conectada = null;
}

class DriveFalso extends Drive {
  final enviados = <String>[];
  String? noDrive;
  bool falhar = false;
  DriveFalso() : super((_) async => 't');

  @override
  Future<DateTime> enviar(String texto) async {
    if (falhar) throw const ErroDoApp('sem conexão com a internet');
    enviados.add(texto);
    noDrive = texto;
    return DateTime(2026, 11, 22, 9, 5);
  }

  @override
  Future<({String texto, DateTime quando})?> baixar() async =>
      noDrive == null ? null : (texto: noDrive!, quando: DateTime(2026, 11, 1));
}

void main() {
  late Store store;
  late ContaFalsa conta;
  late DriveFalso drive;
  late Nuvem nuvem;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = Store(RepositorioMemoria());
    await store.carregar();
    conta = ContaFalsa();
    drive = DriveFalso();
    nuvem = Nuvem(store, conta: conta, drive: drive);
  });

  test('deslogado nunca envia; logado envia só quando algo mudou', () async {
    await nuvem.aoPausar();
    expect(drive.enviados, isEmpty);

    await nuvem.entrar();
    expect(nuvem.email, 'ana@exemplo.com');
    await nuvem.aoPausar();
    expect(drive.enviados.length, 1);
    expect(nuvem.ultimoBackup, DateTime(2026, 11, 22, 9, 5));

    await nuvem.aoPausar();
    expect(drive.enviados.length, 1, reason: 'nada mudou');

    await store.salvarCompra(Compra(DateTime(2026, 11, 2), 10));
    await nuvem.aoPausar();
    expect(drive.enviados.length, 2);
    expect(drive.enviados.last, await store.exportar());
  });

  test('falha no automático fica em erro e tenta na próxima vez', () async {
    await nuvem.entrar();
    drive.falhar = true;
    await nuvem.aoPausar();
    expect(nuvem.erro, 'backup falhou (sem conexão com a internet)');
    drive.falhar = false;
    await nuvem.aoPausar();
    expect(drive.enviados.length, 1);
    expect(nuvem.erro, isNull);
  });

  test('retomar volta à conta e ao horário do último backup', () async {
    await nuvem.entrar();
    await nuvem.backupAgora();
    final outra = Nuvem(store, conta: conta, drive: drive);
    await outra.retomar();
    expect(outra.email, 'ana@exemplo.com');
    expect(outra.ultimoBackup, DateTime(2026, 11, 22, 9, 5));
  });

  test('baixar valida o backup: inválido não altera nada', () async {
    drive.noDrive = '{"isso": "não é backup"';
    await expectLater(nuvem.baixar(), throwsA(isA<ErroDoApp>()));
    drive.noDrive = null;
    expect(await nuvem.baixar(), isNull);
  });

  Future<void> abrir(WidgetTester tester, Nuvem n) =>
      tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: n),
      ], child: const MaterialApp(home: BackupPage())));

  testWidgets('sem GOOGLE_CLIENT_ID: avisa que não está configurado',
      (tester) async {
    await abrir(tester, Nuvem(store));
    expect(find.textContaining('não configurado nesta versão'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('entrar com app vazio oferece restaurar o backup do Drive',
      (tester) async {
    final antes = Store(RepositorioMemoria());
    await tester.runAsync(() async {
      await antes.carregar();
      await antes.salvarCompra(Compra(DateTime(2026, 10, 3), 25));
      drive.noDrive = await antes.exportar();
    });
    await abrir(tester, nuvem);
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pelos do backup do Drive'), findsOneWidget);
    await tester.tap(find.text('Restaurar'));
    // a gravação do Store roda fora do relógio falso do teste
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(store.compras.single.valor, 25);
    expect(find.text('Conta: ana@exemplo.com'), findsOneWidget);
    expect(find.text('Fazer backup agora'), findsOneWidget);

    await tester.tap(find.text('Fazer backup agora'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Último backup: 22/11/2026 09:05'), findsOneWidget);

    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsOneWidget);
  });
}
