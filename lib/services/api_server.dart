import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'config_service.dart';
import 'log_service.dart';

class ApiServer {
  static ApiServer? _instance;
  static ApiServer get instance => _instance ??= ApiServer._();
  ApiServer._();

  HttpServer? _server;
  bool _isRunning = false;
  DateTime? _startTime;
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  bool get isRunning => _isRunning;
  DateTime? get startTime => _startTime;
  Stream<String> get statusStream => _statusController.stream;

  String? get serverUrl {
    if (!_isRunning || _server == null) return null;
    final address = _server!.address.address;
    final port = _server!.port;
    return 'http://$address:$port';
  }

  Duration? get uptime {
    if (_startTime == null) return null;
    return DateTime.now().difference(_startTime!);
  }

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      final config = ConfigService.instance;
      await config.initialize();

      final router = _createRouter();
      final handler = Pipeline()
          .addMiddleware(corsHeaders())
          .addMiddleware(_loggingMiddleware)
          .addHandler(router.call);

      _server = await io.serve(
        handler,
        InternetAddress.anyIPv4,
        config.serverPort,
      );

      _isRunning = true;
      _startTime = DateTime.now();
      await config.setLastStartTime(_startTime!);

      _statusController.add(
          'Server started on ${_server!.address.address}:${_server!.port}');
      LogService.instance
          .addSystemLog('Server started on port ${config.serverPort}');

      return true;
    } catch (e) {
      _statusController.add('Failed to start server: $e');
      LogService.instance
          .addSystemLog('Failed to start server: $e', level: 'ERROR');
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning || _server == null) return;

    await _server!.close(force: true);
    _server = null;
    _isRunning = false;
    _startTime = null;

    _statusController.add('Server stopped');
    LogService.instance.addSystemLog('Server stopped');
  }

  Future<void> restart() async {
    if (_isRunning) {
      await stop();
      await Future.delayed(const Duration(seconds: 1));
    }
    await start();
  }

  Router _createRouter() {
    final router = Router();

    // Health check
    router.get('/ping', _handlePing);

    // Users endpoints
    router.get('/users', _handleGetUsers);
    router.post('/users', _handleCreateUser);
    router.get('/users/<id>', _handleGetUser);
    router.put('/users/<id>', _handleUpdateUser);
    router.delete('/users/<id>', _handleDeleteUser);

    // Server info
    router.get('/info', _handleServerInfo);

    // 404 handler
    router.all('/<ignored|.*>', _handleNotFound);

    return router;
  }

  Middleware get _loggingMiddleware => (Handler handler) {
        return (Request request) async {
          final stopwatch = Stopwatch()..start();

          try {
            final response = await handler(request);
            stopwatch.stop();

            LogService.instance.addHttpLog(
              method: request.method,
              url: request.url.path,
              statusCode: response.statusCode,
              userAgent: request.headers['user-agent'],
              remoteAddress: 'unknown',
              responseTime: stopwatch.elapsed,
            );

            await ConfigService.instance.incrementRequests();
            return response;
          } catch (e) {
            stopwatch.stop();

            LogService.instance.addHttpLog(
              method: request.method,
              url: request.url.path,
              statusCode: 500,
              userAgent: request.headers['user-agent'],
              remoteAddress: 'unknown',
              responseTime: stopwatch.elapsed,
            );

            return Response.internalServerError(
              body: jsonEncode({'error': 'Internal server error'}),
              headers: {'Content-Type': 'application/json'},
            );
          }
        };
      };

  // Route handlers
  Response _handlePing(Request request) {
    return Response.ok(
      jsonEncode({
        'message': 'pong',
        'timestamp': DateTime.now().toIso8601String(),
        'uptime_seconds': uptime?.inSeconds ?? 0,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleGetUsers(Request request) async {
    try {
      final users = await DatabaseService.instance.getAllUsers();
      return Response.ok(
        jsonEncode({
          'users': users.map((user) => user.toJson()).toList(),
          'count': users.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch users: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleCreateUser(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final user = UserModel.fromJson(data);
      final id = await DatabaseService.instance.createUser(user);

      return Response(
        201,
        body: jsonEncode({
          'message': 'User created successfully',
          'user_id': id,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Failed to create user: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleGetUser(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      final user = await DatabaseService.instance.getUserById(id);

      if (user == null) {
        return Response.notFound(
          jsonEncode({'error': 'User not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'user': user.toJson()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid user ID'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleUpdateUser(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final user = UserModel.fromJson(data);
      final success = await DatabaseService.instance.updateUser(id, user);

      if (!success) {
        return Response.notFound(
          jsonEncode({'error': 'User not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'User updated successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Failed to update user: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleDeleteUser(Request request) async {
    try {
      final id = int.parse(request.params['id']!);
      final success = await DatabaseService.instance.deleteUser(id);

      if (!success) {
        return Response.notFound(
          jsonEncode({'error': 'User not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'message': 'User deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Failed to delete user: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleServerInfo(Request request) async {
    try {
      final dbInfo = await DatabaseService.instance.getDatabaseInfo();
      final config = ConfigService.instance;

      return Response.ok(
        jsonEncode({
          'server': {
            'url': serverUrl,
            'uptime_seconds': uptime?.inSeconds ?? 0,
            'start_time': _startTime?.toIso8601String(),
            'port': config.serverPort,
          },
          'database': dbInfo,
          'statistics': {
            'total_requests': config.totalRequests,
            'logs_count': LogService.instance.logCount,
            'method_stats': LogService.instance.getMethodStats(),
            'status_stats': LogService.instance.getStatusCodeStats(),
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get server info: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Response _handleNotFound(Request request) {
    return Response.notFound(
      jsonEncode({
        'error': 'Endpoint not found',
        'path': request.url.path,
        'method': request.method,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  void dispose() {
    _statusController.close();
  }
}
