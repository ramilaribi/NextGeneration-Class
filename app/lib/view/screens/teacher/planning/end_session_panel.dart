import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/formatting.dart';
import '../../../../core/l10n/tunis_time.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/content.dart';
import '../../../../domain/model/session.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stateManager/common/load_status.dart';
import '../../../stateManager/language/language_cubit.dart';
import '../../../stateManager/session_mode/end_session_cubit.dart';
import '../../../stateManager/session_mode/session_mode_cubit.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/content_widgets.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/text_field.dart';

/// "Fin de séance" (Release 4, designs `r4/FinDeSeance.png`, `r4/FinDeSeancePhone.png`): after "Terminer la séance",
/// one panel prefilled with the attendance, what was covered, the private note and what comes next. Nothing is
/// required: "Terminer la séance" at once ends it as before.
class EndSessionPanel extends StatelessWidget {
  const EndSessionPanel({super.key});

  /// The choices, or null when the teacher goes back to the attendance.
  static Future<EndChoice?> open(BuildContext context) {
    final mode = context.read<SessionModeCubit>();
    final detail = mode.state.detail!;
    return showSidePanel<EndChoice>(
      context,
      width: 560,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: mode),
          BlocProvider(
            create: (_) => EndSessionCubit(sl.get(), sl.get(), detail: detail, quickNote: mode.state.quickNote)..load(),
          ),
        ],
        child: const EndSessionPanel(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final state = context.watch<EndSessionCubit>().state;
    final cubit = context.read<EndSessionCubit>();
    final mode = context.watch<SessionModeCubit>().state;
    final session = cubit.session;
    final day = TunisTime.day(session.startsAt);
    final quiet = text.style(12.5, FontWeight.w500, color: BrandColors.slate, height: 1.4);
    final label = text.style(14, FontWeight.w700);
    final absentNames = [
      for (final r in mode.detail!.roster)
        if (mode.markOf(r.studentId) == AttendanceStatus.absent) r.fullName,
    ];
    final subtitle = [
      isolated(session.group.name),
      dayInSentence(day, language),
      l10n.timeRange(hm(session.startsAt), hm(session.endsAt)),
    ].join(l10n.dotSeparator);

    final attendance = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(label: l10n.presentCount(mode.count(AttendanceStatus.present)), accent: Accent.green),
              StatusChip(
                label: [
                  l10n.absentCount(absentNames.length),
                  if (absentNames.isNotEmpty) absentNames.map(isolated).join(l10n.listSeparator),
                ].join(l10n.dotSeparator),
                accent: Accent.red,
              ),
              StatusChip(label: l10n.lateCount(mode.count(AttendanceStatus.late)), accent: Accent.orange),
            ],
          ),
        ),
        TextButton(
          key: const Key('end-edit-attendance'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.edit, style: text.style(13, FontWeight.w700, color: BrandColors.indigo)),
        ),
      ],
    );

    final Widget covered;
    if (state.status == LoadStatus.failure) {
      covered = FailureBanner(state.failure!, onRetry: cubit.load);
    } else if (state.status == LoadStatus.loading) {
      covered = const LinearProgressIndicator(minHeight: 3);
    } else {
      final documents = state.chapterDocuments;
      covered = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectField<String>(
            key: const Key('end-chapter'),
            hint: l10n.coveredChapterHint,
            value: state.chapterId,
            onChanged: cubit.setChapter,
            options: [for (final c in state.chapters) SelectOption(c.id, c.title)],
          ),
          if (state.chapterId != null) ...[
            const SizedBox(height: 10),
            if (documents.isEmpty)
              Text(l10n.coveredNoDocuments, style: quiet)
            else
              for (final d in documents) ...[
                _DocumentChoice(
                  key: Key('end-document-${d.id}'),
                  title: d.title,
                  subtitle: state.shared.contains(d.id) ? l10n.dayContentDocument : tagLabel(l10n, d.tag),
                  kind: d.kind,
                  selected: state.contentIds.contains(d.id),
                  onTap: () => cubit.toggleDocument(d.id),
                ),
                const SizedBox(height: 8),
              ],
          ],
          const SizedBox(height: 10),
          FormInput(key: const Key('end-details'), initialValue: state.details, hint: l10n.coveredDetailsHint, onChanged: cubit.setDetails),
          const SizedBox(height: 6),
          Text(l10n.coveredFamiliesHint(dayInSentence(day, language)), style: quiet),
        ],
      );
    }

    final next = session.recurring
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.row)),
            child: Row(
              children: [
                const Icon(LucideIcons.repeat, size: 18, color: BrandColors.indigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.endNextInSeries, style: text.style(13, FontWeight.w500, color: BrandColors.body)),
                ),
              ],
            ),
          )
        : _SwitchRow(
            key: const Key('end-plan-next'),
            value: state.planNext,
            title: l10n.endPlanNext,
            subtitle: l10n.endPlanNextHint,
            onChanged: cubit.setPlanNext,
            below: !state.planNext
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DateField(value: state.nextDate!, onChanged: cubit.setNextDate, firstDate: day),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TimeField(label: l10n.startTime, value: state.nextStart!, onChanged: cubit.setNextStart),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TimeField(label: l10n.endTime, value: state.nextEnd!, onChanged: cubit.setNextEnd, error: !state.nextValid),
                          ),
                        ],
                      ),
                    ],
                  ),
          );

    return SidePanel(
      icon: LucideIcons.flag,
      accent: Accent.green,
      title: l10n.endSessionPanel,
      subtitle: subtitle,
      actions: [
        GhostButton(label: l10n.back, onPressed: () => Navigator.of(context).pop()),
        PrimaryButton(
          key: const Key('end-confirm'),
          label: l10n.endSession,
          icon: LucideIcons.check,
          height: 44,
          onPressed: state.nextValid ? () => Navigator.of(context).pop(cubit.choice()) : null,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.attendanceTitle, style: label),
          const SizedBox(height: 8),
          attendance,
          const SizedBox(height: 22),
          Text(l10n.coveredLabel, style: label),
          const SizedBox(height: 8),
          covered,
          const SizedBox(height: 22),
          LabeledField(
            label: l10n.sessionNoteLabel,
            labelSuffix: l10n.pageOnlyYou,
            child: FormInput(
              key: const Key('end-note'),
              initialValue: state.sessionNote,
              hint: l10n.sessionNoteHint,
              maxLines: 3,
              onChanged: cubit.setSessionNote,
            ),
          ),
          const SizedBox(height: 22),
          Text(l10n.endThen, style: label),
          const SizedBox(height: 8),
          _SwitchRow(
            key: const Key('end-give-homework'),
            value: state.giveHomework,
            title: l10n.endGiveHomework,
            subtitle: l10n.endGiveHomeworkHint,
            onChanged: cubit.setGiveHomework,
          ),
          const SizedBox(height: 10),
          next,
        ],
      ),
    );
  }
}

class _DocumentChoice extends StatelessWidget {
  const _DocumentChoice({super.key, required this.title, required this.subtitle, required this.kind, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final FileKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Semantics(
      checked: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFFF4F5FC) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.row),
          side: BorderSide(color: selected ? const Color(0xFFC9CEEC) : BrandColors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.row),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(selected ? LucideIcons.squareCheck : LucideIcons.square, size: 22, color: selected ? BrandColors.indigo : BrandColors.slate),
                const SizedBox(width: 12),
                KindBadge(kind: kind, size: IconBadgeSize.small),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.style(14, FontWeight.w700)),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.style(12, FontWeight.w500, color: BrandColors.slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A switch with its title and a quiet line; [below] shows under it while on.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({super.key, required this.value, required this.title, required this.subtitle, required this.onChanged, this.below});

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF4F5FC) : Colors.white,
        border: Border.all(color: value ? const Color(0xFFC9CEEC) : BrandColors.line),
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Row(
              children: [
                BrandSwitch(value: value, onChanged: onChanged, label: title),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.style(15, FontWeight.w700)),
                      Text(subtitle, style: text.style(12.5, FontWeight.w500, color: BrandColors.slate, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}
