final _number = RegExp(r'^-?\d+(\.\d+)?$');

/// Stops spreadsheet formula injection: patient names and notes come from the
/// public booking form, and Excel/Sheets execute a cell starting with
/// `= + - @` (or a tab/CR) even when it is quoted. Such cells get a leading
/// apostrophe, which spreadsheets show as plain text. Plain numbers such as
/// `-250` are left alone.
String csvSafeText(String text) {
  if (text.isEmpty || _number.hasMatch(text)) return text;
  return const ['=', '+', '-', '@', '\t', '\r'].contains(text[0])
      ? "'$text"
      : text;
}
