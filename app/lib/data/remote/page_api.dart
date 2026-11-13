import 'package:dio/dio.dart';

import '../dto/school_dto.dart';

/// `/contents/pages`, `/contents/{id}/page`, `/contents/pictures` (release 3).
class PageApi {
  PageApi(this._dio);

  final Dio _dio;

  Future<Json> create(Json body) async => (await _dio.post<Json>('/contents/pages', data: body)).data!;

  Future<Json> page(String id) async => (await _dio.get<Json>('/contents/$id/page')).data!;

  Future<Json> save(String id, Json body) async => (await _dio.put<Json>('/contents/$id/page', data: body)).data!;

  Future<Json> picture(List<int> bytes, String fileName) async {
    final form = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: fileName)});
    return (await _dio.post<Json>('/contents/pictures', data: form)).data!;
  }
}
