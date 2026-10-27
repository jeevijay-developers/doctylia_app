import 'package:doctylia_app/core/platform/csv_cell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('neutralises spreadsheet formulas', () {
    for (final input in [
      '=HYPERLINK("http://x","click")',
      '+1+1',
      '-2+3',
      '@SUM(A1)',
      '\t=1',
      '\r=1',
    ]) {
      expect(csvSafeText(input), "'$input");
    }
  });

  test('leaves ordinary values alone', () {
    for (final input in ['', 'Riya Sharma', '9876543210', '-250', '12.5']) {
      expect(csvSafeText(input), input);
    }
  });
}
