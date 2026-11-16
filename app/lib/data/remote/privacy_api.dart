import 'package:dio/dio.dart';

import '../dto/school_dto.dart';

/// `/me/privacy` and `/students/{id}/consent`.
class PrivacyApi {
  PrivacyApi(this._dio);

  final Dio _dio;

  Future<Json> info() async => (await _dio.get<Json>('/me/privacy')).data!;

  Future<void> accept() => _dio.post<void>('/me/privacy');

  Future<Json> paper(String studentId) async => (await _dio.post<Json>('/students/$studentId/consent')).data!;
}
