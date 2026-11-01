import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';
import 'package:compras/core/atualizacao.dart';
import 'package:compras/core/erros.dart';
import 'package:compras/features/config/atualizar_page.dart';

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
  test('lê build, APK e sha256 da resposta do GitHub', () {
    final r =
        Release.deJson(respostaGitHub('v1.0.0-7', digest: 'sha256:abc123'));
    expect(r.build, 7);
    expect(r.tag, 'v1.0.0-7');
    expect(r.apk, 'https://x/mesquevem-v1.0.0-7.apk');
    expect(r.sha256, 'abc123');
    expect(Release.deJson(respostaGitHub('v1.0.0-7')).sha256, isNull);
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

  Future<void> abrir(WidgetTester tester, VerificarVersao verificar,
          {BaixarEInstalar? baixar}) =>
      tester.pumpWidget(MaterialApp(
          home: AtualizarPage(
              verificar: verificar,
              baixar: baixar ?? (_) => const Stream.empty(),
              atual: 7,
              versao: '1.0.0-7')));

  testWidgets('já está na última versão', (tester) async {
    await abrir(tester, () async => const Release(7, 'v1.0.0-7', 'u'));
    expect(find.text('Versão instalada: v1.0.0-7'), findsOneWidget);
    await tester.tap(find.text('Verificar atualização'));
    await tester.pumpAndSettle();
    expect(find.text('Você já está na última versão 🎉'), findsOneWidget);
    expect(find.text('Atualizar agora'), findsNothing);
  });

  testWidgets('versão nova: baixa com progresso e abre o instalador',
      (tester) async {
    final eventos = StreamController<OtaEvent>();
    await abrir(tester, () async => const Release(8, 'v1.0.0-8', 'u'),
        baixar: (_) => eventos.stream);
    await tester.tap(find.text('Verificar atualização'));
    await tester.pumpAndSettle();
    expect(find.text('Nova versão v1.0.0-8 disponível!'), findsOneWidget);

    await tester.tap(find.text('Atualizar agora'));
    eventos.add(OtaEvent(OtaStatus.DOWNLOADING, '40'));
    await tester.pump();
    expect(find.text('Baixando… 40%'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        0.4);

    eventos.add(OtaEvent(OtaStatus.INSTALLING, null));
    await tester.pump();
    expect(find.textContaining('Abrindo o instalador'), findsOneWidget);
    await eventos.close();
  });

  testWidgets('permissão negada vira instrução', (tester) async {
    await abrir(tester, () async => const Release(8, 'v1.0.0-8', 'u'),
        baixar: (_) => Stream.value(
            OtaEvent(OtaStatus.PERMISSION_NOT_GRANTED_ERROR, null)));
    await tester.tap(find.text('Verificar atualização'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar agora'));
    await tester.pumpAndSettle();
    expect(find.textContaining('instalar apps desta fonte'), findsOneWidget);
  });

  testWidgets('erro de rede aparece sem prefixo técnico', (tester) async {
    await abrir(tester,
        () async => throw const ErroDoApp('sem conexão com a internet'));
    await tester.tap(find.text('Verificar atualização'));
    await tester.pumpAndSettle();
    expect(find.text('sem conexão com a internet'), findsOneWidget);
  });
}
