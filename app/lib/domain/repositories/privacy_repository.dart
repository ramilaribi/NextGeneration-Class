import '../model/privacy.dart';
import '../model/student.dart';

/// The privacy notice and the parents' agreement.
abstract interface class PrivacyRepository {
  Future<PrivacyInfo> info();

  /// A parent accepts the notice, once for all their children.
  Future<void> accept();

  /// "Accord reçu sur papier" for one of the teacher's pupils.
  Future<StudentConsent> paper(String studentId);
}
