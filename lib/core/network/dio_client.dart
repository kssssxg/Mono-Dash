import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../utils/app_logger.dart';
import 'app_user_agent.dart';
import 'interceptors/api_envelope_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'network_exceptions.dart';

/// 基于 Dio 的 HTTP 客户端封装。
///
/// 职责：
/// - 配置 BaseOptions（baseUrl / 超时 / Header）
/// - 挂载统一拦截器链（鉴权 → 业务错误转换 → 日志）
/// - 把 `DioException` 统一转换为 [AppNetworkException]
class DioClient {
  DioClient({
    required String baseUrl,
    required String apiKey,
    Duration requestTimeout = _defaultRequestTimeout,
    Map<String, String> customHeaders = const {},
    required String userAgent,
    bool allowInsecureConnections = false,
  }) : _dio = Dio(
         _baseOptions(
           baseUrl,
           requestTimeout: requestTimeout,
           customHeaders: customHeaders,
           userAgent: userAgent,
         ),
       ),
       _auth = AuthInterceptor(apiKey) {
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (_, _, _) => allowInsecureConnections;
        return client;
      },
    );

    _dio.interceptors.addAll([
      _auth,
      ApiEnvelopeInterceptor(),
      LoggingInterceptor(),
    ]);
  }

  static const _tag = 'network.client';
  static const _defaultRequestTimeout = Duration(seconds: 60);

  final Dio _dio;
  final AuthInterceptor _auth;

  Dio get raw => _dio;

  /// 切换 API Key（不重建实例）。
  void updateApiKey(String apiKey) => _auth.updateApiKey(apiKey);

  /// 关闭底层连接池。
  void dispose() => _dio.close(force: true);

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _run(
      () => _dio.get<T>(
        path,
        queryParameters: query,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _run(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: query,
        options: options,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _run(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: query,
        options: options,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _run(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: query,
        options: options,
      ),
    );
  }

  /// 多部分表单上传，支持进度回调和取消。
  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData formData,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) {
    return _run(
      () => _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      ),
    );
  }

  /// 文件下载，支持进度回调和取消。
  Future<Response> download(
    String urlPath, {
    required String savePath,
    Map<String, dynamic>? query,
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return _run(
      () => _dio.download(
        urlPath,
        savePath,
        queryParameters: query,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  static BaseOptions _baseOptions(
    String baseUrl, {
    required Duration requestTimeout,
    required Map<String, String> customHeaders,
    required String userAgent,
  }) {
    // 规范做法一：底层仅保留到根目录，由 API 业务层拼版本号
    String normalizedUrl = baseUrl;
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    return BaseOptions(
      baseUrl: normalizedUrl,
      connectTimeout: requestTimeout,
      sendTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
      headers: _headers(customHeaders, userAgent),
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    );
  }

  static Future<String> defaultUserAgent() => AppUserAgent.value;

  static Map<String, String> _headers(
    Map<String, String> customHeaders,
    String userAgent,
  ) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': 'zh',
    };

    for (final entry in customHeaders.entries) {
      if (entry.key.toLowerCase() == HttpHeaders.userAgentHeader) continue;
      headers[entry.key] = entry.value;
    }

    headers[HttpHeaders.userAgentHeader] = userAgent;
    return headers;
  }

  Future<Response<T>> _run<T>(Future<Response<T>> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  AppNetworkException _toAppException(DioException e) {
    // 业务拦截器已把 code!=200 的响应转成 ApiBusinessException 放在 error 字段
    final inner = e.error;
    if (inner is AppNetworkException) return inner;

    final status = e.response?.statusCode;
    final msg = e.message ?? e.toString();

    AppLogger.w(_tag, 'Dio 错误 type=${e.type} status=$status msg=$msg');

    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return NetworkConnectionException('网络连接失败: $msg');
      case DioExceptionType.badCertificate:
        return NetworkConnectionException(
          '证书不受信任，连接已阻止。'
          '如果这是你信任的自签名证书，可在设置中启用“允许不安全连接”。\n$msg',
        );
      case DioExceptionType.cancel:
        return const NetworkConnectionException('请求已取消');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    if (status == 401) {
      return AuthException('认证失败', statusCode: status);
    }
    if (status != null && status >= 500) {
      return ServerException('服务器错误: $msg', statusCode: status);
    }
    if (status != null && status >= 400) {
      return HttpException('HTTP 错误: $msg', statusCode: status);
    }
    return HttpException('请求失败: $msg', statusCode: status);
  }
}
