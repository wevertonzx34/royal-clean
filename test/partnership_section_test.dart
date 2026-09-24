import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/preview/partnership_content_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/partnership_section_royal_clean.dart';

List<PublicPartnerRoyalClean> records(int count) => List.generate(
  count,
  (i) => PublicPartnerRoyalClean(
    id: '$i',
    title: 'Parceiro $i',
    description: 'Apresentação pública $i',
    imageUrl: 'https://example.test/$i.png',
  ),
);

Widget app({int partners = 0, int ads = 0, double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: PartnershipSectionRoyalClean(
          partners: Stream.value(records(partners)),
          ads: Stream.value(records(ads)),
        ),
      ),
    ),
  ),
);

void main() {
  test('Public projection rejects drafts and malformed images', () {
    final data = <String, dynamic>{
      'title': 'Parceiro',
      'description': 'Público',
      'imageUrl': 'https://example.test/logo.png',
      'published': true,
      'email': 'private@example.test',
    };
    expect(PublicPartnerRoyalClean.fromData('1', data)?.title, 'Parceiro');
    expect(
      PublicPartnerRoyalClean.fromData('1', {...data, 'published': false}),
      isNull,
    );
    expect(
      PublicPartnerRoyalClean.fromData('1', {
        ...data,
        'imageUrl': 'http://example.test/a',
      }),
      isNull,
    );
  });

  testWidgets(
    'Logos scroll and open public presentation; small screen supports large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(partners: 10, scale: 1.7));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Parceiro 0'));
      await tester.pumpAndSettle();
      expect(find.text('APRESENTAÇÃO PÚBLICA'), findsOneWidget);
      expect(find.text('Apresentação pública 0'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(-1500, 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Parceiro 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Wide layout shows four logo positions at most', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(partners: 10));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Parceiro 3').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Parceiro 4').hitTestable(), findsNothing);
  });

  testWidgets(
    'Advertisements cap at four; auto advance, pause and swipe work',
    (tester) async {
      await tester.pumpWidget(app(ads: 5));
      await tester.pumpAndSettle();
      expect(find.text('1 / 4'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.text('Apresentação pública 1'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Pausar rolagem automática'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pausar rolagem automática'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('2 / 4'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Empty collections show labeled demonstration advertisements', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text('Parceiro demo 1'),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('VITRINE DEMONSTRATIVA'), findsOneWidget);
    expect(find.text('Cuidado que aproxima.'), findsOneWidget);
    expect(find.byTooltip('Parceiro demo 1'), findsOneWidget);
    expect(find.byTooltip('Parceiro demo 2'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
