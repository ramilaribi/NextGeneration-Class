import 'dart:convert';

import '../../core/network/token_store.dart';
import '../../domain/model/privacy.dart';
import '../../domain/model/student.dart';
import '../../domain/repositories/privacy_repository.dart';
import '../dto/student_dto.dart';
import '../remote/privacy_api.dart';
import 'api_guard.dart';

class PrivacyRepositoryImpl implements PrivacyRepository {
  PrivacyRepositoryImpl(this._api, this._tokens);

  final PrivacyApi _api;
  final TokenStore _tokens;

  @override
  Future<PrivacyInfo> info() => guard(() async {
    final json = await _api.info();
    return PrivacyInfo(
      required: json['required'] as bool? ?? false,
      teacherName: json['teacherName'] as String?,
      children: [for (final c in json['children'] as List? ?? const []) '$c'],
    );
  });

  @override
  Future<void> accept() => guard(() async {
    await _api.accept();
    // The session kept on the device opens on the space next time, without asking again.
    final cached = await _tokens.readUser();
    if (cached != null) {
      await _tokens.saveUser(jsonEncode((jsonDecode(cached) as Map<String, dynamic>)..['privacyRequired'] = false));
    }
  });

  @override
  Future<StudentConsent> paper(String studentId) => guard(() async => consentOf(await _api.paper(studentId))!);
}
