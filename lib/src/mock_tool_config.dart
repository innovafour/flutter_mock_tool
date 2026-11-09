import 'package:flutter_mock_tool/src/mock_scenario.dart';

class MockToolConfig {
  MockToolConfig({
    required List<MockScenarioGroup> groups,
    @Deprecated('Unselected endpoints always delegate to real.')
    this.unmatchedScenarioPolicy = UnmatchedScenarioPolicy.delegateToReal,
  }) : groups = List.unmodifiable(groups) {
    _validateCatalog();
  }

  final List<MockScenarioGroup> groups;
  final UnmatchedScenarioPolicy unmatchedScenarioPolicy;

  MockScenarioGroup group(String id) {
    return groups.firstWhere(
      (group) => group.id == id,
      orElse: () => throw ArgumentError.value(id, 'groupId', 'Unknown group'),
    );
  }

  MockScenario? scenario(String groupId, String scenarioId) {
    final targetGroup = group(groupId);
    for (final scenario in targetGroup.scenarios) {
      if (scenario.id == scenarioId) return scenario;
    }
    return null;
  }

  void _validateCatalog() {
    final groupIds = <String>{};
    for (final group in groups) {
      if (group.id.isEmpty || !groupIds.add(group.id)) {
        throw ArgumentError('Scenario group IDs must be non-empty and unique.');
      }
      final scenarioIds = <String>{};
      for (final scenario in group.scenarios) {
        if (scenario.id.isEmpty || !scenarioIds.add(scenario.id)) {
          throw ArgumentError(
            'Scenario IDs must be non-empty and unique within group '
            '"${group.id}".',
          );
        }
      }
    }
  }
}
