import 'package:flutter/foundation.dart';
import 'package:flutter_mock_tool/src/mock_scenario.dart';
import 'package:flutter_mock_tool/src/mock_tool_config.dart';

class MockToolController extends ChangeNotifier {
  MockToolController({
    required this.config,
    required bool isDevelopment,
    @Deprecated('Selections control mocking; this value is ignored.')
    bool initiallyEnabled = false,
  }) : isDevelopment = isDevelopment && !kReleaseMode;

  final MockToolConfig config;
  final bool isDevelopment;
  bool _isHappyPath = false;
  final Map<String, String> _selectedScenarioIds = {};

  @Deprecated('Use isDevelopment and selectedScenarioId.')
  bool get isEnabled => isDevelopment;
  bool get isActive => isDevelopment;
  int get selectedCount => _selectedScenarioIds.length;

  bool isMocked(String groupId) =>
      isDevelopment && selectedScenarioId(groupId) != null;
  bool get isHappyPath => _isHappyPath;
  Map<String, String> get selectedScenarioIds =>
      Map<String, String>.unmodifiable(_selectedScenarioIds);

  String? selectedScenarioId(String groupId) {
    config.group(groupId);
    return _selectedScenarioIds[groupId];
  }

  @Deprecated('Select or clear endpoint scenarios instead.')
  void setEnabled(bool value) {}

  void selectScenario(String groupId, String scenarioId) {
    if (config.scenario(groupId, scenarioId) == null) {
      throw ArgumentError.value(
        scenarioId,
        'scenarioId',
        'Unknown scenario in group "$groupId"',
      );
    }
    if (_selectedScenarioIds[groupId] == scenarioId && !_isHappyPath) return;
    _selectedScenarioIds[groupId] = scenarioId;
    _isHappyPath = false;
    notifyListeners();
  }

  void clearScenario(String groupId) {
    config.group(groupId);
    if (_selectedScenarioIds.remove(groupId) == null) return;
    _isHappyPath = false;
    notifyListeners();
  }

  void setHappyPath(bool value) {
    if (!value) {
      if (!_isHappyPath && _selectedScenarioIds.isEmpty) return;
      _isHappyPath = false;
      _selectedScenarioIds.clear();
      notifyListeners();
      return;
    }

    final selections = <String, String>{};
    for (final group in config.groups) {
      MockScenario? happyScenario;
      for (final scenario in group.scenarios) {
        if (scenario.kind == MockScenarioKind.success) {
          happyScenario = scenario;
          break;
        }
      }
      if (happyScenario != null) {
        selections[group.id] = happyScenario.id;
      }
    }
    if (_isHappyPath && mapEquals(_selectedScenarioIds, selections)) return;
    _selectedScenarioIds
      ..clear()
      ..addAll(selections);
    _isHappyPath = true;
    notifyListeners();
  }

  void reset() {
    if (!_isHappyPath && _selectedScenarioIds.isEmpty) return;
    _selectedScenarioIds.clear();
    _isHappyPath = false;
    notifyListeners();
  }
}
