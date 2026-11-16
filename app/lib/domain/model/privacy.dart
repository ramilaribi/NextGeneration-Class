import 'package:equatable/equatable.dart';

/// What the parents' agreement screen shows (design `r4/AccordParents.png`): whether it is still needed, the
/// teacher's name and the children's first names.
class PrivacyInfo extends Equatable {
  const PrivacyInfo({required this.required, this.teacherName, this.children = const []});

  final bool required;
  final String? teacherName;
  final List<String> children;

  @override
  List<Object?> get props => [required, teacherName, children];
}
