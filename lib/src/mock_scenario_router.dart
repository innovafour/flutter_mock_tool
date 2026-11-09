import 'dart:async';

import 'package:flutter_mock_tool/src/mock_tool_controller.dart';

class MockScenarioRouter {
  const MockScenarioRouter(this.controller);

  final MockToolController controller;

  Future<T> run<T>({
    required String groupId,
    required FutureOr<T> Function() real,
    required FutureOr<T> Function(String scenarioId) mock,
  }) async {
    controller.config.group(groupId);
    if (!controller.isActive) return await real();

    final selectedScenarioId = controller.selectedScenarioId(groupId);
    if (selectedScenarioId == null) return await real();
    return await mock(selectedScenarioId);
  }
}
