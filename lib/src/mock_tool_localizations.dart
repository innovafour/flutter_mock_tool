import 'package:flutter/widgets.dart';

class MockToolLocalizations {
  const MockToolLocalizations({
    required this.title,
    this.enabledLabel = '',
    required this.happyPathLabel,
    required this.resetLabel,
    required this.clearSelectionLabel,
    required this.closeLabel,
    required this.noScenariosLabel,
    this.searchLabel = 'Search endpoints or scenarios',
    this.noResultsLabel = 'No matching endpoints',
    this.clearSearchLabel = 'Clear search',
    this.allEndpointsLabel = 'All',
    this.selectedOnlyLabel = 'Selected',
    this.realApiLabel = 'Real API',
    this.behaviorHint =
        'Select a scenario to mock an endpoint. Clear it to use the real API.',
    this.selectedCountBuilder = _selectedCount,
    this.resultsCountBuilder = _resultsCount,
  });

  final String title;
  final String enabledLabel;
  final String happyPathLabel;
  final String resetLabel;
  final String clearSelectionLabel;
  final String closeLabel;
  final String noScenariosLabel;
  final String searchLabel;
  final String noResultsLabel;
  final String clearSearchLabel;
  final String allEndpointsLabel;
  final String selectedOnlyLabel;
  final String realApiLabel;
  final String behaviorHint;
  final String Function(int count) selectedCountBuilder;
  final String Function(int count) resultsCountBuilder;

  static String _selectedCount(int count) => '$count selected';
  static String _resultsCount(int count) => '$count endpoints';
}

typedef MockToolLocalizationsBuilder =
    MockToolLocalizations Function(BuildContext context);
