import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/widgets/adaptive_gutters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the gutter the builder receives.
class _Probe extends StatefulWidget {
  const _Probe({required this.gutter});

  final double gutter;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('probe'),
      onTap: () => setState(() => counter++),
      child: Text('gutter=${widget.gutter} counter=$counter'),
    );
  }
}

void _view(WidgetTester tester, double width, [double height = 800]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

double? _gutterOf(WidgetTester tester) {
  final text = tester.widget<Text>(find.textContaining('gutter=')).data!;
  return double.parse(RegExp(r'gutter=([0-9.]+)').firstMatch(text)!.group(1)!);
}

void main() {
  testWidgets('at 412 the builder receives the minimum gutter', (tester) async {
    _view(tester, 412);
    await tester.pumpWidget(
      _app(AdaptiveGutters(builder: (_, gutter) => _Probe(gutter: gutter))),
    );
    expect(_gutterOf(tester), 18);
  });

  testWidgets('at 1440 (no rail) it receives (1440 - 960) / 2', (tester) async {
    _view(tester, 1440);
    await tester.pumpWidget(
      _app(AdaptiveGutters(builder: (_, gutter) => _Probe(gutter: gutter))),
    );
    expect(_gutterOf(tester), 240);
  });

  testWidgets('with the shell rail beside it, centering uses the viewport', (
    tester,
  ) async {
    _view(tester, 1440);
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            const SizedBox(width: 83),
            Expanded(
              child: AdaptiveGutters(
                builder: (_, gutter) => _Probe(gutter: gutter),
              ),
            ),
          ],
        ),
      ),
    );
    expect(_gutterOf(tester), 198.5);
  });

  testWidgets('entry width: 18 in a 600 window with the rail, 140 at 800', (
    tester,
  ) async {
    _view(tester, 600);
    Widget entry() => AdaptiveGutters(
      maxWidth: AppLayoutTokens.entryContentMaxWidth,
      activatesAt: WindowSizeClass.medium,
      builder: (_, gutter) => _Probe(gutter: gutter),
    );
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            const SizedBox(width: 83),
            Expanded(child: entry()),
          ],
        ),
      ),
    );
    expect(_gutterOf(tester), 18);

    _view(tester, 599);
    await tester.pumpWidget(_app(entry()));
    expect(_gutterOf(tester), 18);

    _view(tester, 800);
    await tester.pumpWidget(_app(entry()));
    expect(_gutterOf(tester), 140);
  });

  testWidgets('resizing 1440 -> 412 -> 1440 keeps the child state', (
    tester,
  ) async {
    _view(tester, 1440);
    await tester.pumpWidget(
      _app(AdaptiveGutters(builder: (_, gutter) => _Probe(gutter: gutter))),
    );
    await tester.tap(find.byKey(const ValueKey('probe')));
    await tester.pump();
    expect(find.textContaining('counter=1'), findsOneWidget);

    _view(tester, 412);
    await tester.pump();
    expect(_gutterOf(tester), 18);
    expect(find.textContaining('counter=1'), findsOneWidget);

    _view(tester, 1440);
    await tester.pump();
    expect(_gutterOf(tester), 240);
    expect(find.textContaining('counter=1'), findsOneWidget);
  });

  testWidgets('adds no Center or ConstrainedBox of its own', (tester) async {
    _view(tester, 1440);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveGutters(builder: (_, gutter) => const SizedBox()),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(AdaptiveGutters),
        matching: find.byType(Center),
      ),
      findsNothing,
    );
    // The builder's SizedBox is the direct child: nothing wraps it.
    final adaptive = find.byType(AdaptiveGutters);
    final element = tester.element(adaptive);
    var childCount = 0;
    element.visitChildren((child) {
      childCount++;
      expect(child.widget, isA<LayoutBuilder>());
    });
    expect(childCount, 1);
  });
}
