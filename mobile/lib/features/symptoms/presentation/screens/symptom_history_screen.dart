import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../../symptom_providers.dart';

final FutureProvider<List<SymptomCheckIn>> symptomHistoryProvider =
    FutureProvider<List<SymptomCheckIn>>(
      (Ref ref) => ref.watch(symptomRepositoryProvider).history(),
    );

class SymptomHistoryScreen extends ConsumerWidget {
  const SymptomHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SymptomCheckIn>> state = ref.watch(
      symptomHistoryProvider,
    );

    return AppScaffold(
      title: 'symptoms.history.title'.tr(),
      scrollable: false,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(symptomHistoryProvider),
        ),
        data: (List<SymptomCheckIn> entries) => entries.isEmpty
            ? EmptyState(title: 'symptoms.history.empty'.tr())
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                itemCount: entries.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final SymptomCheckIn entry = entries[index];
                  return SectionCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          DateFormatter.displayDateTime(
                            entry.measuredAt,
                            context.locale.languageCode,
                          ),
                        ),
                        StatusChip(severity: entry.overall),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
