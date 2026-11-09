// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter_mock_tool/flutter_mock_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockScenarioRouter', () {
    test(
      'clearing selection delegates once despite legacy throwing policy',
      () async {
        final controller = _controller(
          development: true,
          enabled: true,
          policy: UnmatchedScenarioPolicy.throwStateError,
        );
        controller.selectScenario('login', 'success');
        controller.clearScenario('login');
        var realCalls = 0;
        var mockCalls = 0;

        final result = await MockScenarioRouter(controller).run<String>(
          groupId: 'login',
          real: () async {
            realCalls++;
            return 'real result';
          },
          mock: (_) async {
            mockCalls++;
            return 'mock result';
          },
        );

        expect(result, 'real result');
        expect(realCalls, 1);
        expect(mockCalls, 0);
      },
    );

    test('enabled but unmatched delegates to real when configured', () async {
      final controller = _controller(
        development: true,
        enabled: true,
        policy: UnmatchedScenarioPolicy.delegateToReal,
      );
      var realCalls = 0;
      var mockCalls = 0;

      final result = await MockScenarioRouter(controller).run<String>(
        groupId: 'login',
        real: () async {
          realCalls++;
          return 'real';
        },
        mock: (_) async {
          mockCalls++;
          return 'mock';
        },
      );

      expect(result, 'real');
      expect(realCalls, 1);
      expect(mockCalls, 0);
    });

    test('propagates real delegate errors without mock fallback', () async {
      final controller = _controller(
        development: true,
        enabled: false,
        policy: UnmatchedScenarioPolicy.delegateToReal,
      );
      final failure = StateError('real service failed');
      var mockCalls = 0;

      await expectLater(
        MockScenarioRouter(controller).run<String>(
          groupId: 'login',
          real: () => Future<String>.error(failure),
          mock: (_) {
            mockCalls++;
            return 'mock';
          },
        ),
        throwsA(same(failure)),
      );
      expect(mockCalls, 0);
    });

    test(
      'production gate wins over enabled state and saved selection',
      () async {
        final controller = _controller(
          development: false,
          enabled: true,
          policy: UnmatchedScenarioPolicy.throwStateError,
        );
        controller.selectScenario('login', 'success');
        var realCalls = 0;
        var mockCalls = 0;

        final result = await MockScenarioRouter(controller).run<String>(
          groupId: 'login',
          real: () async {
            realCalls++;
            return 'real';
          },
          mock: (_) async {
            mockCalls++;
            return 'mock';
          },
        );

        expect(controller.isActive, isFalse);
        expect(controller.isActive, isFalse);
        expect(result, 'real');
        expect(realCalls, 1);
        expect(mockCalls, 0);
      },
    );

    test(
      'selected scenario uses mock delegate and propagates mock result',
      () async {
        final controller = _controller(
          development: true,
          enabled: true,
          policy: UnmatchedScenarioPolicy.throwStateError,
        );
        controller.selectScenario('login', 'success');
        var realCalls = 0;
        final result = await MockScenarioRouter(controller).run<String>(
          groupId: 'login',
          real: () async {
            realCalls++;
            return 'real';
          },
          mock: (scenarioId) async => 'mock:$scenarioId',
        );

        expect(result, 'mock:success');
        expect(realCalls, 0);
      },
    );
  });
}

MockToolController _controller({
  required bool development,
  required bool enabled,
  required UnmatchedScenarioPolicy policy,
}) {
  return MockToolController(
    config: MockToolConfig(
      unmatchedScenarioPolicy: policy,
      groups: [
        MockScenarioGroup(
          id: 'login',
          labelBuilder: (_) => 'Login',
          scenarios: [
            MockScenario(
              id: 'success',
              labelBuilder: (_) => 'Success',
              kind: MockScenarioKind.success,
            ),
            MockScenario(
              id: 'error',
              labelBuilder: (_) => 'Error',
              kind: MockScenarioKind.error,
            ),
          ],
        ),
      ],
    ),
    isDevelopment: development,
    initiallyEnabled: enabled,
  );
}
