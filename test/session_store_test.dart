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
    'retention menjaga batas tujuh hari, state penahan, dan sesi bersama',
    () async {
      final store = await newStore();
      final now = DateTime.utc(2026, 9, 16, 12);
      await store.saveSession(session);

      final exactBoundary = await store.startAttempt(session, attemptNumber: 1);
      await store.setAttemptState(
        exactBoundary,
        AttemptState.ended,
        violationCount: 0,
      );
      await store.setAttemptEndedAt(
        exactBoundary,
        now.subtract(const Duration(days: 7)),
      );

      final expired = await store.startAttempt(session, attemptNumber: 2);
      await store.setAttemptState(
        expired,
        AttemptState.ended,
        violationCount: 0,
      );
      await store.setAttemptEndedAt(
        expired,
        now.subtract(const Duration(days: 7, milliseconds: 1)),
      );

      final held = <String>[];
      for (final state in [
        AttemptState.active,
        AttemptState.locked,
        AttemptState.recoveryPending,
      ]) {
        final attempt = await store.startAttempt(
          session,
          attemptNumber: 3 + state.index,
        );
        held.add(attempt);
        await store.setAttemptState(attempt, state, violationCount: 0);
        await store.setAttemptEndedAt(
          attempt,
          now.subtract(const Duration(days: 10)),
        );
      }

      final unusedSession = ExamSession(
        schemaVersion: 2,
        sessionId: 'session-unused',
        sessionCode: 'UNUSED-1',
        examName: 'Sesi Guru Belum Dipakai',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/unused/viewform'),
        createdAt: now,
      );
      await store.saveSession(unusedSession);

      expect(await store.runRetention(now: now), [expired]);
      expect(
        (await store.loadAttemptsFor(
          session.sessionId,
        )).map((attempt) => attempt.attemptId),
        containsAll([exactBoundary, ...held]),
      );
      expect(await store.loadAttempt(expired), isNull);
      expect(await store.loadSession(session.sessionId), isNotNull);
      expect(await store.loadSession(unusedSession.sessionId), isNotNull);
    },
  );

  test(
    'retention tidak menghapus data parsial saat penghapusan gagal',
    () async {
      final store = await newStore();
      final now = DateTime.utc(2026, 9, 16, 12);
      await store.saveSession(session);
      final attemptId = await store.startAttempt(session, attemptNumber: 1);
      await store.setAttemptState(
        attemptId,
        AttemptState.ended,
        violationCount: 0,
      );
      await store.setAttemptEndedAt(
        attemptId,
        now.subtract(const Duration(days: 8)),
      );
      await store.recordEvent(
        attemptId: attemptId,
        eventType: 'networkLost',
        countedAsViolation: false,
        counterAfter: 0,
      );
      await store.recordSupervisorAction(
        attemptId: attemptId,
        actionType: 'end',
        result: 'ended',
      );
      final db = openDbs.single;
      await db.execute('''
      CREATE TRIGGER fail_retention_attempt
      BEFORE DELETE ON attempts
      WHEN OLD.attempt_id = '$attemptId'
      BEGIN SELECT RAISE(ABORT, 'simulasi pembersihan gagal'); END
    ''');

      await expectLater(
        store.runRetention(now: now),
        throwsA(isA<StorageFailure>()),
      );

      final retained = await store.loadAttempt(attemptId);
      expect(retained, isNotNull);
      expect(retained!.events, hasLength(1));
      expect(
        await db.query(
          'supervisor_actions',
          where: 'attempt_id = ?',
          whereArgs: [attemptId],
        ),
        hasLength(1),
      );
    },
  );

  test(
    'retention menjaga sesi selama pemulihan pra-aktivasi tertunda',
    () async {
      final store = await newStore();
      final now = DateTime.utc(2026, 9, 16, 12);
      await store.saveSession(session);
      final attemptId = await store.startAttempt(session, attemptNumber: 1);
      await store.setAttemptState(
        attemptId,
        AttemptState.ended,
        violationCount: 0,
      );
      await store.setAttemptEndedAt(
        attemptId,
        now.subtract(const Duration(days: 8)),
      );
      await store.prepareProtectionActivation(session);

      expect(await store.runRetention(now: now), [attemptId]);
      expect(await store.loadSession(session.sessionId), isNotNull);
      expect(await store.loadPreparedProtectionSessionId(), session.sessionId);
    },
  );

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

  test('attempt row rusak muncul sebagai kegagalan penyimpanan', () async {
    final store = await newStore();
    await store.saveSession(session);
    final attemptId = await store.startAttempt(session, attemptNumber: 1);
    final db = openDbs.single;
    await db.update(
      'attempts',
      {'violation_count': 'bukan angka'},
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
    );

    await expectLater(
      store.loadCurrentAttempt(),
      throwsA(isA<StorageFailure>()),
    );
  });

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

    // Sesi konsisten: tidak ada duplikat saat disimpan ulang.
    await store.saveSession(session);
    expect((await store.listSessions()).length, 1);
  });

  test('delete session membersihkan attempt, event, dan aksi pengawas', () async {
    final store = await newStore();
    final other = ExamSession(
      schemaVersion: 2,
      sessionId: 'session-2',
      sessionCode: 'BIN-1234',
      examName: 'Bahasa Indonesia',
      formUrl: Uri.parse('https://forms.gle/other'),
    );
    await store.saveSession(session);
    await store.saveSession(other);
    final attemptId = await store.startAttempt(session, attemptNumber: 1);
    await store.recordEvent(
      attemptId: attemptId,
      eventType: 'focusLost',
      countedAsViolation: false,
      counterAfter: 0,
    );
    await store.recordSupervisorAction(
      attemptId: attemptId,
      actionType: 'end',
      result: 'ended',
    );
    await store.setAttemptState(
      attemptId,
      AttemptState.ended,
      violationCount: 0,
    );
    await store.setAttemptEndedAt(attemptId, DateTime.now());

    expect(await store.deleteSession(session.sessionId), [attemptId]);

    expect(await store.loadSession(session.sessionId), isNull);
    expect(await store.loadAttemptsFor(session.sessionId), isEmpty);
    // Sesi lain tidak ikut terhapus.
    expect((await store.listSessions()).single.sessionId, 'session-2');
    final db = openDbs.single;
    for (final table in [
      'session_events',
      'supervisor_actions',
      'protection_states',
    ]) {
      expect(
        await db.query(table, where: 'attempt_id = ?', whereArgs: [attemptId]),
        isEmpty,
      );
    }
  });

  test('attempt belum selesai menahan penghapusan sesi', () async {
    final store = await newStore();
    await store.saveSession(session);
    await store.startAttempt(session, attemptNumber: 1);

    await expectLater(
      store.deleteSession(session.sessionId),
      throwsA(isA<StorageFailure>()),
    );

    expect(await store.loadSession(session.sessionId), isNotNull);
    expect(await store.loadCurrentAttempt(), isNotNull);
  });

  test('pemulihan proteksi tertunda menahan penghapusan sesi', () async {
    final store = await newStore();
    await store.saveSession(session);
    final attemptId = await store.startAttempt(session, attemptNumber: 1);
    await store.setAttemptState(
      attemptId,
      AttemptState.ended,
      violationCount: 0,
    );
    await store.setAttemptEndedAt(attemptId, DateTime.now());
    await store.saveProtectionState(
      attemptId: attemptId,
      secureWindowActive: true,
      notificationProtectionActive: true,
      notificationAccessGranted: true,
      restorePending: true,
    );

    await expectLater(
      store.deleteSession(session.sessionId),
      throwsA(isA<StorageFailure>()),
    );

    expect(await store.loadSession(session.sessionId), isNotNull);
    expect(await store.hasPendingRestore(), isTrue);
  });

  test('pemulihan pra-aktivasi menahan penghapusan sesi', () async {
    final store = await newStore();
    await store.saveSession(session);
    await store.prepareProtectionActivation(session);

    await expectLater(
      store.deleteSession(session.sessionId),
      throwsA(isA<StorageFailure>()),
    );

    expect(await store.loadSession(session.sessionId), isNotNull);
    expect(await store.loadPreparedProtectionSessionId(), session.sessionId);
  });

  test('daftar guru hanya menampilkan sesi buatan lokal', () async {
    final store = await newStore();
    await store.saveSession(session);
    final scanned = ExamSession(
      schemaVersion: 2,
      sessionId: 'session-2',
      sessionCode: 'BIO-3X8Q',
      examName: 'Biologi Kelas X',
      formUrl: Uri.parse('https://forms.gle/contoh'),
      createdAt: DateTime.utc(2026, 9, 14, 8),
    );
    await store.saveSession(scanned, fromScan: true);

    expect(await store.listSessions(), hasLength(2));
    final local = await store.listLocalSessions();
    expect(local, hasLength(1));
    expect(local.single.sessionId, 'session-1');
    // Scan ulang sesi identik tidak mengubah origin.
    await store.saveSession(scanned, fromScan: true);
    expect(await store.listLocalSessions(), hasLength(1));
    // Keterkaitan attempt tetap bisa memuat sesi hasil scan.
    expect(
      (await store.loadSession('session-2'))!.sessionId,
      'session-2',
    );
  });

  test('migrasi menambah origin pada database lama', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    openDbs.add(db);
    await db.execute('''
      CREATE TABLE sessions (
        session_id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        session_code TEXT NOT NULL,
        exam_name TEXT NOT NULL,
        form_url TEXT NOT NULL,
        security_policy_version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.insert('sessions', {
      'session_id': 'legacy-1',
      'schema_version': 2,
      'session_code': 'MTK-7K2P',
      'exam_name': 'Matematika Kelas XI',
      'form_url': 'https://docs.google.com/forms/d/e/abc/viewform',
      'security_policy_version': 1,
      'created_at': DateTime.utc(2026, 9, 13, 8).millisecondsSinceEpoch,
    });

    final store = await SessionStore.open(db);

    // Baris lama ikut default local; baris baru tercatat sesuai asal.
    expect(await store.listLocalSessions(), hasLength(1));
    final scanned = ExamSession(
      schemaVersion: 2,
      sessionId: 'session-2',
      sessionCode: 'BIO-3X8Q',
      examName: 'Biologi Kelas X',
      formUrl: Uri.parse('https://forms.gle/contoh'),
      createdAt: DateTime.utc(2026, 9, 14, 8),
    );
    await store.saveSession(scanned, fromScan: true);
    expect(await store.listSessions(), hasLength(2));
    expect(await store.listLocalSessions(), hasLength(1));
  });
}
