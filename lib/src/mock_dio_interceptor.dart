import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_mock_tool/src/mock_tool_controller.dart';

class MockTransportConfig {
  MockTransportConfig({required List<MockTransportRoute> routes})
    : routes = List.unmodifiable(routes) {
    final routeKeys = <String>{};
    for (final route in routes) {
      final key = '${route.method} ${route.path} ${route.groupId}';
      if (!routeKeys.add(key)) {
        throw ArgumentError('Transport route definitions must be unique: $key');
      }
    }
  }

  final List<MockTransportRoute> routes;

  MockTransportRoute? match(RequestOptions options) {
    for (final route in routes) {
      if (route.matches(options)) return route;
    }
    return null;
  }
}

class MockTransportRoute {
  MockTransportRoute({
    required this.groupId,
    required String method,
    required this.path,
    required Map<String, MockTransportOutcome> scenarios,
    this.queryMatcher,
    this.dataMatcher,
  }) : method = method.toUpperCase(),
       scenarios = Map.unmodifiable(scenarios) {
    if (groupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Must not be empty.');
    }
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Must not be empty.');
    }
    if (this.scenarios.keys.any((id) => id.isEmpty)) {
      throw ArgumentError('Scenario IDs must not be empty.');
    }
  }

  final String groupId;
  final String method;
  final String path;
  final Map<String, MockTransportOutcome> scenarios;
  final bool Function(Map<String, dynamic> queryParameters)? queryMatcher;
  final bool Function(Object? data)? dataMatcher;

  bool matches(RequestOptions options) {
    if (options.method.toUpperCase() != method ||
        _normalizePath(options.path) != _normalizePath(path)) {
      return false;
    }
    if (queryMatcher != null && !queryMatcher!(options.queryParameters)) {
      return false;
    }
    if (dataMatcher != null && !dataMatcher!(options.data)) return false;
    return true;
  }

  static String _normalizePath(String value) {
    final uriPath = Uri.tryParse(value)?.path ?? value;
    final leadingSlash = uriPath.startsWith('/') ? uriPath : '/$uriPath';
    if (leadingSlash.length > 1 && leadingSlash.endsWith('/')) {
      return leadingSlash.substring(0, leadingSlash.length - 1);
    }
    return leadingSlash;
  }
}

sealed class MockTransportOutcome {
  const MockTransportOutcome({this.delay = Duration.zero});

  final Duration delay;
}

class MockTransportResponse extends MockTransportOutcome {
  MockTransportResponse({
    required this.data,
    this.statusCode = 200,
    this.statusMessage,
    Map<String, List<String>> headers = const {},
    super.delay,
  }) : headers = Map<String, List<String>>.unmodifiable(
         headers.map<String, List<String>>(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       );

  final Object? data;
  final int statusCode;
  final String? statusMessage;
  final Map<String, List<String>> headers;
}

class MockTransportFailure extends MockTransportOutcome {
  MockTransportFailure({
    required this.message,
    this.statusCode = 500,
    this.data,
    Map<String, List<String>> headers = const {},
    super.delay,
  }) : headers = Map<String, List<String>>.unmodifiable(
         headers.map<String, List<String>>(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       );

  final String message;
  final int statusCode;
  final Object? data;
  final Map<String, List<String>> headers;
}

class MockDioInterceptor extends Interceptor {
  MockDioInterceptor({required this.controller, required this.config}) {
    for (final route in config.routes) {
      controller.config.group(route.groupId);
      for (final scenarioId in route.scenarios.keys) {
        if (controller.config.scenario(route.groupId, scenarioId) == null) {
          throw ArgumentError.value(
            scenarioId,
            'scenarioId',
            'Unknown scenario in group "${route.groupId}".',
          );
        }
      }
    }
  }

  final MockToolController controller;
  final MockTransportConfig config;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    unawaited(_handleRequest(options, handler));
  }

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!controller.isActive) {
      handler.next(options);
      return;
    }

    MockTransportRoute? route;
    try {
      route = config.match(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }
    if (route == null) {
      handler.next(options);
      return;
    }

    final scenarioId = controller.selectedScenarioId(route.groupId);
    if (scenarioId == null) {
      handler.next(options);
      return;
    }
    final outcome = route.scenarios[scenarioId];
    if (outcome == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          message:
              'Selected scenario "$scenarioId" has no mock response for '
              '${route.method} ${route.path} (group "${route.groupId}").',
        ),
      );
      return;
    }

    try {
      await _waitForDelay(outcome.delay, options);
      final cancellation = options.cancelToken?.cancelError;
      if (cancellation != null) {
        handler.reject(cancellation);
        return;
      }
      switch (outcome) {
        case MockTransportResponse(
          :final data,
          :final statusCode,
          :final statusMessage,
          :final headers,
        ):
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: data,
              statusCode: statusCode,
              statusMessage: statusMessage,
              headers: Headers.fromMap(headers),
            ),
          );
        case MockTransportFailure(
          :final message,
          :final statusCode,
          :final data,
          :final headers,
        ):
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<Object?>(
                requestOptions: options,
                data: data,
                statusCode: statusCode,
                statusMessage: message,
                headers: Headers.fromMap(headers),
              ),
              type: DioExceptionType.badResponse,
              message: message,
            ),
          );
      }
    } on DioException catch (error) {
      handler.reject(error);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _waitForDelay(Duration delay, RequestOptions options) async {
    final token = options.cancelToken;
    if (token == null || delay == Duration.zero) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return;
    }
    await Future.any<void>([
      Future<void>.delayed(delay),
      token.whenCancel.then<void>((error) => throw error),
    ]);
  }
}
