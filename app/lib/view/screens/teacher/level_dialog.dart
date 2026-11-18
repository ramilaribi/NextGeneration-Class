import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/model/reference.dart';
import '../../../l10n/app_localizations.dart';
import '../../stateManager/reference/reference_cubit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/feedback.dart';
import '../../widgets/panels.dart';
import '../../widgets/text_field.dart';

/// "Nouveau niveau" or, with [editing], "Modifier le niveau": a level of the teacher's own, after the six
/// primary years (French, optional Arabic). Returns the saved level, or null when cancelled.
Future<Level?> showLevelDialog(BuildContext context, {Level? editing}) {
  final reference = context.read<ReferenceCubit>();
  return showAppDialog<Level>(
    context,
    builder: (_) => BlocProvider.value(
      value: reference,
      child: _LevelDialog(editing: editing),
    ),
  );
}

class _LevelDialog extends StatefulWidget {
  const _LevelDialog({this.editing});

  final Level? editing;

  @override
  State<_LevelDialog> createState() => _LevelDialogState();
}

class _LevelDialogState extends State<_LevelDialog> {
  late String _nameFr = widget.editing?.name.fr ?? '';
  late String _nameAr = widget.editing?.name.ar ?? '';
  bool _missingName = false;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_nameFr.trim().isEmpty) {
      setState(() => _missingName = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    final draft = LevelDraft(nameFr: _nameFr, nameAr: _nameAr);
    final reference = context.read<ReferenceCubit>();
    final editing = widget.editing;
    final (level, failure) = editing == null ? await reference.createLevel(draft) : await reference.updateLevel(editing.id, draft);
    if (!mounted) return;
    if (level != null) {
      Navigator.of(context).pop(level);
    } else {
      setState(() {
        _saving = false;
        _error = failureText(l10n, failure!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      icon: widget.editing == null ? LucideIcons.layers : LucideIcons.pencil,
      title: widget.editing == null ? l10n.newLevel : l10n.editLevel,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[ErrorBanner(message: _error!), const SizedBox(height: 16)],
          FormInput(
            label: l10n.subjectNameFr,
            hint: l10n.levelNameHint,
            initialValue: _nameFr,
            autofocus: true,
            textDirection: TextDirection.ltr,
            onChanged: (v) => setState(() {
              _nameFr = v;
              _missingName = false;
            }),
            onSubmitted: (_) => _save(),
            errorText: _missingName ? l10n.fieldRequired : null,
          ),
          const SizedBox(height: 16),
          FormInput(
            label: l10n.subjectNameAr,
            labelSuffix: l10n.optional,
            hint: l10n.levelNameArExample,
            helper: l10n.subjectNameArHint,
            initialValue: _nameAr,
            textDirection: TextDirection.rtl,
            onChanged: (v) => _nameAr = v,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(context).pop()),
        PrimaryButton(label: l10n.save, height: 44, loading: _saving, onPressed: _save),
      ],
    );
  }
}
