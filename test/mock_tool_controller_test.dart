// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter_mock_tool/flutter_mock_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockToolController', () {
    test('happy path chooses the first success in catalog order', () {
      final controller = _controller();

      controller.setHappyPath(true);

      expect(controller.isHappyPath, isTrue);
      expect(controller.selectedScenarioIds, {'login': 'first-success'});
    });

    test('happy path leaves groups without success scenarios unselected', () {
      final controller = _controller(includeEmpty: true);

      controller.setHappyPath(true);

      expect(controller.selectedScenarioIds['empty'], isNull);
      expect(controller.selectedScenarioIds['profile'], isNull);
    });

    test('manual scenario change exits happy path deterministically', () {
      final controller = _controller();
      controller.setHappyPath(true);

      controller.selectScenario('login', 'failure');

      expect(controller.isHappyPath, isFalse);
      expect(controller.selectedScenarioId('login'), 'failure');
      expect(controller.selectedScenarioId('profile'), isNull);
    });

    test(
      'legacy global gate cannot disable selected endpoints; reset clears',
      () {
        final controller = _controller();
        controller.setHappyPath(true);
        controller.setEnabled(false);

        expect(controller.isActive, isTrue);
        expect(controller.selectedScenarioId('login'), 'first-success');

        controller.setEnabled(true);
        controller.reset();

        expect(controller.isActive, isTrue);
        expect(controller.selectedScenarioIds, isEmpty);
        expect(controller.isHappyPath, isFalse);
      },
    );

    test('selection validation and listener state stay consistent', () {
      final controller = _controller();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.selectScenario('login', 'failure');
      controller.selectScenario('login', 'failure');
      expect(notifications, 1);
      expect(controller.selectedCount, 1);
      expect(controller.isMocked('login'), isTrue);
      expect(
        () => controller.selectScenario('login', 'missing'),
        throwsArgumentError,
      );
      expect(controller.selectedScenarioId('login'), 'failure');
      expect(
        () => controller.selectedScenarioIds.clear(),
        throwsUnsupportedError,
      );
      controller.clearScenario('login');
      controller.clearScenario('login');
      expect(notifications, 2);
      expect(controller.selectedCount, 0);
      expect(controller.isMocked('login'), isFalse);
    });

    test('production controller cannot be enabled', () {
      final controller = _controller(development: false);

      controller.setEnabled(true);

      expect(controller.isActive, isFalse);
      expect(controller.isActive, isFalse);
    });
  });
}

MockToolController _controller({
  bool development = true,
  bool includeEmpty = false,
}) {
  return MockToolController(
    config: MockToolConfig(
      unmatchedScenarioPolicy: UnmatchedScenarioPolicy.throwStateError,
      groups: [
        MockScenarioGroup(
          id: 'login',
          labelBuilder: (_) => 'Login',
          scenarios: [
            MockScenario(
              id: 'first-success',
              labelBuilder: (_) => 'First success',
              kind: MockScenarioKind.success,
            ),
            MockScenario(
              id: 'second-success',
              labelBuilder: (_) => 'Second success',
              kind: MockScenarioKind.success,
            ),
            MockScenario(
              id: 'failure',
              labelBuilder: (_) => 'Failure',
              kind: MockScenarioKind.error,
            ),
          ],
        ),
        if (includeEmpty)
          MockScenarioGroup(
            id: 'empty',
            labelBuilder: (_) => 'Empty',
            scenarios: [],
          ),
        MockScenarioGroup(
          id: 'profile',
          labelBuilder: (_) => 'Profile',
          scenarios: [
            MockScenario(
              id: 'first-profile',
              labelBuilder: (_) => 'Profile data',
            ),
            MockScenario(
              id: 'second-profile',
              labelBuilder: (_) => 'Alternate profile',
            ),
          ],
        ),
      ],
    ),
    isDevelopment: development,
  );
}
