import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/block.dart';

/// Renders any [ContentBlock] — the one renderer design decision 5 asks
/// for, so a new topic never needs a new widget, only new JSON.
///
/// [onOpenLink] fires with a [ReferenceLinkBlock]'s URL when tapped. There
/// is no `url_launcher` (or equivalent) dependency declared in
/// `pubspec.yaml` yet — that's a second, separate blocker from the
/// `assets/content/` one, and adding a dependency there is the
/// maintainer's call, not something to add on this branch. Until it lands,
/// callers should treat a link tap as "copy the URL" rather than "open it".
class BlockRenderer extends StatelessWidget {
  const BlockRenderer({required this.block, this.onOpenLink, super.key});

  final ContentBlock block;
  final ValueChanged<String>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final ContentBlock block = this.block;
    return switch (block) {
      ParagraphBlock() => _Paragraph(block),
      BulletListBlock() => _BulletList(block),
      CalloutBlock() => _Callout(block),
      ReferenceLinkBlock() => _ReferenceLink(block, onTap: onOpenLink),
    };
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.block);

  final ParagraphBlock block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(block.text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.block);

  final BulletListBlock block;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String item in block.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('•  ', style: text.bodyLarge),
                  Expanded(child: Text(item, style: text.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout(this.block);

  final CalloutBlock block;

  bool get _isWarning => block.tone == CalloutTone.warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _isWarning ? AppColors.warningBg : AppColors.accentBg,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            _isWarning
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: _isWarning ? AppColors.warning : AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              block.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceLink extends StatelessWidget {
  const _ReferenceLink(this.block, {required this.onTap});

  final ReferenceLinkBlock block;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(block.url),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                block.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
