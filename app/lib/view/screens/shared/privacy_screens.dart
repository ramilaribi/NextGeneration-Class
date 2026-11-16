import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/formatting.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../stateManager/auth/auth_cubit.dart';
import '../../stateManager/auth/auth_state.dart';
import '../../stateManager/common/load_status.dart';
import '../../stateManager/privacy/privacy_cubit.dart';
import '../../widgets/brand_wordmark.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/feedback.dart';
import '../../widgets/language_toggle.dart';
import 'welcome_layout.dart';

/// The four points of the notice, short (agreement screen) or in full (privacy page).
List<(IconData, Accent, String, String)> _points(AppLocalizations l10n, {required bool full}) => [
  if (full) (LucideIcons.shieldCheck, Accent.indigo, l10n.privacyWhoTitle, l10n.privacyWho),
  (LucideIcons.database, Accent.indigo, l10n.privacyKeptTitle, full ? l10n.privacyKept : l10n.privacyKeptShort),
  if (full) (LucideIcons.fileCheck, Accent.turquoise, l10n.privacyWhyTitle, l10n.privacyWhy),
  (LucideIcons.eye, Accent.turquoise, l10n.privacySeenTitle, full ? l10n.privacySeen : l10n.privacySeenShort),
  if (full) (LucideIcons.server, Accent.amber, l10n.privacyWhereTitle, l10n.privacyWhere),
  (LucideIcons.hourglass, Accent.amber, l10n.privacyHowLongTitle, full ? l10n.privacyHowLong : l10n.privacyHowLongShort),
  (LucideIcons.hand, Accent.violet, l10n.privacyRightsTitle, full ? l10n.privacyRights : l10n.privacyRightsShort),
];

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.accent, required this.title, required this.text, this.large = false});

  final IconData icon;
  final Accent accent;
  final String title;
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = AppText.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: icon, accent: accent, size: large ? IconBadgeSize.large : IconBadgeSize.medium),
        SizedBox(width: large ? 18 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: style.style(large ? 18 : 15, large ? FontWeight.w800 : FontWeight.w700)),
              const SizedBox(height: 4),
              Text(text, style: style.style(large ? 15 : 14, FontWeight.w500, color: BrandColors.body, height: large ? 1.65 : 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A parent's first login (design `r4/AccordParents.png`): the essentials in four points, a box to tick, "Continuer".
/// Without the agreement the space stays closed; the parent can sign out and talk to the teacher.
class PrivacyAgreementScreen extends StatelessWidget {
  const PrivacyAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PrivacyAgreementCubit(sl.get())..load(),
    child: const PrivacyAgreementView(),
  );
}

class PrivacyAgreementView extends StatelessWidget {
  const PrivacyAgreementView({super.key});

  Future<void> _continue(BuildContext context) async {
    final auth = context.read<AuthCubit>();
    if (await context.read<PrivacyAgreementCubit>().accept()) auth.privacyAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<PrivacyAgreementCubit>().state;
    final cubit = context.read<PrivacyAgreementCubit>();
    final info = state.info;
    final names = info == null || info.children.isEmpty ? null : info.children.map(keptTogether).join(l10n.andSeparator);
    final teacher = info?.teacherName == null ? l10n.privacyTeacherFallback : isolated(info!.teacherName!);
    final Widget form;
    if (state.status == LoadStatus.failure && info == null) {
      form = FailureBanner(state.failure!, onRetry: cubit.load);
    } else if (info == null) {
      form = const LinearProgressIndicator(minHeight: 3);
    } else {
      form = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WelcomeTitle(
            overline: l10n.privacyOverline,
            title: names == null ? l10n.privacyAgreementTitleNone : l10n.privacyAgreementTitle(names),
            message: l10n.privacyAgreementMessage(teacher, names ?? l10n.privacyTeacherFallback.toLowerCase()),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(border: Border.all(color: BrandColors.line), borderRadius: BorderRadius.circular(AppRadii.tile)),
            child: Column(
              children: [
                for (final (i, (icon, accent, title, body)) in _points(l10n, full: false).indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _Point(icon: icon, accent: accent, title: title, text: body),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('privacy-read-all'),
              onPressed: () => context.push(Routes.privacy),
              icon: const Icon(LucideIcons.shieldCheck, size: 17, color: BrandColors.indigo),
              label: Text(l10n.privacyReadAll, style: text.style(14, FontWeight.w700, color: BrandColors.indigo)),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            checked: state.checked,
            child: Material(
              color: state.checked ? const Color(0xFFF4F5FC) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.row),
                side: BorderSide(color: state.checked ? BrandColors.indigo : BrandColors.line, width: state.checked ? 1.5 : 1),
              ),
              child: InkWell(
                key: const Key('privacy-accept'),
                onTap: () => cubit.setChecked(!state.checked),
                borderRadius: BorderRadius.circular(AppRadii.row),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        state.checked ? LucideIcons.squareCheck : LucideIcons.square,
                        size: 24,
                        color: state.checked ? BrandColors.indigo : BrandColors.slate,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          names == null ? l10n.privacyAcceptNone : l10n.privacyAccept(names),
                          style: text.style(14, FontWeight.w600, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state.failure != null) ...[const SizedBox(height: 12), FailureBanner(state.failure!)],
          const SizedBox(height: 16),
          PrimaryButton(
            key: const Key('privacy-continue'),
            label: l10n.privacyContinue,
            arrow: true,
            shadow: true,
            loading: state.sending,
            onPressed: state.checked ? () => _continue(context) : null,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(l10n.privacyDisagree, style: text.style(13, FontWeight.w500, color: BrandColors.slate)),
              TextButton.icon(
                onPressed: () => context.read<AuthCubit>().logout(),
                icon: const Icon(LucideIcons.logOutDir, size: 16, color: BrandColors.body),
                label: Text(l10n.logout, style: text.style(13, FontWeight.w700, color: BrandColors.body)),
              ),
            ],
          ),
        ],
      );
    }
    return WelcomeLayout(form: form);
  }
}

/// The notice in full (design `r4/Confidentialite.png`): from the login page, the agreement and every account menu.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      final auth = context.read<AuthCubit>().state;
      context.go(auth is AuthSignedIn ? Routes.homeOf(auth.user.role) : Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    final points = _points(l10n, full: true);
    return Scaffold(
      backgroundColor: BrandColors.chalk,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 68,
                padding: EdgeInsets.symmetric(horizontal: phone ? 12 : 32),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandColors.line))),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('privacy-back'),
                      tooltip: l10n.back,
                      onPressed: () => _back(context),
                      icon: const Icon(LucideIcons.arrowLeftDir, size: 20, color: BrandColors.ink),
                    ),
                    if (!phone) ...[const SizedBox(width: 8), const BrandWordmark(size: WordmarkSize.sidebar)],
                    const Spacer(),
                    const LanguageToggleCompact(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 24, vertical: phone ? 20 : 44),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(text.upper(l10n.privacyLink), style: text.overline(color: BrandColors.turquoise)),
                      const SizedBox(height: 10),
                      Text(l10n.privacyPageTitle, style: text.pageTitle(phone: phone)),
                      const SizedBox(height: 8),
                      Text(l10n.privacyPageSubtitle, style: text.style(16, FontWeight.w500, color: BrandColors.body, height: 1.6)),
                      const SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 30, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: BrandColors.line),
                          borderRadius: BorderRadius.circular(AppRadii.card),
                        ),
                        child: Column(
                          children: [
                            for (final (i, (icon, accent, title, body)) in points.indexed)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                decoration: BoxDecoration(
                                  border: i == 0 ? null : const Border(top: BorderSide(color: Color(0xFFF0F1F6))),
                                ),
                                child: _Point(icon: icon, accent: accent, title: title, text: body, large: !phone),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.privacyUpdated, style: text.style(13, FontWeight.w500, color: BrandColors.slate)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
