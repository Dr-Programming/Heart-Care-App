/// The shared widget kit.
///
/// Import this one file rather than reaching for individual widgets:
/// `import '../../../core/widgets/widgets.dart';`
///
/// Anything a second feature would want belongs here, not in a feature's
/// `presentation/widgets/` folder — but adding to the kit is a change to
/// shared code, so raise it with the maintainer instead of pushing it on a
/// feature branch. Widgets that only ever make sense inside one feature
/// (a PIN pad, a chart legend, a dose row) stay in that feature.
library;

export 'app_button.dart';
export 'app_scaffold.dart';
export 'app_text_field.dart';
export 'cards.dart';
export 'confirm_sheet.dart';
export 'offline_banner.dart';
export 'state_views.dart';
export 'status_chip.dart';
