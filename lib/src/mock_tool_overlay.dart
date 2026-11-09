import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mock_tool/src/mock_scenario.dart';
import 'package:flutter_mock_tool/src/mock_tool_controller.dart';
import 'package:flutter_mock_tool/src/mock_tool_localizations.dart';

part 'presenter/sections/panel.dart';

const double _panelMaxWidth = 640;
const double _panelMaxHeight = 720;
const double _touchTarget = 48;
const double _fabMargin = 12;

class MockToolOverlay extends StatefulWidget {
  const MockToolOverlay({
    required this.child,
    required this.controller,
    required this.localizationsBuilder,
    this.fabAlignment = Alignment.bottomLeft,
    super.key,
  });

  final Widget child;
  final MockToolController controller;
  final MockToolLocalizationsBuilder localizationsBuilder;
  final Alignment fabAlignment;

  @override
  State<MockToolOverlay> createState() => _MockToolOverlayState();
}

class _MockToolOverlayState extends State<MockToolOverlay>
    with SingleTickerProviderStateMixin {
  bool _isPanelOpen = false;
  Offset? _fabOffset;
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void didUpdateWidget(covariant MockToolOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      if (!widget.controller.isDevelopment) {
        _isPanelOpen = false;
        _animationController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!widget.controller.isDevelopment && _isPanelOpen) {
      _isPanelOpen = false;
      _animationController.value = 0;
    }
    if (mounted) setState(() {});
  }

  void _openPanel() {
    setState(() => _isPanelOpen = true);
    _animationController.forward();
  }

  void _moveFab(Offset delta, Rect bounds) {
    final current = _fabOffset ?? _initialFabOffset(bounds);
    setState(() => _fabOffset = _clampFab(current + delta, bounds));
  }

  Offset _initialFabOffset(Rect bounds) {
    final free = Size(
      math.max(0, bounds.width - _touchTarget),
      math.max(0, bounds.height - _touchTarget),
    );
    return bounds.topLeft + widget.fabAlignment.alongSize(free);
  }

  Offset _clampFab(Offset offset, Rect bounds) => Offset(
    offset.dx.clamp(
      bounds.left,
      math.max(bounds.left, bounds.right - _touchTarget),
    ),
    offset.dy.clamp(
      bounds.top,
      math.max(bounds.top, bounds.bottom - _touchTarget),
    ),
  );

  void _closePanel() {
    _animationController.reverse().then((_) {
      if (mounted) setState(() => _isPanelOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isDevelopment) return widget.child;
    final labels = widget.localizationsBuilder(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _isPanelOpen,
          child: ExcludeSemantics(excluding: _isPanelOpen, child: widget.child),
        ),
        if (_isPanelOpen) ...[
          Positioned.fill(
            child: Semantics(
              button: true,
              label: labels.closeLabel,
              child: GestureDetector(
                onTap: _closePanel,
                child: FadeTransition(
                  opacity: _animationController,
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.54),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _slideAnimation,
                child: _MockToolPanel(
                  controller: widget.controller,
                  labels: labels,
                  onClose: _closePanel,
                ),
              ),
            ),
          ),
        ] else
          LayoutBuilder(
            builder: (context, constraints) {
              final padding = MediaQuery.paddingOf(context);
              final bounds = Rect.fromLTRB(
                math.max(padding.left, _fabMargin),
                math.max(padding.top, _fabMargin),
                constraints.maxWidth - math.max(padding.right, _fabMargin),
                constraints.maxHeight - math.max(padding.bottom, _fabMargin),
              );
              final offset = _clampFab(
                _fabOffset ?? _initialFabOffset(bounds),
                bounds,
              );
              return Stack(
                children: [
                  Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: GestureDetector(
                      key: const ValueKey<String>('flutter_mock_tool_fab'),
                      onPanUpdate: (details) => _moveFab(details.delta, bounds),
                      child: _MockToolFab(
                        onPressed: _openPanel,
                        label: labels.title,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _MockToolFab extends StatelessWidget {
  const _MockToolFab({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: _touchTarget,
        height: _touchTarget,
        child: FloatingActionButton.small(
          heroTag: 'flutter_mock_tool_fab',
          tooltip: null,
          onPressed: onPressed,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          foregroundColor: Theme.of(context).colorScheme.onTertiary,
          child: const Icon(Icons.bug_report_outlined),
        ),
      ),
    );
  }
}

enum _EndpointFilter { all, selected }

class _MockToolPanel extends StatefulWidget {
  const _MockToolPanel({
    required this.controller,
    required this.labels,
    required this.onClose,
  });

  final MockToolController controller;
  final MockToolLocalizations labels;
  final VoidCallback onClose;

  @override
  State<_MockToolPanel> createState() => _MockToolPanelState();
}

class _MockToolPanelState extends State<_MockToolPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  _EndpointFilter _filter = _EndpointFilter.all;
  String _query = '';
  String? _expandedGroupId;

  @override
  void initState() {
    super.initState();
    final isTouchPlatform =
        (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.fuchsia);
    if (!isTouchPlatform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusSearch() => _searchFocus.requestFocus();

  void _setQuery(String value) => setState(() => _query = value);

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    _searchFocus.requestFocus();
  }

  void _setFilter(_EndpointFilter value) => setState(() => _filter = value);

  void _toggleExpanded(String groupId) {
    setState(() {
      _expandedGroupId = _expandedGroupId == groupId ? null : groupId;
    });
  }

  bool _matchesQuery(BuildContext context, MockScenarioGroup group) {
    final tokens = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return true;

    final parts = <String?>[
      group.id,
      group.labelBuilder(context),
      group.method,
      group.path,
      group.sectionBuilder?.call(context),
      group.descriptionBuilder?.call(context),
      for (final scenario in group.scenarios) ...[
        scenario.id,
        scenario.labelBuilder(context),
        scenario.descriptionBuilder?.call(context),
        scenario.responseSummaryBuilder?.call(context),
      ],
    ];
    final haystack = parts.whereType<String>().join(' ').toLowerCase();
    return tokens.every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(_panelMaxWidth, size.width - padding.horizontal);
    final available = size.height - insets.bottom - padding.top;
    final maxHeight = math.max(
      0.0,
      math.min(available * 0.92, _panelMaxHeight),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: labels.title,
            child: FocusScope(
              autofocus: true,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      widget.onClose,
                  const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                      _focusSearch,
                  const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                      _focusSearch,
                },
                child: Focus(
                  autofocus: true,
                  child: Material(
                    color: theme.colorScheme.surface,
                    elevation: 8,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        final bottomSafe = padding.bottom;
                        final labels = widget.labels;
                        final controller = widget.controller;
                        final groups = [
                          for (final group in controller.config.groups)
                            if (group.scenarios.isNotEmpty) group,
                        ];
                        final visible = [
                          for (final group in groups)
                            if ((_filter == _EndpointFilter.all ||
                                    controller.selectedScenarioId(group.id) !=
                                        null) &&
                                _matchesQuery(context, group))
                              group,
                        ];
                        final selectedCount =
                            controller.selectedScenarioIds.length;
                        final hasHappyPath = groups.any(
                          (group) => group.scenarios.any(
                            (scenario) =>
                                scenario.kind == MockScenarioKind.success,
                          ),
                        );

                        final compactViewport =
                            maxHeight < 360 ||
                            MediaQuery.textScalerOf(context).scale(14) > 24;
                        final header = _PanelHeader(
                          labels: labels,
                          selectedCount: selectedCount,
                          onReset: selectedCount == 0 ? null : controller.reset,
                          onClose: widget.onClose,
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!compactViewport) header,
                            Flexible(
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(
                                      overscroll: false,
                                      physics: const ClampingScrollPhysics(),
                                    ),
                                child: CustomScrollView(
                                  shrinkWrap: true,
                                  primary: false,
                                  physics: const ClampingScrollPhysics(),
                                  slivers: [
                                    if (compactViewport)
                                      SliverToBoxAdapter(child: header),
                                    SliverToBoxAdapter(
                                      child: _PanelToolbar(
                                        labels: labels,
                                        controller: controller,
                                        searchController: _searchController,
                                        searchFocus: _searchFocus,
                                        query: _query,
                                        onQuery: _setQuery,
                                        onClearSearch: _clearSearch,
                                        filter: _filter,
                                        onFilter: _setFilter,
                                        hasHappyPath: hasHappyPath,
                                        resultCount: visible.length,
                                        showResults: groups.isNotEmpty,
                                      ),
                                    ),
                                    if (groups.isEmpty)
                                      SliverToBoxAdapter(
                                        child: _EmptyState(
                                          icon: Icons.science_outlined,
                                          message: labels.noScenariosLabel,
                                        ),
                                      )
                                    else if (visible.isEmpty)
                                      SliverToBoxAdapter(
                                        child: _EmptyState(
                                          icon: Icons.search_off,
                                          message: labels.noResultsLabel,
                                          actionLabel: _query.isNotEmpty
                                              ? labels.clearSearchLabel
                                              : labels.allEndpointsLabel,
                                          onAction: _query.isNotEmpty
                                              ? _clearSearch
                                              : () => _setFilter(
                                                  _EndpointFilter.all,
                                                ),
                                        ),
                                      )
                                    else
                                      SliverList(
                                        delegate: SliverChildListDelegate(
                                          _buildEntries(context, visible),
                                        ),
                                      ),
                                    SliverToBoxAdapter(
                                      child: SizedBox(height: 16 + bottomSafe),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEntries(
    BuildContext context,
    List<MockScenarioGroup> visible,
  ) {
    final sections = <String?, List<MockScenarioGroup>>{};
    for (final group in visible) {
      sections
          .putIfAbsent(group.sectionBuilder?.call(context), () => [])
          .add(group);
    }

    final widgets = <Widget>[];
    sections.forEach((section, sectionGroups) {
      if (section != null) {
        widgets.add(_SectionHeader(title: section));
      }
      for (final group in sectionGroups) {
        widgets.add(
          _EndpointCard(
            key: ValueKey<String>(group.id),
            group: group,
            controller: widget.controller,
            labels: widget.labels,
            expanded: _expandedGroupId == group.id,
            onToggle: () => _toggleExpanded(group.id),
          ),
        );
      }
    });
    return widgets;
  }
}
