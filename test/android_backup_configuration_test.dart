import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup dan transfer Android mengecualikan seluruh data ExamSeal', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final legacyRules = File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsStringSync();
    final currentRules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    for (final rules in [legacyRules, currentRules]) {
      expect(rules, contains('domain="root" path="."'));
      expect(rules, contains('domain="database" path="."'));
      expect(rules, contains('domain="sharedpref" path="."'));
    }
    expect(currentRules, contains('<cloud-backup>'));
    expect(currentRules, contains('<device-transfer>'));
  });
}
