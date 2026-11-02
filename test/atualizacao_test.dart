import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:compras/core/atualizacao.dart';
import 'package:compras/core/erros.dart';
import 'package:compras/features/config/atualizar_page.dart';
import 'package:compras/state/atualizador.dart';

Map<String, dynamic> respostaGitHub(String tag,
        {String nome = 'mesquevem-v1.0.0-7.apk', String? digest}) =>
    {
      'tag_name': tag,
      'assets': [
        {'name': 'notas.txt', 'browser_download_url': 'https://x/notas.txt'},
        {
          'name': nome,
          'browser_download_url': 'https://x/$nome',
          if (digest != null) 'digest': digest,
        },
      ],
    };

void main() {
  test('.gitignore da raiz bloqueia a chave de assinatura', () {
    final g = File('.gitignore').readAsLinesSync();
    for (final p in ['*.jks', '*.keystore', 'key.properties', '*.b64']) {
      expect(g, contains(p), reason: p);
    }
  });

  test('versão release declara INTERNET (sem ela: "sem conexão" com internet)',
      () {
    // o manifest de debug/profile tem a permissão; o release só tem o main
    final m =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android.permission.INTERNET'));
  });

  test('lê build, APK e sha256 da resposta do GitHub', () {
    final r =
        Release.deJson(respostaGitHub('v1.0.0-7', digest: 'sha256:abc123'));
    expect(r.build, 7);
    expect(r.tag, 'v1.0.0-7');
    expect(r.apk, 'https://x/mesquevem-v1.0.0-7.apk');
    expect(r.sha256, 'abc123');
    expect(Release.deJson(respostaGitHub('v1.0.0-7')).sha256, isNull);
  });

  test('resposta fora do formato vira mensagem legível, não TypeError', () {
    for (final j in <Map<String, dynamic>>[
      {'assets': []}, // sem tag_name
      {'tag_name': 'v1.0.0-9', 'assets': 'x'},
      {
        'tag_name': 'v1.0.0-9',
        'assets': [
          {'name': 5}
        ]
      },
    ]) {
      expect(
          () => Release.deJson(j),
          throwsA(isA<FormatException>().having(
              (e) => e.message, 'message', 'resposta inesperada do GitHub')),
          reason: '$j');
    }
  });

  test('tag que não serve como nome de arquivo é recusada', () {
    for (final t in ['v1/2-15', '../x-9', '..', 'v1.0.0-9 ', '']) {
      expect(() => Release.deJson(respostaGitHub(t)), throwsFormatException,
          reason: t);
    }
    expect(tagValida('v1.0.0-14'), isTrue);
  });

  test('release sem número na tag ou sem APK é recusada', () {
    expect(
        () => Release.deJson(respostaGitHub('v1.0.0')), throwsFormatException);
    expect(() => Release.deJson(respostaGitHub('v1.0.0-8', nome: 'a.zip')),
        throwsFormatException);
  });

  test('temNova: só com build maior e nunca em build de desenvolvimento', () {
    const r = Release(8, 'v1.0.0-8', 'u');
    expect(temNova(r, atual: 7), isTrue);
    expect(temNova(r, atual: 8), isFalse);
    expect(temNova(r, atual: 9), isFalse);
    expect(temNova(r, atual: 0), isFalse);
  });

  Future<void> abrir(WidgetTester tester, Future<Release> Function() v) =>
      tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => Atualizador(verificar: v, atual: 7, versao: '1.0.0-7'),
          child: const MaterialApp(home: AtualizarPage())));

  testWidgets('já está na última versão', (tester) async {
    await abrir(tester, () async => const Release(7, 'v1.0.0-7', 'u'));
    expect(find.text('Versão instalada: v1.0.0-7'), findsOneWidget);
    await tester.tap(find.text('Verificar atualização'));
    await tester.pumpAndSettle();
    expect(find.text('Você já está na última versão 🎉'), findsOneWidget);
    expect(find.text('Atualizar agora'), findsNothing);
  });

  testWidgets('versão nova mostra o botão Atualizar agora', (tester) async {
    await abrir(tester, () async => const Release(8, 'v1.0.0-8', 'u'));
    await tester.tap(find.text('Verificar atualização'));
    await tester.pumpAndSettle();
    expect(find.text('Nova versão v1.0.0-8 disponível!'), findsOneWidget);
    expect(find.text('Atualizar agora'), findsOneWidget);
  });

  testWidgets('erro de rede aparece sem prefixo técnico', (tester) async {
    await abrir(tester,
        () async => throw const ErroDoApp('sem conexão com a internet'));
    await tester.tap(find.text('Verificar atualização'));
    await tester.pumpAndSettle();
    expect(find.text('sem conexão com a internet'), findsOneWidget);
  });

  testWidgets('sair da tela e voltar mantém o progresso', (tester) async {
    final a = Atualizador(atual: 8, versao: '1.0.0-8')
      ..release = const Release(9, 'v1.0.0-9', 'u')
      ..fase = Fase.baixando
      ..recebidos = 1048576
      ..total = 2097152;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: a,
        child: MaterialApp(
            routes: {'/atualizar': (_) => const AtualizarPage()},
            home: const Scaffold())));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    for (var i = 0; i < 2; i++) {
      nav.pushNamed('/atualizar');
      await tester.pumpAndSettle();
      expect(find.text('Baixando… 50% (1,0 de 2,0 MB)'), findsOneWidget);
      nav.pop();
      await tester.pumpAndSettle();
    }
  });
}
