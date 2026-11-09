// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mock_tool/flutter_mock_tool.dart';

void main() {
  group('MockDioInterceptor', () {
    test(
      'returns a selected fixture without reaching the HTTP adapter',
      () async {
        final controller = _controller();
        controller.selectScenario('profile', 'success');
        final adapter = _RecordingAdapter();
        final client = _client(controller, adapter);

        final cancelToken = CancelToken();
        final response = await client.get<Object?>(
          '/profile',
          options: Options(headers: {'X-Host-Header': 'preserved'}),
          cancelToken: cancelToken,
        );

        expect(response.data, {'name': 'Ada'});
        expect(response.statusCode, 202);
        expect(response.requestOptions.path, '/profile');
        expect(response.requestOptions.cancelToken, same(cancelToken));
        expect(response.requestOptions.headers['X-Host-Header'], 'preserved');
        expect(response.headers.value('x-mock-fixture'), 'present');
        expect(adapter.calls, 0);
      },
    );

    test(
      'matches method, query, and request data in the central registry',
      () async {
        final controller = _controller();
        controller.selectScenario('profile', 'success');
        final adapter = _RecordingAdapter();
        final client = _client(
          controller,
          adapter,
          route: MockTransportRoute(
            groupId: 'profile',
            method: 'post',
            path: '/profile',
            queryMatcher: (query) => query['version'] == '2',
            dataMatcher: (data) => data is Map && data['name'] == 'Ada',
            scenarios: {
              'success': MockTransportResponse(data: {'saved': true}),
            },
          ),
        );

        final response = await client.post<Object?>(
          '/profile',
          queryParameters: {'version': '2'},
          data: {'name': 'Ada'},
        );

        expect(response.data, {'saved': true});
        expect(adapter.calls, 0);
      },
    );

    test(
      'production controller state always forwards selected routes',
      () async {
        final controller = _controller();
        final productionController = MockToolController(
          config: controller.config,
          isDevelopment: false,
          initiallyEnabled: true,
        );
        productionController.selectScenario('profile', 'success');
        final adapter = _RecordingAdapter();

        final response = await _client(
          productionController,
          adapter,
        ).get<String>('/profile');

        expect(response.data, 'real response');
        expect(adapter.calls, 1);
      },
    );

    test(
      'a request that fails optional matching predicates passes through',
      () async {
        final controller = _controller();
        controller.selectScenario('profile', 'success');
        final adapter = _RecordingAdapter();
        final client = _client(
          controller,
          adapter,
          route: MockTransportRoute(
            groupId: 'profile',
            method: 'get',
            path: '/profile',
            queryMatcher: (query) => query['version'] == '2',
            scenarios: {
              'success': MockTransportResponse(data: {'name': 'Ada'}),
            },
          ),
        );

        final response = await client.get<String>(
          '/profile',
          queryParameters: {'version': '1'},
        );

        expect(response.data, 'real response');
        expect(adapter.calls, 1);
      },
    );

    test(
      'an active registered route delegates once under delegateToReal',
      () async {
        final controller = _controller();
        final adapter = _RecordingAdapter();
        final response = await _client(
          controller,
          adapter,
        ).get<String>('/profile');

        expect(response.data, 'real response');
        expect(adapter.calls, 1);
      },
    );

    test(
      'unselected route delegates even under legacy throwing policy',
      () async {
        final controller = _controller(
          policy: UnmatchedScenarioPolicy.throwStateError,
        );
        final adapter = _RecordingAdapter();
        final response = await _client(
          controller,
          adapter,
        ).get<String>('/profile');
        expect(response.data, 'real response');
        expect(adapter.calls, 1);
      },
    );

    test(
      'selected scenario missing outcome rejects without real fallback',
      () async {
        final controller = _controller()..selectScenario('profile', 'error');
        final adapter = _RecordingAdapter();
        await expectLater(
          _client(controller, adapter).get<Object?>('/profile'),
          throwsA(
            isA<DioException>().having(
              (e) => e.message,
              'message',
              contains('has no mock response'),
            ),
          ),
        );
        expect(adapter.calls, 0);
      },
    );

    test(
      'one client mixes mocked and real endpoints then clears to real once',
      () async {
        final controller = _controller()..selectScenario('profile', 'success');
        final adapter = _RecordingAdapter();
        final client = _client(controller, adapter);
        expect(
          (await client.get<Object?>('https://host.invalid/profile')).data,
          {'name': 'Ada'},
        );
        expect(adapter.calls, 0);
        expect((await client.get<String>('/other')).data, 'real response');
        controller.clearScenario('profile');
        expect((await client.get<String>('/profile')).data, 'real response');
        expect(adapter.calls, 2);
      },
    );

    test(
      'simulated failures use DioException with response and request options',
      () async {
        final controller = _controller();
        controller.selectScenario('profile', 'error');
        final adapter = _RecordingAdapter();
        final client = _client(
          controller,
          adapter,
          outcomes: {
            'success': MockTransportResponse(data: {'name': 'Ada'}),
            'error': MockTransportFailure(
              message: 'Unavailable',
              statusCode: 503,
              data: {'message': 'try again'},
            ),
          },
        );

        await expectLater(
          client.get<Object?>('/profile'),
          throwsA(
            isA<DioException>()
                .having((error) => error.response?.statusCode, 'status', 503)
                .having((error) => error.response?.data, 'body', {
                  'message': 'try again',
                })
                .having(
                  (error) => error.requestOptions.path,
                  'path',
                  '/profile',
                ),
          ),
        );
        expect(adapter.calls, 0);
      },
    );

    test(
      'cleared selection forwards once and preserves client errors',
      () async {
        final controller = _controller();
        controller.selectScenario('profile', 'success');
        controller.clearScenario('profile');
        final adapter = _RecordingAdapter(
          onFetch: (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'offline',
          ),
        );
        final client = _client(controller, adapter);

        await expectLater(
          client.get<Object?>('/profile'),
          throwsA(
            isA<DioException>()
                .having(
                  (error) => error.type,
                  'type',
                  DioExceptionType.connectionError,
                )
                .having((error) => error.message, 'message', 'offline'),
          ),
        );
        expect(adapter.calls, 1);
      },
    );

    test(
      'an unregistered request passes through once in development',
      () async {
        final controller = _controller();
        final adapter = _RecordingAdapter();
        final response = await _client(
          controller,
          adapter,
        ).get<String>('/unregistered');

        expect(response.data, 'real response');
        expect(adapter.calls, 1);
      },
    );

    test('delay is cancellable and does not reach the adapter', () async {
      final controller = _controller();
      controller.selectScenario('profile', 'success');
      final adapter = _RecordingAdapter();
      final client = _client(
        controller,
        adapter,
        outcomes: {
          'success': MockTransportResponse(
            data: {'name': 'Ada'},
            delay: const Duration(seconds: 2),
          ),
        },
      );
      final token = CancelToken();
      final request = client.get<Object?>('/profile', cancelToken: token);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel('test cancellation');

      await expectLater(request, throwsA(isA<DioException>()));
      expect(adapter.calls, 0);
    });

    test('invalid registered scenario IDs fail catalog validation', () {
      final controller = _controller();
      final route = MockTransportRoute(
        groupId: 'profile',
        method: 'GET',
        path: '/profile',
        scenarios: {'missing': MockTransportResponse(data: 'wrong')},
      );
      expect(
        () => MockDioInterceptor(
          controller: controller,
          config: MockTransportConfig(routes: [route]),
        ),
        throwsArgumentError,
      );
    });

    test('route registry and scenario mappings are immutable snapshots', () {
      final scenarios = <String, MockTransportOutcome>{
        'success': MockTransportResponse(data: 'ok'),
      };
      final routes = <MockTransportRoute>[
        MockTransportRoute(
          groupId: 'profile',
          method: 'get',
          path: '/profile',
          scenarios: scenarios,
        ),
      ];
      final config = MockTransportConfig(routes: routes);
      scenarios.clear();
      routes.clear();

      expect(config.routes, hasLength(1));
      expect(config.routes.single.scenarios, contains('success'));
    });
  });
}

MockToolController _controller({
  UnmatchedScenarioPolicy policy = UnmatchedScenarioPolicy.delegateToReal,
}) {
  return MockToolController(
    config: MockToolConfig(
      unmatchedScenarioPolicy: policy,
      groups: [
        MockScenarioGroup(
          id: 'other',
          labelBuilder: (_) => 'Other',
          scenarios: [
            const MockScenario(id: 'success', labelBuilder: _successLabel),
          ],
        ),
        MockScenarioGroup(
          id: 'profile',
          labelBuilder: (_) => 'Profile',
          scenarios: const [
            MockScenario(
              id: 'success',
              labelBuilder: _successLabel,
              kind: MockScenarioKind.success,
            ),
            MockScenario(
              id: 'error',
              labelBuilder: _errorLabel,
              kind: MockScenarioKind.error,
            ),
          ],
        ),
      ],
    ),
    isDevelopment: true,
  );
}

String _successLabel(_) => 'Success';
String _errorLabel(_) => 'Error';

Dio _client(
  MockToolController controller,
  _RecordingAdapter adapter, {
  MockTransportRoute? route,
  Map<String, MockTransportOutcome>? outcomes,
}) {
  final actualRoute =
      route ??
      MockTransportRoute(
        groupId: 'profile',
        method: 'get',
        path: '/profile',
        scenarios:
            outcomes ??
            {
              'success': MockTransportResponse(
                data: {'name': 'Ada'},
                statusCode: 202,
                headers: {
                  'x-mock-fixture': ['present'],
                },
              ),
            },
      );
  return Dio(BaseOptions(baseUrl: 'https://mock.invalid'))
    ..httpClientAdapter = adapter
    ..interceptors.add(
      MockDioInterceptor(
        controller: controller,
        config: MockTransportConfig(
          routes: [
            actualRoute,
            MockTransportRoute(
              groupId: 'other',
              method: 'GET',
              path: '/other',
              scenarios: {
                'success': MockTransportResponse(data: 'other mocked'),
              },
            ),
          ],
        ),
      ),
    );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.onFetch});

  final Future<ResponseBody> Function(RequestOptions options)? onFetch;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final handler = onFetch;
    if (handler != null) return handler(options);
    return ResponseBody.fromString('real response', 200);
  }

  @override
  void close({bool force = false}) {}
}
