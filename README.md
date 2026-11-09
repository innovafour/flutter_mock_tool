# flutter_mock_tool

A reusable development-only Flutter scenario panel and optional global Dio
interceptor. The host owns its endpoint catalog, fixtures, localization, theme,
and real API configuration. There are no app-specific imports or credentials.

## Routing contract

In development, selecting a scenario mocks that endpoint immediately. Clearing
it uses the real API. One client can mix mocked and real endpoints. Unselected
and unregistered requests continue through the original Dio adapter once, with
headers, data, cancellation and errors preserved. There is no mock fallback
following a real error. A selected scenario missing a registered transport
outcome rejects with a clear DioException rather than silently using real data.

Production (`isDevelopment: false`) and Flutter release builds always use real
transport and omit the panel, even if saved selections exist.

```dart
final controller = MockToolController(
  isDevelopment: appEnvironment.isDevelopment,
  config: MockToolConfig(groups: [
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
      ],
    ),
  ]),
);
// Add once where the host shared Dio is created, not in repositories.
dio.interceptors.add(MockDioInterceptor(
  controller: controller,
  config: MockTransportConfig(routes: [
    MockTransportRoute(
      groupId: 'profile', method: 'GET', path: '/profile',
      scenarios: {'success': MockTransportResponse(data: {'name': 'Ada'})},
    ),
  ]),
));
```

Routes match normalized relative or absolute URI paths and HTTP methods.
Optional query/data predicates narrow matching; first matching route wins.
Scenario IDs must exist in the UI catalog. Keep one independently selectable
endpoint per group. A host requiring an origin before real calls should validate
its configuration at the shared client boundary; clearing a selection can invoke
real transport.

## Panel

Wrap routed content with `MockToolOverlay(child: app, controller: controller,
localizationsBuilder: (_) => labels)`. It follows the host Material theme.
`MockToolLocalizations` supplies configurable search, filter, count, empty-state,
reset and routing-hint labels. Count builders let hosts localize plural forms.
Group method/path, section and descriptions and scenario response summaries are
optional. Search includes endpoint metadata and scenario text. Selection filters,
counts and endpoint summaries update directly from the controller.

Selections are in memory. `reset()` clears all selections. `setHappyPath(true)`
selects the first success in each group; groups without success remain real.
Manual changes leave happy-path state; disabling happy path clears selections.
The transport-neutral `MockScenarioRouter` follows the same selected/real rule
for hosts that do not use Dio.

## Compatibility migration

Existing constructors and scenario selection APIs remain source compatible.
`initiallyEnabled`, `setEnabled`, and `isEnabled` are deprecated compatibility
members: the first two do not gate mocking; `isEnabled` reports development
availability. `isActive` also reports development availability. Use
`controller.isMocked(groupId)` or `controller.isDevelopment &&
controller.selectedScenarioId(groupId) != null` to check an endpoint.
`unmatchedScenarioPolicy` remains accepted for compatibility but no longer
controls unselected endpoints or missing selected responses. `enabledLabel`
remains accepted and is unused. The panel contains no global toggle.

See `example/` for a shared Dio example with a fake real adapter, and `test/`
for adapter-backed tests that never reach the network.
