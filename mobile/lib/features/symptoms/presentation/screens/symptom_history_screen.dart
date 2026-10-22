// Author: Saif Abdulsattar
// Contributors: Saif Abdulsattar, Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../../symptom_providers.dart';
import '../widgets/check_in_result_view.dart';

/// Read again each time the screen opens (autoDispose), and refreshed after a
/// check-in is saved, so a new check-in always shows up.
final FutureProvider<List<SymptomCheckIn>> symptomHistoryProvider =
    FutureProvider.autoDispose<List<SymptomCheckIn>>(
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
                    key: Key('checkInHistory_${entry.clientRecordId}'),
                    onTap: () => context.pushNamed(
                      AppRoutes.symptomCheckInDetail,
                      pathParameters: <String, String>{
                        'id': entry.clientRecordId,
                      },
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            DateFormatter.displayDateTime(
                              entry.measuredAt,
                              context.locale.languageCode,
                            ),
                          ),
                        ),
                        StatusChip(severity: entry.overall),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// One check-in from the history, found by its id.
final symptomCheckInByIdProvider =
    FutureProvider.autoDispose.family<SymptomCheckIn?, String>((
      Ref ref,
      String id,
    ) async {
      final List<SymptomCheckIn> all = await ref
          .watch(symptomRepositoryProvider)
          .history();
      for (final SymptomCheckIn entry in all) {
        if (entry.clientRecordId == id) return entry;
      }
      return null;
    });

/// The full results of one past check-in: every answer with its rating.
class CheckInDetailScreen extends ConsumerWidget {
  const CheckInDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SymptomCheckIn?> state = ref.watch(
      symptomCheckInByIdProvider(id),
    );
    return AppScaffold(
      title: 'symptoms.history.detailTitle'.tr(),
      scrollable: false,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(symptomCheckInByIdProvider(id)),
        ),
        data: (SymptomCheckIn? entry) => entry == null
            ? EmptyState(title: 'symptoms.history.notFound'.tr())
            : CheckInResultView(result: entry, fromHistory: true),
      ),
    );
  }
}
