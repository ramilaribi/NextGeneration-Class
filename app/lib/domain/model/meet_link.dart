/// A visio link as a teacher types or pastes it, cleaned before it is checked (bug 2026-11-18): a phone
/// keyboard adds spaces ("https: //www.whatsapp.com") and capitals ("Https://"), and a link is often
/// pasted without its "https://". A web address never contains a space, so every space goes; a missing
/// "https://" is added, and "http://" becomes "https://" (only secure links are accepted).
String cleanMeetLink(String raw) {
  var link = raw.replaceAll(RegExp(r'\s+'), '');
  if (link.isEmpty) return '';
  final scheme = RegExp(r'^([a-zA-Z]+):/*').firstMatch(link);
  if (scheme == null) return 'https://$link';
  final name = scheme.group(1)!.toLowerCase();
  if (name == 'https' || name == 'http') return 'https://${link.substring(scheme.end)}';
  return link;
}

/// What the server accepts: an https address with something after "https://".
bool isValidMeetLink(String link) => link.startsWith('https://') && link.length > 'https://'.length + 3 && link.contains('.');
