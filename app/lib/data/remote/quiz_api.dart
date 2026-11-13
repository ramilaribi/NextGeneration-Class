import 'package:dio/dio.dart';

import '../dto/school_dto.dart';

/// The teacher's builder (`/contents/quizzes`, `/contents/{id}/quiz`), the pupil's attempts
/// (`/me/assignments/{id}/quiz`) and the teacher's correction (`/assignments/{id}/quiz/{studentId}`), release 3.
class QuizApi {
  QuizApi(this._dio);

  final Dio _dio;

  Future<Json> create(Json body) async => (await _dio.post<Json>('/contents/quizzes', data: body)).data!;

  Future<Json> quiz(String id) async => (await _dio.get<Json>('/contents/$id/quiz')).data!;

  Future<Json> save(String id, Json body) async => (await _dio.put<Json>('/contents/$id/quiz', data: body)).data!;

  Future<Json> duplicate(String id) async => (await _dio.post<Json>('/contents/$id/quiz/duplicate')).data!;

  Future<List<dynamic>> preview(String id, Json answers) async =>
      (await _dio.post<List<dynamic>>('/contents/$id/quiz/preview', data: {'answers': answers})).data!;

  Map<String, dynamic>? _child(String? studentId) => studentId == null ? null : {'studentId': studentId};

  Future<Json> myQuiz(String assignmentId, {String? studentId}) async =>
      (await _dio.get<Json>('/me/assignments/$assignmentId/quiz', queryParameters: _child(studentId))).data!;

  Future<Json> start(String assignmentId, {String? studentId}) async =>
      (await _dio.post<Json>('/me/assignments/$assignmentId/quiz/attempts', queryParameters: _child(studentId))).data!;

  Future<void> saveAnswers(String assignmentId, String attemptId, Json answers, {String? studentId}) => _dio.put<void>(
    '/me/assignments/$assignmentId/quiz/attempts/$attemptId/answers',
    data: {'answers': answers},
    queryParameters: _child(studentId),
  );

  Future<Json> submit(String assignmentId, String attemptId, {String? studentId}) async =>
      (await _dio.post<Json>('/me/assignments/$assignmentId/quiz/attempts/$attemptId/submit', queryParameters: _child(studentId))).data!;

  Future<Json> attempt(String assignmentId, String attemptId, {String? studentId}) async =>
      (await _dio.get<Json>('/me/assignments/$assignmentId/quiz/attempts/$attemptId', queryParameters: _child(studentId))).data!;

  Future<Json> correction(String assignmentId, String studentId, {String? attemptId}) async => (await _dio.get<Json>(
    '/assignments/$assignmentId/quiz/$studentId',
    queryParameters: attemptId == null ? null : {'attemptId': attemptId},
  )).data!;

  Future<Json> correct(String assignmentId, String studentId, String attemptId, Json body) async =>
      (await _dio.put<Json>('/assignments/$assignmentId/quiz/$studentId/attempts/$attemptId', data: body)).data!;
}
