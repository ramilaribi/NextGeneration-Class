import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_language.dart';
import '../../../../core/l10n/formatting.dart';
import '../../../../core/l10n/tunis_time.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/announcement.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stateManager/announcements/announcements_cubit.dart';
import '../../../stateManager/common/load_status.dart';
import '../../../stateManager/groups/groups_cubit.dart';
import '../../../stateManager/language/language_cubit.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/classmates.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/page_frame.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/school_widgets.dart';
import 'new_announcement_panel.dart';

/// Annonces (Release 4, design `r4/Annonces.png`): what the teacher sent, to whom, and how many read it.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => AnnouncementsCubit(sl.get())..load(), child: const AnnouncementsView());
}

String audienceLabel(AppLocalizations l10n, Audience audience) => switch (audience) {
  Audience.pupils => l10n.audiencePupils,
  Audience.parents => l10n.audienceParents,
  Audience.both => l10n.audienceBoth,
};

Accent audienceAccent(Audience audience) => switch (audience) {
  Audience.pupils => Accent.amber,
  Audience.parents => Accent.turquoise,
  Audience.both => Accent.indigo,
};

/// "Aujourd'hui à 09:12", "Hier à 18:40", then the day.
String sentWhen(AppLocalizations l10n, AppLanguage language, DateTime instant, DateTime now) {
  final day = TunisTime.day(instant);
  final today = TunisTime.day(now);
  if (TunisTime.sameDay(day, today)) return l10n.todayAt(hm(instant));
  if (TunisTime.sameDay(day, TunisTime.addDays(today, -1))) return l10n.yesterdayAt(hm(instant));
  return dayInSentence(day, language);
}

class AnnouncementsView extends StatelessWidget {
  const AnnouncementsView({super.key});

  static Future<void> _new(BuildContext context) async {
    final cubit = context.read<AnnouncementsCubit>();
    final sent = await NewAnnouncementPanel.open(context, groupId: cubit.state.groupId);
    if (sent == null) return;
    cubit.sent(sent);
    if (context.mounted) showNotice(context, AppLocalizations.of(context).announcementSent(sent.recipients));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final phone = isPhone(context);
    final state = context.watch<AnnouncementsCubit>().state;
    final cubit = context.read<AnnouncementsCubit>();
    final groups = context.watch<GroupsCubit>().state.regular;

    final header = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 16,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.navAnnouncements, style: text.pageTitle(phone: phone)),
              const SizedBox(height: 6),
              Text(l10n.announcementsSubtitle, style: text.style(15, FontWeight.w500, color: BrandColors.body, height: 1.5)),
            ],
          ),
        ),
        PrimaryButton(
          key: const Key('new-announcement'),
          label: phone ? l10n.newAnnouncementShort : l10n.newAnnouncement,
          icon: LucideIcons.plus,
          height: 44,
          onPressed: () => _new(context),
        ),
      ],
    );

    final List<Widget> body;
    if (state.status == LoadStatus.failure && state.items.isEmpty) {
      body = [FailureBanner(state.failure!, onRetry: cubit.load)];
    } else if (state.status == LoadStatus.loading && state.items.isEmpty) {
      body = [const LinearProgressIndicator(minHeight: 3)];
    } else if (state.items.isEmpty) {
      body = [
        SectionCard(
          child: EmptyState(
            message: l10n.announcementsEmptyTitle,
            scale: 0.5,
            action: Column(
              children: [
                Text(
                  l10n.announcementsEmptyHint,
                  textAlign: TextAlign.center,
                  style: text.style(13, FontWeight.w500, color: BrandColors.slate, height: 1.5),
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: l10n.newAnnouncement, icon: LucideIcons.plus, height: 44, onPressed: () => _new(context)),
              ],
            ),
          ),
        ),
      ];
    } else {
      final visible = state.visible;
      body = [
        if (groups.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: PillTabs<String?>(
              items: [
                TabItem(null, l10n.allLabel, count: state.items.length),
                for (final g in groups) TabItem(g.id, g.name),
              ],
              value: state.groupId,
              onChanged: cubit.showGroup,
            ),
          ),
        if (visible.isEmpty)
          Text(l10n.announcementsNoneForGroup, style: text.small)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                FadeRise(
                  index: i,
                  child: AnnouncementCard(announcement: visible[i]),
                ),
              ],
            ],
          ),
      ];
    }
    return PageScroll(children: [header, ...body]);
  }
}

/// One announcement: what it says, who it went to, when, and how many read it.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement});

  final Announcement announcement;

  Future<void> _unread(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AnnouncementsCubit>();
    try {
      final people = await cubit.unread(announcement);
      if (!context.mounted) return;
      await showSidePanel<void>(
        context,
        width: 460,
        builder: (panelContext) => SidePanel(
          icon: LucideIcons.eyeOff,
          title: l10n.notReadYet,
          subtitle: announcement.title,
          actions: [PrimaryButton(label: l10n.close, height: 44, onPressed: () => Navigator.of(panelContext).pop())],
          body: people.isEmpty
              ? Text(l10n.everyoneRead, style: AppText.of(panelContext).style(15, FontWeight.w600, color: Accent.green.onSoft))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final p in people)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            InitialsAvatar(
                              initials: '${p.firstName.isEmpty ? '' : p.firstName[0]}${p.lastName.isEmpty ? '' : p.lastName[0]}'.toUpperCase(),
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.fullName, style: AppText.of(panelContext).style(15, FontWeight.w700)),
                                  Text(p.parent ? l10n.parentOf(p.childFirstName ?? '') : l10n.pupilRole, style: AppText.of(panelContext).small),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      );
    } on Object catch (error) {
      if (context.mounted) showNotice(context, failureText(l10n, ApiFailure.from(error)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmAction(
      context,
      title: l10n.deleteAnnouncementTitle,
      text: l10n.deleteAnnouncementText,
      confirmLabel: l10n.delete,
      icon: LucideIcons.trash2,
    );
    if (!ok || !context.mounted) return;
    final failure = await context.read<AnnouncementsCubit>().delete(announcement);
    if (context.mounted) showNotice(context, failure == null ? l10n.announcementDeleted : failureText(l10n, failure));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final phone = isPhone(context);
    final a = announcement;
    final when = sentWhen(l10n, language, a.createdAt, sl.get<Now>()());
    final targets = Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final t in a.targets)
          if (t.group != null)
            GroupLabel(code: t.group!.code, color: t.group!.color, name: t.group!.name)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.user, size: 15, color: Color(0xFF7048E8)),
                const SizedBox(width: 6),
                Text(t.label, style: text.style(13, FontWeight.w600)),
              ],
            ),
        Text(when, style: text.style(12.5, FontWeight.w600, color: BrandColors.slate)),
      ],
    );
    final read = _ReadBar(read: a.read, total: a.recipients);
    final menu = MenuAnchor(
      menuChildren: [
        MenuItemButton(leadingIcon: const Icon(LucideIcons.eyeOff, size: 16), onPressed: () => _unread(context), child: Text(l10n.notReadYet)),
        if (a.deletable)
          MenuItemButton(
            leadingIcon: Icon(LucideIcons.trash2, size: 16, color: Accent.red.onSoft),
            onPressed: () => _delete(context),
            child: Text(l10n.delete, style: TextStyle(color: Accent.red.onSoft)),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        key: Key('announcement-menu-${a.id}'),
        tooltip: l10n.announcementActions,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(LucideIcons.ellipsis, size: 20, color: BrandColors.slate),
      ),
    );
    return Container(
      padding: EdgeInsets.all(phone ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: BrandColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: LucideIcons.megaphone, accent: Accent.indigo, size: phone ? IconBadgeSize.small : IconBadgeSize.large),
          SizedBox(width: phone ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(a.title, style: text.style(16, FontWeight.w800)),
                    StatusChip(label: audienceLabel(l10n, a.audience), accent: audienceAccent(a.audience)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  a.body,
                  textDirection: writtenDirection(a.body),
                  style: text.style(14, FontWeight.w500, color: BrandColors.body, height: 1.55),
                ),
                const SizedBox(height: 8),
                targets,
                if (phone) ...[const SizedBox(height: 10), read],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              menu,
              if (!phone) ...[const SizedBox(height: 8), SizedBox(width: 180, child: read)],
            ],
          ),
        ],
      ),
    );
  }
}

/// "9 / 14 lus" with its turquoise bar.
class _ReadBar extends StatelessWidget {
  const _ReadBar({required this.read, required this.total});

  final int read;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : read / total,
              minHeight: 6,
              backgroundColor: BrandColors.line,
              color: BrandColors.turquoise,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          l10n.readCount(read, total),
          key: const Key('read-count'),
          textDirection: TextDirection.ltr,
          style: AppText.of(context).style(12.5, FontWeight.w700),
        ),
      ],
    );
  }
}
