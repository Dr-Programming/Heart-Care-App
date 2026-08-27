/// One entry in the bundled common-medications list used to power
/// [MedicationSearchScreen]'s suggestions (Decision A of
/// docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md). Not a real
/// drug database — no such catalog exists in the backend or database. Picking
/// a suggestion only pre-fills the add/edit form; saving still goes through
/// the unchanged repository/sync path.
class MedicationLibraryEntry {
  const MedicationLibraryEntry({
    required this.name,
    required this.doseMg,
    required this.drugClass,
    this.mostCommon = false,
  });

  final String name;
  final double doseMg;
  final String drugClass;

  /// Soft hint only — the single most-likely dose for this drug, shown
  /// first and highlighted (Figma's pale-blue top-suggestion row).
  final bool mostCommon;
}

const List<MedicationLibraryEntry> kMedicationLibrary = <MedicationLibraryEntry>[
  MedicationLibraryEntry(name: 'Metoprolol', doseMg: 25, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Metoprolol', doseMg: 50, drugClass: 'Beta-blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Metoprolol', doseMg: 100, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Bisoprolol', doseMg: 2.5, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Bisoprolol', doseMg: 5, drugClass: 'Beta-blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Carvedilol', doseMg: 6.25, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Carvedilol', doseMg: 12.5, drugClass: 'Beta-blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Atorvastatin', doseMg: 10, drugClass: 'Statin'),
  MedicationLibraryEntry(name: 'Atorvastatin', doseMg: 20, drugClass: 'Statin', mostCommon: true),
  MedicationLibraryEntry(name: 'Atorvastatin', doseMg: 40, drugClass: 'Statin'),
  MedicationLibraryEntry(name: 'Rosuvastatin', doseMg: 10, drugClass: 'Statin', mostCommon: true),
  MedicationLibraryEntry(name: 'Rosuvastatin', doseMg: 20, drugClass: 'Statin'),
  MedicationLibraryEntry(name: 'Aspirin', doseMg: 75, drugClass: 'Antiplatelet', mostCommon: true),
  MedicationLibraryEntry(name: 'Aspirin', doseMg: 100, drugClass: 'Antiplatelet'),
  MedicationLibraryEntry(name: 'Clopidogrel', doseMg: 75, drugClass: 'Antiplatelet', mostCommon: true),
  MedicationLibraryEntry(name: 'Lisinopril', doseMg: 5, drugClass: 'ACE inhibitor'),
  MedicationLibraryEntry(name: 'Lisinopril', doseMg: 10, drugClass: 'ACE inhibitor', mostCommon: true),
  MedicationLibraryEntry(name: 'Lisinopril', doseMg: 20, drugClass: 'ACE inhibitor'),
  MedicationLibraryEntry(name: 'Ramipril', doseMg: 2.5, drugClass: 'ACE inhibitor'),
  MedicationLibraryEntry(name: 'Ramipril', doseMg: 5, drugClass: 'ACE inhibitor', mostCommon: true),
  MedicationLibraryEntry(name: 'Losartan', doseMg: 50, drugClass: 'ARB', mostCommon: true),
  MedicationLibraryEntry(name: 'Losartan', doseMg: 100, drugClass: 'ARB'),
  MedicationLibraryEntry(name: 'Amlodipine', doseMg: 5, drugClass: 'Calcium channel blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Amlodipine', doseMg: 10, drugClass: 'Calcium channel blocker'),
  MedicationLibraryEntry(name: 'Furosemide', doseMg: 20, drugClass: 'Diuretic'),
  MedicationLibraryEntry(name: 'Furosemide', doseMg: 40, drugClass: 'Diuretic', mostCommon: true),
  MedicationLibraryEntry(name: 'Spironolactone', doseMg: 25, drugClass: 'Diuretic', mostCommon: true),
  MedicationLibraryEntry(name: 'Warfarin', doseMg: 1, drugClass: 'Anticoagulant'),
  MedicationLibraryEntry(name: 'Warfarin', doseMg: 5, drugClass: 'Anticoagulant', mostCommon: true),
  MedicationLibraryEntry(name: 'Digoxin', doseMg: 0.125, drugClass: 'Cardiac glycoside', mostCommon: true),
  MedicationLibraryEntry(name: 'Nitroglycerin', doseMg: 0.4, drugClass: 'Nitrate (GTN spray)', mostCommon: true),
  MedicationLibraryEntry(name: 'Isosorbide mononitrate', doseMg: 30, drugClass: 'Nitrate', mostCommon: true),
];

/// Case-insensitive substring match on [MedicationLibraryEntry.name].
/// Most-common entries first, then alphabetical by name, then by dose.
/// An empty/blank query returns nothing — the search screen only shows
/// suggestions once the user has typed something.
List<MedicationLibraryEntry> searchMedicationLibrary(String query) {
  final String trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return const <MedicationLibraryEntry>[];

  final List<MedicationLibraryEntry> matches = kMedicationLibrary
      .where((MedicationLibraryEntry e) => e.name.toLowerCase().contains(trimmed))
      .toList();

  matches.sort((MedicationLibraryEntry a, MedicationLibraryEntry b) {
    if (a.mostCommon != b.mostCommon) return a.mostCommon ? -1 : 1;
    final int nameCompare = a.name.compareTo(b.name);
    if (nameCompare != 0) return nameCompare;
    return a.doseMg.compareTo(b.doseMg);
  });

  return matches;
}
