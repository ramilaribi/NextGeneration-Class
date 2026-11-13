import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/formatting.dart';
import '../../core/l10n/tunis_time.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/brand_colors.dart';
import '../../domain/model/app_notification.dart';
import '../../l10n/app_localizations.dart';
import '../stateManager/language/language_cubit.dart';
import '../stateManager/notifications/notifications_cubit.dart';
import 'buttons.dart';
import 'cards.dart';
import 'panels.dart';

/// How long an announcement stays on the families' home (spec 08); then it is only in the notifications.
const announcementOnHome = Duration(days: 7);

/// The announcements of the last 7 days, the latest first; for a parent, those about [studentId].
List<AppNotification> recentAnnouncements(List<AppNotification> items, DateTime now, {String? studentId, int max = 2}) => [
  for (final n in items)
    if (n.kind == NotificationKind.announcement &&
        now.difference(n.createdAt) < announcementOnHome &&
        (studentId == null || n.studentId == null || n.studentId == studentId))
      n,
].take(max).toList();

/// The full announcement in a window; opening it marks it read.
Future<void> openAnnouncement(BuildContext context, AppNotification n) {
  context.read<NotificationsCubit>().markRead(n);
  final l10n = AppLocalizations.of(context);
  final body = n.body ?? '';
  return showAppDialog<void>(
    context,
    builder: (dialogContext) => AppDialog(
      icon: LucideIcons.megaphone,
      title: n.title ?? '',
      subtitle: [if ((n.author ?? '').isNotEmpty) n.author!, keptTogether(n.groupName)].join(l10n.dotSeparator),
      content: Text(body, textDirection: writtenDirection(body), style: AppText.of(dialogContext).style(15, FontWeight.w500, height: 1.6)),
      actions: [PrimaryButton(label: l10n.close, height: 44, onPressed: () => Navigator.of(dialogContext).pop())],
    ),
  );
}

/// An announcement on the families' home (design `r4/AnnoncesPhone.png`): "Annonce · Ines Haddad", its title and
/// its text; a dot while unread. A tap opens it whole.
class FamilyAnnouncementCard extends StatelessWidget {
  const FamilyAnnouncementCard({super.key, required this.notification, required this.now});

  final AppNotification notification;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final n = notification;
    final body = n.body ?? '';
    final day = TunisTime.day(n.createdAt);
    final today = TunisTime.day(now);
    final when = TunisTime.sameDay(day, today)
        ? l10n.todayAt(hm(n.createdAt))
        : (TunisTime.sameDay(day, TunisTime.addDays(today, -1)) ? l10n.yesterdayAt(hm(n.createdAt)) : dayInSentence(day, language));
    final overline = [l10n.announcementLabel, if ((n.author ?? '').isNotEmpty) n.author!].join(l10n.dotSeparator);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          side: BorderSide(color: n.read ? BrandColors.line : const Color(0xFFC9CEEC), width: n.read ? 1 : 1.5),
        ),
        child: InkWell(
          key: Key('family-announcement-${n.id}'),
          borderRadius: BorderRadius.circular(AppRadii.tile),
          onTap: () => openAnnouncement(context, n),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(icon: LucideIcons.megaphone, accent: Accent.indigo, size: IconBadgeSize.small),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text.upper(overline), style: text.overline(size: 11, color: BrandColors.slate)),
                      const SizedBox(height: 2),
                      Text(n.title ?? '', style: text.style(16, FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textDirection: writtenDirection(body),
                        style: text.style(14, FontWeight.w500, color: BrandColors.body, height: 1.55),
                      ),
                      const SizedBox(height: 6),
                      Text('$when${l10n.dotSeparator}${keptTogether(n.groupName)}', style: text.small),
                    ],
                  ),
                ),
                if (!n.read) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(color: BrandColors.indigo, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The recent announcements, one under the other; nothing when there are none.
class FamilyAnnouncements extends StatelessWidget {
  const FamilyAnnouncements({super.key, required this.items, required this.now});

  final List<AppNotification> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 10), FamilyAnnouncementCard(notification: items[i], now: now)],
    ],
  );
}
