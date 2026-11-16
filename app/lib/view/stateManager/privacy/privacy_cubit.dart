import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/model/privacy.dart';
import '../../../domain/repositories/privacy_repository.dart';
import '../common/load_status.dart';

class PrivacyAgreementState extends Equatable {
  const PrivacyAgreementState({this.status = LoadStatus.loading, this.info, this.checked = false, this.sending = false, this.failure});

  final LoadStatus status;
  final PrivacyInfo? info;

  /// "J'accepte …" ticked: "Continuer" works only then.
  final bool checked;
  final bool sending;
  final ApiFailure? failure;

  PrivacyAgreementState copyWith({LoadStatus? status, PrivacyInfo? info, bool? checked, bool? sending, ApiFailure? Function()? failure}) =>
      PrivacyAgreementState(
        status: status ?? this.status,
        info: info ?? this.info,
        checked: checked ?? this.checked,
        sending: sending ?? this.sending,
        failure: failure != null ? failure() : this.failure,
      );

  @override
  List<Object?> get props => [status, info, checked, sending, failure?.code];
}

/// A parent's first login (design `r4/AccordParents.png`): the essentials, a box to tick, "Continuer".
class PrivacyAgreementCubit extends Cubit<PrivacyAgreementState> {
  PrivacyAgreementCubit(this._repository) : super(const PrivacyAgreementState());

  final PrivacyRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final info = await _repository.info();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, info: info));
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  void setChecked(bool value) => emit(state.copyWith(checked: value));

  /// True once accepted.
  Future<bool> accept() async {
    if (!state.checked || state.sending) return false;
    emit(state.copyWith(sending: true, failure: () => null));
    try {
      await _repository.accept();
      if (!isClosed) emit(state.copyWith(sending: false));
      return true;
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(sending: false, failure: () => ApiFailure.from(error)));
      return false;
    }
  }
}
