import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/formatting.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/announcement.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stateManager/announcements/announcement_form_cubit.dart';
import '../../../stateManager/auth/auth_cubit.dart';
import '../../../stateManager/groups/groups_cubit.dart';
import '../../../stateManager/students/students_cubit.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/school_widgets.dart';
import '../../../widgets/text_field.dart';
import 'announcements_screen.dart' show audienceLabel;

/// "Nouvelle annonce" (Release 4, design `r4/NouvelleAnnonce.png`): for groups or one pupil, read by the pupils,
/// the parents or both, a title and a message, with what families will see. Sent at once.
class NewAnnouncementPanel extends StatelessWidget {
  const NewAnnouncementPanel({super.key});

  /// [groupId]: the group already chosen (the tab open in Annonces).
  static Future<Announcement?> open(BuildContext context, {String? groupId}) {
    final groups = context.read<GroupsCubit>();
    return showSidePanel<Announcement>(
      context,
      width: 540,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: groups),
          BlocProvider(create: (_) => AnnouncementFormCubit(sl.get(), groupId: groupId)),
          BlocProvider(create: (_) => sl.get<StudentsCubit>()..load()),
        ],
        child: const NewAnnouncementPanel(),
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final sent = await context.read<AnnouncementFormCubit>().send();
    if (sent != null && context.mounted) Navigator.of(context).pop(sent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<AnnouncementFormCubit>().state;
    final cubit = context.read<AnnouncementFormCubit>();
    final groups = context.watch<GroupsCubit>().state.groups;
    final students = context.watch<StudentsCubit>().state.students;
    final errors = state.errors;
    final teacher = context.read<AuthCubit>().user;
    final quiet = text.style(12.5, FontWeight.w500, color: BrandColors.slate);

    final recipients = state.toOnePupil
        ? SelectField<String>(
            key: const Key('announcement-pupil'),
            hint: l10n.choosePupil,
            value: state.studentId,
            onChanged: cubit.setStudent,
            errorText: errors.contains(AnnouncementFormError.recipients) ? l10n.chooseRecipients : null,
            options: [for (final s in students) SelectOption(s.id, '${s.firstName} ${s.lastName}')],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in groups) ...[
                _GroupChoice(
                  key: Key('announcement-group-${g.id}'),
                  code: g.code,
                  color: g.color,
                  name: g.name,
                  count: g.memberCount,
                  selected: state.groupIds.contains(g.id),
                  onTap: () => cubit.toggleGroup(g.id),
                ),
                const SizedBox(height: 8),
              ],
              if (errors.contains(AnnouncementFormError.recipients))
                Text(l10n.chooseRecipients, style: text.style(12.5, FontWeight.w600, color: Accent.red.onSoft)),
            ],
          );

    final title = state.title.trim().isEmpty ? l10n.announcementTitleHint : state.title.trim();
    final body = state.body.trim().isEmpty ? l10n.announcementBodyHint : state.body.trim();
    final preview = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.chalk,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: const Color(0xFFC9CEEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.upper(switch (state.audience) {
              Audience.pupils => l10n.previewForPupils,
              Audience.parents => l10n.previewForParents,
              Audience.both => l10n.previewForFamilies,
            }),
            style: text.overline(size: 11, color: BrandColors.slate),
          ),
          const SizedBox(height: 8),
          AnnouncementPreview(title: title, body: body, author: teacher == null ? '' : '${teacher.firstName} ${teacher.lastName}'),
        ],
      ),
    );

    return SidePanel(
      icon: LucideIcons.megaphone,
      title: l10n.newAnnouncement,
      subtitle: l10n.newAnnouncementSubtitle,
      actions: [
        GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(context).pop()),
        PrimaryButton(
          key: const Key('send-announcement'),
          label: l10n.sendAnnouncement,
          icon: LucideIcons.send,
          height: 44,
          loading: state.sending,
          onPressed: () => _send(context),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.failure != null) ...[FailureBanner(state.failure!), const SizedBox(height: 16)],
          LabeledField(
            label: l10n.announcementFor,
            child: SegmentedChoice<bool>(
              value: state.toOnePupil,
              onChanged: cubit.setOnePupil,
              options: [SelectOption(false, l10n.someGroups), SelectOption(true, l10n.onePupil)],
            ),
          ),
          const SizedBox(height: 10),
          recipients,
          const SizedBox(height: 18),
          LabeledField(
            label: l10n.announcementAudience,
            child: SegmentedChoice<Audience>(
              value: state.audience,
              onChanged: cubit.setAudience,
              options: [for (final a in Audience.values) SelectOption(a, audienceLabel(l10n, a))],
            ),
          ),
          const SizedBox(height: 6),
          Text(state.audience == Audience.parents ? l10n.parentsOnlyHint : l10n.pupilsNeedLoginHint, style: quiet),
          const SizedBox(height: 18),
          FormInput(
            key: const Key('announcement-title'),
            label: l10n.titleLabel,
            hint: l10n.announcementTitleHint,
            initialValue: state.title,
            onChanged: cubit.setTitle,
            errorText: errors.contains(AnnouncementFormError.title) ? l10n.fieldRequired : null,
          ),
          const SizedBox(height: 16),
          FormInput(
            key: const Key('announcement-body'),
            label: l10n.messageLabel,
            hint: l10n.announcementBodyHint,
            initialValue: state.body,
            maxLines: 5,
            onChanged: cubit.setBody,
            errorText: errors.contains(AnnouncementFormError.body) ? l10n.fieldRequired : null,
          ),
          const SizedBox(height: 18),
          preview,
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info, size: 15, color: BrandColors.slate),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.announcementOneWayNote, style: quiet)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupChoice extends StatelessWidget {
  const _GroupChoice({
    super.key,
    required this.code,
    required this.color,
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String color;
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFF4F5FC) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: selected ? const Color(0xFFC9CEEC) : BrandColors.line),
            ),
            child: Row(
              children: [
                Icon(selected ? LucideIcons.squareCheck : LucideIcons.square, size: 21, color: selected ? BrandColors.indigo : BrandColors.slate),
                const SizedBox(width: 12),
                GroupSquare(code: code, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.style(14, FontWeight.w600)),
                ),
                Text(l10n.pupilsCount(count), style: text.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An announcement as families see it: the megaphone, its title, its text, who wrote it.
class AnnouncementPreview extends StatelessWidget {
  const AnnouncementPreview({super.key, required this.title, required this.body, required this.author});

  final String title;
  final String body;
  final String author;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: LucideIcons.megaphone, accent: Accent.indigo, size: IconBadgeSize.small),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.style(15, FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textDirection: writtenDirection(body),
                  style: text.style(13, FontWeight.w500, color: BrandColors.body, height: 1.45),
                ),
                if (author.isNotEmpty) ...[const SizedBox(height: 6), Text(author, style: text.small)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
