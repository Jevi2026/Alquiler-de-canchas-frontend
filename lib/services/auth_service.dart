import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_user.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
}

class AuthService extends ChangeNotifier {
  final http.Client _client;
  String? _token;
  AuthUser? _user;

  AuthService({http.Client? client}) : _client = client ?? http.Client();
  AuthUser? get user => _user;
  bool get isAuthenticated => _token != null && _user != null;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (authenticated && _token != null) 'Authorization': 'Bearer $_token',
    };
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$path');
      final encoded = body == null ? null : jsonEncode(body);
      final Future<http.Response> pending = switch (method) {
        'GET' => _client.get(url, headers: headers),
        'POST' => _client.post(url, headers: headers, body: encoded),
        'PUT' => _client.put(url, headers: headers, body: encoded),
        'PATCH' => _client.patch(url, headers: headers, body: encoded),
        'DELETE' => _client.delete(url, headers: headers),
        _ => throw const ApiException('Metodo HTTP no soportado.'),
      };
      final response = await pending.timeout(const Duration(seconds: 20));
      if (authenticated &&
          (response.statusCode == 401 || response.statusCode == 403)) {
        _clearSession();
        throw ApiException(
          'Sesion vencida o sin permisos. Inicia sesion otra vez.',
          response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode >= 400) {
        var message = decoded['message']?.toString() ?? 'Solicitud rechazada.';
        if (decoded['errors'] is Map) {
          message = (decoded['errors'] as Map).values
              .map((e) => (e as List).join(' '))
              .join('\n');
        }
        if (response.statusCode >= 500) {
          message = decoded['message']?.toString() ?? 'Error del servidor.';
        }
        throw ApiException(message, response.statusCode);
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException('El servidor tardo demasiado.');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar. Revisa Laravel y CORS.');
    } on FormatException {
      throw const ApiException('La API no devolvio el JSON esperado.');
    }
  }

  Future<List<int>> downloadPdf(String path) async {
    if (_token == null) throw const ApiException('Inicia sesion para descargar el reporte.');
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {'Accept': 'application/pdf', 'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode >= 400) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(decoded['message']?.toString() ?? 'No se pudo generar el reporte.', response.statusCode);
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const ApiException('El servidor tardo demasiado al generar el reporte.');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor.');
    } on FormatException {
      throw const ApiException('No se pudo interpretar la respuesta del servidor.');
    }
  }

  Future<Map<String, dynamic>> requestMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    Uint8List? photo,
    String? photoName,
  }) async {
    final request = http.MultipartRequest(
      method == 'PUT' ? 'POST' : method,
      Uri.parse('${ApiConfig.baseUrl}$path'),
    )..headers.addAll({
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    });
    request.fields.addAll(fields);
    if (method == 'PUT') request.fields['_method'] = 'PUT';
    if (photo != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo', photo,
        filename: photoName ?? 'cancha.jpg',
      ));
    }
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 || response.statusCode == 403) {
        _clearSession();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode >= 400) {
        var message = decoded['message']?.toString() ?? 'Solicitud rechazada.';
        if (decoded['errors'] is Map) {
          message = (decoded['errors'] as Map).values
              .map((value) => (value as List).join(' ')).join('\n');
        }
        throw ApiException(message, response.statusCode);
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException('El servidor tardo demasiado.');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor.');
    } on FormatException {
      throw const ApiException('La API no devolvio el JSON esperado.');
    }
  }

  Future<void> login(String username, String password) async {
    final data = await request(
      'POST',
      '/login',
      body: {
        'username': username.trim(),
        'password': password,
        'device_name': 'flutter-app',
      },
    );
    _token = data['access_token'] as String;
    _user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> register({
    required String username,
    required String name,
    required String email,
    required String gender,
    required String password,
    required String passwordConfirmation,
  }) async {
    await request(
      'POST',
      '/register',
      body: {
        'username': username.trim(),
        'name': name.trim(),
        'email': email.trim(),
        'gender': gender,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<void> refreshUser() async {
    final data = await request('GET', '/user', authenticated: true);
    _user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await request('POST', '/logout', body: {}, authenticated: true);
    } finally {
      _clearSession();
    }
  }

  void _clearSession() {
    _token = null;
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
