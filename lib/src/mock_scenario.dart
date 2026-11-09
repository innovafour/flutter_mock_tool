import 'package:flutter/widgets.dart';

enum MockScenarioKind { success, error, loading, other }

class MockScenario {
  const MockScenario({
    required this.id,
    required this.labelBuilder,
    this.descriptionBuilder,
    this.responseSummaryBuilder,
    this.kind = MockScenarioKind.other,
  });

  final String id;
  final String Function(BuildContext context) labelBuilder;
  final String Function(BuildContext context)? descriptionBuilder;
  final String Function(BuildContext context)? responseSummaryBuilder;
  final MockScenarioKind kind;
}

class MockScenarioGroup {
  MockScenarioGroup({
    required this.id,
    required this.labelBuilder,
    required List<MockScenario> scenarios,
    this.method,
    this.path,
    this.sectionBuilder,
    this.descriptionBuilder,
  }) : scenarios = List.unmodifiable(scenarios);

  final String id;
  final String Function(BuildContext context) labelBuilder;
  final List<MockScenario> scenarios;
  final String? method;
  final String? path;
  final String Function(BuildContext context)? sectionBuilder;
  final String Function(BuildContext context)? descriptionBuilder;
}

enum UnmatchedScenarioPolicy { delegateToReal, throwStateError }
