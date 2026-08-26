import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/adherence.dart';
import '../controllers/adherence_controller.dart';

class AdherenceScreen extends ConsumerWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdherenceState> state = ref.watch(adherenceControllerProvider);

    return AppScaffold(
      title: 'meds.adherence.title'.tr(),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => ErrorView(
          failure: e is Failure ? e : UnknownFailure(e.toString()),
          onRetry: () => ref.invalidate(adherenceControllerProvider),
        ),
        data: (AdherenceState data) => ListView(
          children: <Widget>[
            _AdherenceCard(title: 'meds.adherence.overall7'.tr(), adherence: data.overall7),
            const SizedBox(height: AppSpacing.md),
            _AdherenceCard(title: 'meds.adherence.overall30'.tr(), adherence: data.overall30),
          ],
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.title, required this.adherence});

  final String title;
  final Adherence adherence;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: adherence.hasData
          ? Text(
              'meds.adherence.count'.tr(
                namedArgs: <String, String>{'taken': '${adherence.taken}', 'due': '${adherence.due}'},
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            )
          : Text('meds.adherence.noData'.tr()),
    );
  }
}
