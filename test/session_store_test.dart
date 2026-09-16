import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/attempt_state_machine.dart';
import 'package:examseal/services/session_store.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  final openDbs = <Database>[];

  // FFI menyimpan database single-instance per path; menutupnya di akhir
  // tiap test memastikan :memory: berikutnya benar-benar baru.
  Future<SessionStore> newStore() async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    openDbs.add(db);
    return SessionStore.open(db);
  }

  tearDown(() async {
    for (final db in openDbs) {
      if (db.isOpen) await db.close();
    }
    openDbs.clear();
  });

  final session = ExamSession(
    schemaVersion: 2,
    sessionId: 'session-1',
    sessionCode: 'MTK-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
    pinSalt: 'c2FsdA==',
    pinVerifier: 'dmVyaWZpZXI=',
    createdAt: DateTime.utc(2026, 9, 13, 8),
  );

  test('saving an attempt persists before the UI can depend on it', () async {
    final store = await newStore();
    await store.saveSession(session);
    await store.startAttempt(session, attemptNumber: 1);

    final restored = await store.loadCurrentAttempt();
    expect(restored, isNotNull);
    expect(restored!.state, AttemptState.active);
    expect(restored.attemptNumber, 1);
    expect(restored.session!.sessionId, 'session-1');
    expect(restored.violationCount, 0);
  });

  test('mutasi Form ditolak atomik saat attempt sudah dimulai', () async {
    final store = await newStore();
    await store.saveSession(session);
    await store.startAttempt(session, attemptNumber: 1);

    await expectLater(
      store.beginFormTest(session, DateTime.now()),
      throwsA(isA<StorageFailure>()),
    );
  });

  test(
    'scan serentak dengan ID sama tidak menerima konfigurasi yang berbeda',
    () async {
      final store = await newStore();
      final other = ExamSession(
        schemaVersion: 2,
        sessionId: session.sessionId,
        sessionCode: session.sessionCode,
        examName: session.examName,
        formUrl: Uri.parse('https://forms.gle/other'),
        pinSalt: session.pinSalt,
        pinVerifier: session.pinVerifier,
      );
      await store.saveSession(session);
      await expectLater(
        store.saveSession(other),
        throwsA(isA<StorageFailure>()),
      );
      expect(
        (await store.loadSession(session.sessionId))!.formUrl,
        session.formUrl,
      );
      expect(await store.listSessions(), hasLength(1));
    },
  );

  test(
    'violations persist so reopening the app cannot reset the counter',
    () async {
      final store = await newStore();
      await store.saveSession(session);
      final attemptId = await store.startAttempt(session, attemptNumber: 1);

      await store.recordEvent(
        attemptId: attemptId,
        eventType: 'appLeftWhileActive',
        countedAsViolation: true,
        counterAfter: 1,
      );
      await store.setAttemptState(
        attemptId,
        AttemptState.locked,
        violationCount: 3,
      );

      final restored = await store.loadCurrentAttempt();
      expect(restored!.state, AttemptState.locked);
      expect(restored.violationCount, 3);
      expect(restored.events.single.countedAsViolation, isTrue);
      expect(restored.events.single.counterAfter, 1);
    },
  );

  test('retention only deletes ended attempts older than seven days', () async {
    final store = await newStore();

    // Attempt aktif dan terkunci tidak boleh terhapus walau tua.
    await store.saveSession(session);
    final activeId = await store.startAttempt(session, attemptNumber: 1);
    await store.setAttemptState(
      activeId,
      AttemptState.active,
      violationCount: 1,
    );

    final oldSession = ExamSession(
      schemaVersion: 2,
      sessionId: 'session-old',
      sessionCode: 'OLD-1234',
      examName: 'Ujian Lama',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/old/viewform'),
      pinSalt: 'c2FsdA==',
      pinVerifier: 'dmVyaWZpZXI=',
      createdAt: DateTime.utc(2026, 9, 1),
    );
    await store.saveSession(oldSession);
    final endedId = await store.startAttempt(oldSession, attemptNumber: 1);
    await store.setAttemptState(endedId, AttemptState.ended, violationCount: 0);
    // endedAt 10 hari lalu.
    await store.setAttemptEndedAt(
      endedId,
      DateTime.now().subtract(const Duration(days: 10)),
    );
    await store.setAttemptUpdatedAt(
      endedId,
      DateTime.now().subtract(const Duration(days: 10)),
    );

    final deleted = await store.runRetention(now: DateTime.now());
    expect(deleted, contains(endedId));
    expect(deleted, isNot(contains(activeId)));

    final remaining = await store.loadCurrentAttempt();
    expect(remaining, isNotNull);
    expect(remaining!.attemptId, activeId);
  });

  test(
    'retention keeps an ended attempt with pending protection restore',
    () async {
      final store = await newStore();
      await store.saveSession(session);
      final attemptId = await store.startAttempt(session, attemptNumber: 1);
      await store.setAttemptState(
        attemptId,
        AttemptState.ended,
        violationCount: 0,
      );
      await store.setAttemptEndedAt(
        attemptId,
        DateTime.now().subtract(const Duration(days: 10)),
      );
      await store.saveProtectionState(
        attemptId: attemptId,
        secureWindowActive: true,
        notificationProtectionActive: true,
        notificationAccessGranted: true,
        restorePending: true,
      );

      final deleted = await store.runRetention(now: DateTime.now());

      expect(deleted, isNot(contains(attemptId)));
      expect(await store.hasPendingRestore(), isTrue);
    },
  );

  test(
    'a failed write surfaces an actionable error instead of a trusted new state',
    () async {
      final db = await factory.openDatabase(inMemoryDatabasePath);
      openDbs.add(db);
      final store = await SessionStore.open(db);
      await db.close();

      expect(() => store.saveSession(session), throwsA(isA<StorageFailure>()));
    },
  );

  test(
    'repeat by supervisor creates a fresh attempt while old history stays',
    () async {
      final store = await newStore();
      await store.saveSession(session);
      final first = await store.startAttempt(session, attemptNumber: 1);
      await store.setAttemptState(first, AttemptState.ended, violationCount: 3);

      final second = await store.startAttempt(session, attemptNumber: 2);
      expect(second, isNot(first));

      final current = await store.loadCurrentAttempt();
      expect(current!.attemptNumber, 2);
      expect(current.violationCount, 0);
      expect(current.state, AttemptState.active);

      final history = await store.loadAttemptsFor('session-1');
      expect(history.map((a) => a.attemptId), containsAll([first, second]));
      expect(history.length, 2);
    },
  );

  test('teacher sessions round-trip and can be listed again', () async {
    final store = await newStore();
    await store.saveSession(session);

    final sessions = await store.listSessions();
    expect(sessions.length, 1);
    expect(sessions.first.sessionId, 'session-1');
    expect(sessions.first.sessionCode, 'MTK-7K2P');
    expect(sessions.first.pinVerifier, 'dmVyaWZpZXI=');

    // Sesi konsisten: tidak ada duplikat saat disimpan ulang.
    await store.saveSession(session);
    expect((await store.listSessions()).length, 1);
  });
}
