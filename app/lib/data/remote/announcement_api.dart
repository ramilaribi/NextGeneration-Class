import 'package:dio/dio.dart';

import '../dto/school_dto.dart';

/// `/announcements` (Release 4).
class AnnouncementApi {
  AnnouncementApi(this._dio);

  final Dio _dio;

  Future<List<dynamic>> list() async => (await _dio.get<List<dynamic>>('/announcements')).data!;

  Future<Json> send(Json body) async => (await _dio.post<Json>('/announcements', data: body)).data!;

  Future<List<dynamic>> unread(String id) async => (await _dio.get<List<dynamic>>('/announcements/$id/unread')).data!;

  Future<void> delete(String id) => _dio.delete<void>('/announcements/$id');
}
