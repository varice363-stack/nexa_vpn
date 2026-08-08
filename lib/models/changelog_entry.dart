/// Changelog release entry (static content).
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.notes,
  });

  final String version;
  final String date;
  final List<String> notes;
}
