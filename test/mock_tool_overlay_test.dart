import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mock_tool/flutter_mock_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'search metadata, filter, selection count and reset stay in sync',
    (tester) async {
      final controller = _controller();
      await _open(tester, controller);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Localized toggle'), findsNothing);
      expect(find.text('0 selected'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Reset',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'get profile');
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Success'));
      await tester.tap(find.text('Success'));
      await tester.pumpAndSettle();
      expect(controller.selectedScenarioId('profile'), 'success');
      expect(find.text('1 selected'), findsOneWidget);
      await _reveal(tester, find.byTooltip('Clear search'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected'));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
      await tester.tap(find.byTooltip('Reset'));
      await tester.pumpAndSettle();
      expect(controller.selectedCount, 0);
      expect(find.text('No matching endpoints'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'All'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'not-found');
      await tester.pumpAndSettle();
      expect(find.text('No matching endpoints'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Clear search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '503');
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clearing and external selections update endpoint summary', (
    tester,
  ) async {
    final controller = _controller();
    await _open(tester, controller);
    controller.selectScenario('profile', 'error');
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await _reveal(tester, find.text('Profile'));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Clear scenario'));
    await tester.tap(find.text('Clear scenario'));
    await tester.pumpAndSettle();
    expect(controller.selectedScenarioId('profile'), isNull);
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Real API'), findsWidgets);
  });

  testWidgets('one endpoint expands at a time and Escape closes', (
    tester,
  ) async {
    await _open(tester, _controller());
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Login success'), findsOneWidget);
    await _reveal(tester, find.text('Profile'));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Login success'), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('empty catalog and production remain usable', (tester) async {
    await _open(
      tester,
      MockToolController(
        config: MockToolConfig(groups: []),
        isDevelopment: true,
      ),
    );
    expect(find.text('No scenarios configured'), findsOneWidget);
    await tester.pumpWidget(_host(_controller(development: false)));
    expect(find.text('Host content'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets(
    'small viewport, keyboard, large text and semantics fit without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final controller = _controller()..selectScenario('profile', 'success');
      await _open(tester, controller, scale: 2, inset: 210);
      await tester.enterText(find.byType(TextField), 'profile');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Profile'));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Server error'));
      await tester.tap(find.text('Server error'));
      await tester.pumpAndSettle();
      expect(controller.selectedScenarioId('profile'), 'error');
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp('Profile, GET /profile')),
        findsOneWidget,
      );
      final scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scroll.physics, isA<ClampingScrollPhysics>());
      semantics.dispose();
    },
  );

  testWidgets('launcher drags, stays where dropped, and still opens', (
    tester,
  ) async {
    // Scenario: the launcher covers app controls at its default corner.
    // Setup: drag it up, rebuild, then drag it far outside the screen.
    // Assertions: the position persists across rebuilds, stays inside the
    // safe bounds, and a tap still opens the panel.
    // Expected result: a movable launcher that never leaves the screen.
    final controller = _controller();
    await tester.pumpWidget(_host(controller));
    final launcher = find.byKey(const ValueKey('flutter_mock_tool_fab'));
    final start = tester.getTopLeft(launcher);

    await tester.drag(launcher, const Offset(0, -300));
    await tester.pumpAndSettle();
    final moved = tester.getTopLeft(launcher);
    expect(moved.dy, lessThan(start.dy - 250));
    expect(moved.dx, start.dx);

    await tester.pumpWidget(_host(controller));
    expect(tester.getTopLeft(launcher), moved);

    await tester.drag(launcher, const Offset(5000, -5000));
    await tester.pumpAndSettle();
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final clamped = tester.getRect(launcher);
    expect(clamped.top, greaterThanOrEqualTo(12));
    expect(clamped.right, lessThanOrEqualTo(size.width - 12));

    await tester.tap(find.byTooltip('Scenario lab'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visual QA capture', (tester) async {
    if (Platform.environment['MOCK_TOOL_CAPTURE'] != '1') return;
    final font = Platform.environment['MOCK_TOOL_FONT'];
    if (font != null) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
        );
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '${File(font).parent.path}/MaterialIcons-Regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
      final monoPath = Platform.environment['MOCK_TOOL_MONO_FONT'];
      if (monoPath != null) {
        final mono = FontLoader('monospace')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(monoPath).readAsBytesSync()),
            ),
          );
        await mono.load();
      }
    }
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller()..selectScenario('profile', 'success');
    await _open(tester, controller);
    await _reveal(tester, find.text('Profile'));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await _capture(tester, 'panel-selected.png');
    await _reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'unknown-route');
    await tester.pumpAndSettle();
    await _capture(tester, 'panel-no-results.png');
    expect(tester.takeException(), isNull);
  });
}

final _captureKey = GlobalKey();
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      80,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 50,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('qa')..createSync();
    File(
      '${directory.path}/$name',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _open(
  WidgetTester tester,
  MockToolController controller, {
  double scale = 1,
  double inset = 0,
}) async {
  await tester.pumpWidget(_host(controller, scale: scale, inset: inset));
  await tester.tap(find.byTooltip('Scenario lab'));
  await tester.pumpAndSettle();
}

Widget _host(
  MockToolController controller, {
  double scale = 1,
  double inset = 0,
}) => MaterialApp(
  theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: inset),
      ),
      child: RepaintBoundary(
        key: _captureKey,
        child: MockToolOverlay(
          controller: controller,
          localizationsBuilder: (_) => _labels,
          child: const Scaffold(body: Text('Host content')),
        ),
      ),
    ),
  ),
);

const _labels = MockToolLocalizations(
  title: 'Scenario lab',
  enabledLabel: 'Localized toggle',
  happyPathLabel: 'Happy path',
  resetLabel: 'Reset',
  clearSelectionLabel: 'Clear scenario',
  closeLabel: 'Close',
  noScenariosLabel: 'No scenarios configured',
);

MockToolController _controller({bool development = true}) => MockToolController(
  isDevelopment: development,
  config: MockToolConfig(
    groups: [
      MockScenarioGroup(
        id: 'login',
        labelBuilder: (_) => 'Login',
        method: 'POST',
        path: '/auth/login',
        sectionBuilder: (_) => 'Account',
        scenarios: [
          MockScenario(
            id: 'success',
            labelBuilder: (_) => 'Login success',
            kind: MockScenarioKind.success,
          ),
        ],
      ),
      MockScenarioGroup(
        id: 'profile',
        labelBuilder: (_) => 'Profile',
        method: 'GET',
        path: '/profile',
        sectionBuilder: (_) => 'Account',
        scenarios: [
          MockScenario(
            id: 'success',
            labelBuilder: (_) => 'Success',
            responseSummaryBuilder: (_) => '200 · Profile data',
            kind: MockScenarioKind.success,
          ),
          MockScenario(
            id: 'error',
            labelBuilder: (_) => 'Server error',
            descriptionBuilder: (_) => 'Try again later',
            responseSummaryBuilder: (_) => '503 · Unavailable',
            kind: MockScenarioKind.error,
          ),
        ],
      ),
    ],
  ),
);
