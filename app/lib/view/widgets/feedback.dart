import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/brand_colors.dart';
import '../../l10n/app_localizations.dart';
import 'cards.dart';

/// The text to show for a failure: the server's message (already in the app language),
/// or the app's own wording for local problems.
String failureText(AppLocalizations l10n, ApiFailure failure) {
  if (failure.isNetwork) return l10n.errorNetwork;
  return failure.message ?? l10n.errorUnknown;
}

class FailureBanner extends StatelessWidget {
  const FailureBanner(this.failure, {super.key, this.onRetry});

  final ApiFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ErrorBanner(message: failureText(l10n, failure), onRetry: onRetry, retryLabel: l10n.retry);
  }
}

/// "Cette section arrive avec une prochaine version": for actions whose release has not come yet.
void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).comingSoonMessage)));
}

/// Shown in a release build in place of a part of a screen that failed to build, instead of an empty grey box.
/// It may sit outside the app's localizations (a failure high in the tree): then it shows the icon only.
class BrokenPart extends StatelessWidget {
  const BrokenPart({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 18, color: Accent.amber.strong),
            if (l10n != null) ...[
              const SizedBox(width: 8),
              Flexible(child: Text(l10n.errorDisplay, style: const TextStyle(fontSize: 13, color: BrandColors.slate))),
            ],
          ],
        ),
      ),
    );
  }
}
