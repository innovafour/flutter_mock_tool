import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mock_tool/flutter_mock_tool.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final MockToolController _controller = MockToolController(
    config: _config,
    isDevelopment: kDebugMode,
  );
  late final Dio _dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
    ..httpClientAdapter = _DemoRealTransport()
    ..interceptors.add(
      MockDioInterceptor(controller: _controller, config: _transportConfig),
    );
  String _result = 'Choose a profile scenario and make a normal Dio request.';

  MockToolConfig get _config => MockToolConfig(
    groups: [
      MockScenarioGroup(
        id: 'profile',
        method: 'GET',
        path: '/profile',
        labelBuilder: (_) => 'Profile',
        scenarios: const [
          MockScenario(
            id: 'success',
            labelBuilder: _successLabel,
            kind: MockScenarioKind.success,
          ),
          MockScenario(
            id: 'unavailable',
            labelBuilder: _errorLabel,
            descriptionBuilder: _errorDescription,
            kind: MockScenarioKind.error,
          ),
          MockScenario(
            id: 'pending',
            labelBuilder: _loadingLabel,
            kind: MockScenarioKind.loading,
          ),
        ],
      ),
    ],
  );

  MockTransportConfig get _transportConfig => MockTransportConfig(
    routes: [
      MockTransportRoute(
        groupId: 'profile',
        method: 'GET',
        path: '/profile',
        scenarios: {
          'success': MockTransportResponse(
            data: {'name': 'Ada'},
            statusCode: 200,
          ),
          'unavailable': MockTransportFailure(
            message: 'Profile service unavailable',
            statusCode: 503,
            data: {'message': 'Try again later'},
          ),
          'pending': MockTransportResponse(
            data: {'name': 'Ada'},
            delay: const Duration(seconds: 2),
          ),
        },
      ),
    ],
  );

  Future<void> _loadProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/profile');
      setState(() => _result = 'Profile response: ${response.data}');
    } on DioException catch (error) {
      setState(
        () => _result =
            'Dio error ${error.response?.statusCode}: ${error.message}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: MockToolOverlay(
        controller: _controller,
        localizationsBuilder: (_) => const MockToolLocalizations(
          title: 'Scenario tool',
          happyPathLabel: 'Happy path',
          resetLabel: 'Reset selections',
          clearSelectionLabel: 'Clear group selection',
          closeLabel: 'Close scenario tool',
          noScenariosLabel: 'No scenarios configured.',
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Host app example')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_result, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadProfile,
                    child: const Text('Load profile using shared Dio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _successLabel(BuildContext _) => 'Success response';
String _errorLabel(BuildContext _) => 'Unavailable response';
String _errorDescription(BuildContext _) => 'Demonstrates a Dio failure';
String _loadingLabel(BuildContext _) => 'Delayed response';

class _DemoRealTransport implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"name":"real transport example"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
