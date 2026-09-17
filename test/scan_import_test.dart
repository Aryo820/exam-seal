import 'dart:io';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/attempt_state_machine.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  ExamSession session(String id, {String name = 'Matematika'}) => ExamSession(
    schemaVersion: 2,
    sessionId: id,
    sessionCode: 'MTK-1234',
    examName: name,
    formUrl: Uri.parse('https://forms.gle/example'),
  );
  ExamSessionController controller(SessionStore store) =>
      ExamSessionController(store: store, now: DateTime.now);
  late Database db;
  late SessionStore store;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = await SessionStore.open(db);
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
  });

  test(
    'scan ganda tersimpan sekali dan pra-ujian tetap menahan proteksi yang belum terbukti',
    () async {
      final app = controller(store);
      final scanned = session('siswa');
      final results = await Future.wait([
        app.importScannedSession(scanned),
        app.importScannedSession(scanned),
      ]);
      expect(results.every((r) => r.route == ScanImportRoute.preExam), isTrue);
      expect(await store.listSessions(), hasLength(1));
      expect(await store.loadCurrentAttempt(), isNull);
      expect(await app.listTeacherSessions(), hasLength(1));
      final ready = await app.assessReadiness(scanned);
      expect(ready.qrValid && ready.urlValid && ready.storageWritable, isTrue);
      expect(ready.allMandatoryPassed, isFalse);
      final conflict = await app.importScannedSession(
        session('siswa', name: 'Ujian palsu'),
      );
      expect(conflict.error, isNotNull);
      expect((await store.loadSession('siswa'))!.examName, 'Matematika');
    },
  );

  test(
    'scan tidak menulis sesi pengganti ketika percobaan aktif, terkunci, atau pemulihan',
    () async {
      final app = controller(store);
      final original = session('lama');
      await app.importScannedSession(original);
      final attempt = await store.startAttempt(original, attemptNumber: 1);
      for (final state in [
        AttemptState.active,
        AttemptState.locked,
        AttemptState.recoveryPending,
      ]) {
        await store.setAttemptState(attempt, state, violationCount: 3);
        expect(
          (await app.importScannedSession(session('baru'))).error,
          isNotNull,
        );
        expect(await store.loadSession('baru'), isNull);
        expect(
          (await app.importScannedSession(original)).route,
          ScanImportRoute.storedAttempt,
        );
        expect((await store.loadCurrentAttempt())!.state, state);
      }
      await store.setAttemptState(
        attempt,
        AttemptState.ended,
        violationCount: 3,
      );
      expect(
        (await app.importScannedSession(original)).route,
        ScanImportRoute.endedNeedsConfirmation,
      );
    },
  );

  test(
    'storage baca-saja menolak scan dan tidak dinyatakan siap menulis',
    () async {
      final app = controller(store);
      await app.importScannedSession(session('ada'));
      await db.execute('PRAGMA query_only = ON');
      await expectLater(
        app.importScannedSession(session('baru')),
        throwsA(isA<StorageFailure>()),
      );
      expect(await store.loadSession('baru'), isNull);
      expect(
        (await app.assessReadiness(session('ada'))).storageWritable,
        isFalse,
      );
    },
  );

  test('impor membaca kembali percobaan yang dimulai bersamaan', () async {
    final scanned = session('bersamaan');
    await store.saveSession(scanned);
    final incoming = controller(store).importScannedSession(scanned);
    await store.startAttempt(scanned, attemptNumber: 1);
    expect((await incoming).route, ScanImportRoute.storedAttempt);
  });

  test('hasil scan dan QR tetap sama setelah database dibuka ulang', () async {
    final dir = await Directory.systemTemp.createTemp('examseal-scan-');
    final path = '${dir.path}/session.db';
    final firstDb = await databaseFactoryFfi.openDatabase(path);
    final first = controller(await SessionStore.open(firstDb));
    final scanned = session('persist');
    await first.importScannedSession(scanned);
    final qr = first.encodeQr(scanned);
    await firstDb.close();
    final reopened = await databaseFactoryFfi.openDatabase(path);
    try {
      final saved = await SessionStore.open(reopened);
      expect(
        controller(saved).encodeQr((await saved.loadSession('persist'))!),
        qr,
      );
      expect(await saved.loadAttemptsFor('persist'), isEmpty);
    } finally {
      await reopened.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await dir.delete();
    }
  });
}
