part of '../../mock_tool_overlay.dart';

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.labels,
    required this.selectedCount,
    required this.onReset,
    required this.onClose,
  });

  final MockToolLocalizations labels;
  final int selectedCount;
  final VoidCallback? onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4, top: 4),
      child: Row(
        children: [
          Icon(Icons.bug_report_outlined, color: theme.colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(labels.title, style: theme.textTheme.titleMedium),
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    labels.selectedCountBuilder(selectedCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(
              minWidth: _touchTarget,
              minHeight: _touchTarget,
            ),
            tooltip: labels.resetLabel,
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            constraints: const BoxConstraints(
              minWidth: _touchTarget,
              minHeight: _touchTarget,
            ),
            tooltip: labels.closeLabel,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

MockScenario? _findScenario(MockScenarioGroup group, String? scenarioId) {
  if (scenarioId == null) return null;
  for (final scenario in group.scenarios) {
    if (scenario.id == scenarioId) return scenario;
  }
  return null;
}

IconData _kindIcon(MockScenarioKind kind) {
  switch (kind) {
    case MockScenarioKind.success:
      return Icons.check_circle_outline;
    case MockScenarioKind.error:
      return Icons.error_outline;
    case MockScenarioKind.loading:
      return Icons.hourglass_empty;
    case MockScenarioKind.other:
      return Icons.tune;
  }
}

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({
    required this.group,
    required this.controller,
    required this.labels,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final MockScenarioGroup group;
  final MockToolController controller;
  final MockToolLocalizations labels;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedId = controller.selectedScenarioId(group.id);
    final selectedScenario = _findScenario(group, selectedId);
    final isMocked = selectedId != null;
    final title = group.labelBuilder(context);
    final method = group.method;
    final path = group.path;
    final status = isMocked
        ? (selectedScenario?.labelBuilder(context) ?? selectedId)
        : labels.realApiLabel;
    final routeText = [
      if (method != null) method.toUpperCase(),
      ?path,
    ].join(' ');
    final semanticLabel = [
      title,
      if (routeText.isNotEmpty) routeText,
      status,
    ].join(', ');
    final description = group.descriptionBuilder?.call(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isMocked ? scheme.primary : scheme.outlineVariant,
          width: isMocked ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: semanticLabel,
            onTap: onToggle,
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _touchTarget),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (routeText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _RouteLine(method: method, path: path),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isMocked
                                        ? Icons.science
                                        : Icons.cloud_outlined,
                                    size: 16,
                                    color: isMocked
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      status,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: isMocked
                                                ? FontWeight.w600
                                                : null,
                                            color: isMocked
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: _touchTarget,
                        height: _touchTarget,
                        child: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            if (description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (isMocked)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => controller.clearScenario(group.id),
                    icon: const Icon(Icons.undo),
                    label: Text(labels.clearSelectionLabel),
                  ),
                ),
              ),
            RadioGroup<String>(
              groupValue: selectedId,
              onChanged: (value) {
                if (value != null) controller.selectScenario(group.id, value);
              },
              child: Column(
                children: [
                  for (final scenario in group.scenarios)
                    _ScenarioTile(scenario: scenario),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.method, required this.path});

  final String? method;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (method != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                method!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (path != null)
          Text(
            path!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({required this.scenario});

  final MockScenario scenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = scenario.descriptionBuilder?.call(context);
    final summary = scenario.responseSummaryBuilder?.call(context);

    return RadioListTile<String>(
      value: scenario.id,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      secondary: Icon(_kindIcon(scenario.kind)),
      title: Text(scenario.labelBuilder(context)),
      subtitle: description == null && summary == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null) Text(description),
                if (summary != null)
                  Padding(
                    padding: EdgeInsets.only(top: description == null ? 0 : 2),
                    child: Text(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PanelToolbar extends StatelessWidget {
  const _PanelToolbar({
    required this.labels,
    required this.controller,
    required this.searchController,
    required this.searchFocus,
    required this.query,
    required this.onQuery,
    required this.onClearSearch,
    required this.filter,
    required this.onFilter,
    required this.hasHappyPath,
    required this.resultCount,
    required this.showResults,
  });
  final MockToolLocalizations labels;
  final MockToolController controller;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String query;
  final ValueChanged<String> onQuery;
  final VoidCallback onClearSearch;
  final _EndpointFilter filter;
  final ValueChanged<_EndpointFilter> onFilter;
  final bool hasHappyPath;
  final int resultCount;
  final bool showResults;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _touchTarget),
            child: TextField(
              controller: searchController,
              focusNode: searchFocus,
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: labels.searchLabel,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: labels.clearSearchLabel,
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text(labels.allEndpointsLabel),
                selected: filter == _EndpointFilter.all,
                onSelected: (_) => onFilter(_EndpointFilter.all),
              ),
              ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text(labels.selectedOnlyLabel),
                selected: filter == _EndpointFilter.selected,
                onSelected: (_) => onFilter(_EndpointFilter.selected),
              ),
              if (hasHappyPath)
                Semantics(
                  selected: controller.isHappyPath,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => controller.setHappyPath(true),
                    icon: Icon(
                      controller.isHappyPath
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                    ),
                    label: Text(labels.happyPathLabel),
                  ),
                ),
            ],
          ),
          if (showResults)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  labels.resultsCountBuilder(resultCount),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              labels.behaviorHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
