import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/exam_sessions.dart';
import 'attempt_state_machine.dart';

extension _LastWhereOrNull<T> on Iterable<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    T? found;
    for (final element in this) {
      if (test(element)) found = element;
    }
    return found;
  }
}

/// Kegagalan penyimpanan yang harus ditangani UI secara terlihat: jangan
/// lanjut ke state yang bergantung pada data tersebut (PRD FR12).
class StorageFailure implements Exception {
  StorageFailure(this.message);
  final String message;

  @override
  String toString() => 'StorageFailure: $message';
}

/// Attempt ujian yang dipulihkan dari penyimpanan lokal, lengkap dengan
/// sesi dan riwayat event-nya.
class StoredAttempt {
  StoredAttempt({
    required this.attemptId,
    required this.sessionId,
    required this.attemptNumber,
    required this.state,
    required this.violationCount,
    required this.startedAt,
    required this.lastEndedAt,
    required this.session,
    required this.events,
    this.violationReason,
  });

  final String attemptId;
  final String sessionId;
  final int attemptNumber;
  final AttemptState state;
  final int violationCount;
  final DateTime startedAt;
  final DateTime? lastEndedAt;
  final ExamSession? session;
  final List<StoredEvent> events;

  /// Alasan pelanggaran terakhir yang tercatat (untuk overlay/lock UI);
  /// null bila belum ada pelanggaran.
  final String? violationReason;
}

class StoredEvent {
  StoredEvent({
    required this.eventId,
    required this.attemptId,
    required this.eventType,
    required this.occurredAt,
    required this.countedAsViolation,
    required this.counterAfter,
    required this.correlationId,
  });

  final String eventId;
  final String attemptId;
  final String eventType;
  final DateTime occurredAt;
  final bool countedAsViolation;
  final int counterAfter;
  final String? correlationId;
}

/// Penyimpanan privat aplikasi untuk sesi, attempt, event, aksi pengawas,
/// dan status proteksi (PRD FR12). Semua transisi penting ditulis ke sini
/// sebelum UI memberi akses baru; kegagalan tulis memblokir transisi.
///
/// PIN mentah tidak pernah disimpan di sini: bahan terlindungi milik HP
/// pembuat sesi berada di secure storage (PinService).
class SessionStore {
  SessionStore._(this._db);

  final Database _db;

  /// Membuka/membuat database pada [db] yang sudah terbuka dan menjalankan
  /// migrasi. Lempar [StorageFailure] bila gagal.
  static Future<SessionStore> open(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          session_id TEXT PRIMARY KEY,
          schema_version INTEGER NOT NULL,
          session_code TEXT NOT NULL,
          exam_name TEXT NOT NULL,
          form_url TEXT NOT NULL,
          pin_salt TEXT,
          pin_verifier TEXT,
          security_policy_version INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attempts (
          attempt_id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          attempt_number INTEGER NOT NULL,
          state TEXT NOT NULL,
          violation_count INTEGER NOT NULL,
          started_at INTEGER NOT NULL,
          ended_at INTEGER,
          ended_reason TEXT,
          updated_at INTEGER NOT NULL,
          UNIQUE(session_id, attempt_number)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS session_events (
          event_id TEXT PRIMARY KEY,
          attempt_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          occurred_at INTEGER NOT NULL,
          counted_as_violation INTEGER NOT NULL,
          counter_after INTEGER NOT NULL,
          correlation_id TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supervisor_actions (
          action_id TEXT PRIMARY KEY,
          attempt_id TEXT NOT NULL,
          action_type TEXT NOT NULL,
          authorized_at INTEGER NOT NULL,
          result TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS protection_states (
          attempt_id TEXT PRIMARY KEY,
          secure_window_state TEXT NOT NULL,
          notification_protection_state TEXT NOT NULL,
          notification_access_granted INTEGER NOT NULL,
          restore_pending INTEGER NOT NULL,
          restore_data TEXT,
          last_checked_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pin_attempt_status (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          attempt_id TEXT NOT NULL,
          failed_attempts INTEGER NOT NULL,
          locked_until INTEGER,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS form_checks (
          session_id TEXT PRIMARY KEY,
          form_url TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          checked_at INTEGER,
          blocked_navigations INTEGER NOT NULL DEFAULT 0
        )
      ''');
      return SessionStore._(db);
    } on DatabaseException catch (e) {
      throw StorageFailure('Penyimpanan sesi gagal dibuka: $e');
    }
  }

  Future<T> _guard<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on StorageFailure {
      rethrow;
    } on DatabaseException catch (e) {
      throw StorageFailure('Gagal $action: $e');
    }
  }

  // ---- Sesi ----

  Future<bool> isFormConfirmed(ExamSession session) => _guard(
    'membaca pemeriksaan Form',
    () async => (await _db.query(
      'form_checks',
      where: 'session_id = ? AND form_url = ? AND checked_at IS NOT NULL',
      whereArgs: [session.sessionId, session.formUrl.toString()],
    )).isNotEmpty,
  );

  Future<void> beginFormTest(ExamSession session, DateTime now) =>
      _guard('memulai pemeriksaan Form', () async {
        await _db.insert('form_checks', {
          'session_id': session.sessionId,
          'form_url': session.formUrl.toString(),
          'started_at': now.millisecondsSinceEpoch,
          'checked_at': null,
          'blocked_navigations': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

  Future<void> recordFormNavigationBlocked(ExamSession session) =>
      _guard('mencatat navigasi Form yang diblokir', () async {
        final changed = await _db.rawUpdate(
          '''
        UPDATE form_checks SET blocked_navigations = blocked_navigations + 1
        WHERE session_id = ? AND form_url = ? AND checked_at IS NULL
      ''',
          [session.sessionId, session.formUrl.toString()],
        );
        if (changed != 1) throw StorageFailure('Uji Form belum dimulai.');
      });

  // Ini pernyataan manual guru, bukan bukti pengiriman dari Google Forms.
  Future<void> confirmFormReady(ExamSession session, DateTime now) =>
      _guard('menyimpan konfirmasi guru', () async {
        final changed = await _db.update(
          'form_checks',
          {'checked_at': now.millisecondsSinceEpoch},
          where: 'session_id = ? AND form_url = ? AND checked_at IS NULL',
          whereArgs: [session.sessionId, session.formUrl.toString()],
        );
        if (changed != 1) {
          throw StorageFailure('Jalankan uji Form terlebih dahulu.');
        }
      });

  /// Simpan sesi (idempoten untuk sesi identik).
  Future<void> saveSession(
    ExamSession session, {
    bool fromScan = false,
  }) => _guard('menyimpan sesi', () async {
    await _db.transaction((txn) async {
      if (fromScan) {
        final active = await txn.query(
          'attempts',
          columns: ['session_id'],
          where: 'state IN (?, ?, ?)',
          whereArgs: ['active', 'locked', 'recoveryPending'],
        );
        if (active.any((row) => row['session_id'] != session.sessionId)) {
          throw StorageFailure(
            'Masih ada ujian yang belum selesai. Hubungi pengawas.',
          );
        }
      }
      final existing = await txn.query(
        'sessions',
        where: 'session_id = ?',
        whereArgs: [session.sessionId],
      );
      if (existing.isNotEmpty &&
          !_sessionFromRow(existing.single).sameIdentityAs(session)) {
        throw StorageFailure(
          'Data sesi berbeda dengan yang tersimpan. Minta QR sesi dari guru.',
        );
      }
      await txn.insert('sessions', {
        'session_id': session.sessionId,
        'schema_version': session.schemaVersion,
        'session_code': session.sessionCode,
        'exam_name': session.examName,
        'form_url': session.formUrl.toString(),
        'pin_salt': session.pinSalt,
        'pin_verifier': session.pinVerifier,
        'security_policy_version': session.securityPolicyVersion,
        'created_at': session.createdAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  });

  Future<List<ExamSession>> listSessions() =>
      _guard('memuat daftar sesi', () async {
        final rows = await _db.query('sessions', orderBy: 'created_at DESC');
        return rows.map(_sessionFromRow).toList();
      });

  Future<ExamSession?> loadSession(String sessionId) =>
      _guard('memuat sesi', () async {
        final rows = await _db.query(
          'sessions',
          where: 'session_id = ?',
          whereArgs: [sessionId],
          limit: 1,
        );
        return rows.isEmpty ? null : _sessionFromRow(rows.first);
      });

  ExamSession _sessionFromRow(Map<String, Object?> row) => ExamSession(
    schemaVersion: row['schema_version'] as int,
    sessionId: row['session_id'] as String,
    sessionCode: row['session_code'] as String,
    examName: row['exam_name'] as String,
    formUrl: Uri.parse(row['form_url'] as String),
    pinSalt: row['pin_salt'] as String?,
    pinVerifier: row['pin_verifier'] as String?,
    securityPolicyVersion: row['security_policy_version'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );

  // ---- Attempt ----

  /// Mulai attempt baru untuk sesi. Attempt aktif/terkunci yang sudah ada
  /// memblokir pembuatan attempt baru (scan baru tidak menimpa).
  Future<String> startAttempt(
    ExamSession session, {
    required int attemptNumber,
  }) => _guard('memulai attempt', () async {
    final now = DateTime.now();
    final attemptId =
        'attempt-${session.sessionId}-$attemptNumber-${now.millisecondsSinceEpoch}';
    await _db.insert('attempts', {
      'attempt_id': attemptId,
      'session_id': session.sessionId,
      'attempt_number': attemptNumber,
      'state': AttemptState.active.name,
      'violation_count': 0,
      'started_at': now.millisecondsSinceEpoch,
      'ended_at': null,
      'ended_reason': null,
      'updated_at': now.millisecondsSinceEpoch,
    });
    return attemptId;
  });

  /// Attempt "saat ini" yang menahan mode siswa: aktif, terkunci, atau
  /// menunggu pemulihan. Attempt berakhir bukan penahan; pengulangan
  /// membuat attempt baru.
  Future<StoredAttempt?> loadCurrentAttempt() =>
      _guard('memuat attempt tersimpan', () async {
        final rows = await _db.query(
          'attempts',
          where: 'state IN (?, ?, ?)',
          whereArgs: [
            AttemptState.active.name,
            AttemptState.locked.name,
            AttemptState.recoveryPending.name,
          ],
          orderBy: 'updated_at DESC',
          limit: 1,
        );
        if (rows.isEmpty) return null;
        return _attemptFromRow(rows.first);
      });

  Future<List<StoredAttempt>> loadAttemptsFor(String sessionId) =>
      _guard('memuat riwayat attempt', () async {
        final rows = await _db.query(
          'attempts',
          where: 'session_id = ?',
          whereArgs: [sessionId],
          orderBy: 'attempt_number ASC',
        );
        final attempts = <StoredAttempt>[];
        for (final row in rows) {
          attempts.add(await _attemptFromRow(row));
        }
        return attempts;
      });

  Future<StoredAttempt?> loadAttempt(String attemptId) =>
      _guard('memuat attempt', () async {
        final rows = await _db.query(
          'attempts',
          where: 'attempt_id = ?',
          whereArgs: [attemptId],
          limit: 1,
        );
        return rows.isEmpty ? null : _attemptFromRow(rows.first);
      });

  Future<StoredAttempt> _attemptFromRow(Map<String, Object?> row) async {
    final attemptId = row['attempt_id'] as String;
    final events = await _db.query(
      'session_events',
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
      orderBy: 'occurred_at ASC',
    );
    final session = await loadSession(row['session_id'] as String);
    final eventList = events.map(_eventFromRow).toList();
    final lastCounted = eventList.lastWhereOrNull((e) => e.countedAsViolation);
    return StoredAttempt(
      attemptId: attemptId,
      sessionId: row['session_id'] as String,
      attemptNumber: row['attempt_number'] as int,
      state: _stateFromName(row['state'] as String),
      violationCount: row['violation_count'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      lastEndedAt: row['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
      session: session,
      events: eventList,
      violationReason: lastCounted?.eventType,
    );
  }

  AttemptState _stateFromName(String name) => AttemptState.values.firstWhere(
    (s) => s.name == name,
    orElse: () => AttemptState.preExam,
  );

  Future<void> setAttemptState(
    String attemptId,
    AttemptState state, {
    required int violationCount,
  }) => _guard('menyimpan state attempt', () async {
    await _db.update(
      'attempts',
      {
        'state': state.name,
        'violation_count': violationCount,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
    );
  });

  Future<void> setAttemptEndedAt(String attemptId, DateTime endedAt) =>
      _guard('menyimpan waktu berakhir', () async {
        await _db.update(
          'attempts',
          {'ended_at': endedAt.millisecondsSinceEpoch},
          where: 'attempt_id = ?',
          whereArgs: [attemptId],
        );
      });

  Future<void> setAttemptUpdatedAt(String attemptId, DateTime updatedAt) =>
      _guard('menyimpan waktu pembaruan', () async {
        await _db.update(
          'attempts',
          {'updated_at': updatedAt.millisecondsSinceEpoch},
          where: 'attempt_id = ?',
          whereArgs: [attemptId],
        );
      });

  Future<void> setAttemptEndReason(String attemptId, String reason) =>
      _guard('menyimpan alasan pengakhiran', () async {
        await _db.update(
          'attempts',
          {
            'ended_reason': reason,
            'ended_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'attempt_id = ?',
          whereArgs: [attemptId],
        );
      });

  // ---- Event ----

  Future<void> recordEvent({
    required String attemptId,
    required String eventType,
    required bool countedAsViolation,
    required int counterAfter,
    String? correlationId,
  }) => _guard('mencatat event', () async {
    final now = DateTime.now();
    await _db.insert('session_events', {
      'event_id': 'event-$attemptId-$now-${eventType.hashCode.abs()}',
      'attempt_id': attemptId,
      'event_type': eventType,
      'occurred_at': now.millisecondsSinceEpoch,
      'counted_as_violation': countedAsViolation ? 1 : 0,
      'counter_after': counterAfter,
      'correlation_id': correlationId,
    });
  });

  StoredEvent _eventFromRow(Map<String, Object?> row) => StoredEvent(
    eventId: row['event_id'] as String,
    attemptId: row['attempt_id'] as String,
    eventType: row['event_type'] as String,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int),
    countedAsViolation: (row['counted_as_violation'] as int) == 1,
    counterAfter: row['counter_after'] as int,
    correlationId: row['correlation_id'] as String?,
  );

  // ---- Aksi pengawas ----

  Future<void> recordSupervisorAction({
    required String attemptId,
    required String actionType,
    required String result,
  }) => _guard('mencatat aksi pengawas', () async {
    final now = DateTime.now();
    await _db.insert('supervisor_actions', {
      'action_id': 'action-$attemptId-$now-$actionType'.replaceAll(' ', '_'),
      'attempt_id': attemptId,
      'action_type': actionType,
      'authorized_at': now.millisecondsSinceEpoch,
      'result': result,
    });
  });

  // ---- Status proteksi ----

  Future<void> saveProtectionState({
    required String attemptId,
    required bool secureWindowActive,
    required bool notificationProtectionActive,
    required bool notificationAccessGranted,
    required bool restorePending,
    Map<String, Object?>? restoreData,
  }) => _guard('menyimpan status proteksi', () async {
    await _db.insert('protection_states', {
      'attempt_id': attemptId,
      'secure_window_state': secureWindowActive ? 'active' : 'inactive',
      'notification_protection_state': notificationProtectionActive
          ? 'active'
          : 'inactive',
      'notification_access_granted': notificationAccessGranted ? 1 : 0,
      'restore_pending': restorePending ? 1 : 0,
      'restore_data': restoreData == null ? null : jsonEncode(restoreData),
      'last_checked_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<bool> hasPendingRestore() =>
      _guard('memeriksa pemulihan tertunda', () async {
        final rows = await _db.query(
          'protection_states',
          where: 'restore_pending = 1',
          limit: 1,
        );
        return rows.isNotEmpty;
      });

  Future<String?> loadPendingRestoreAttemptId() =>
      _guard('memuat attempt dengan pemulihan tertunda', () async {
        final rows = await _db.query(
          'protection_states',
          where: 'restore_pending = 1',
          limit: 1,
        );
        if (rows.isEmpty) return null;
        final data = rows.first['restore_data'] as String?;
        if (data == null) return rows.first['attempt_id'] as String;
        return rows.first['attempt_id'] as String;
      });

  Future<void> clearPendingRestore(String attemptId) =>
      _guard('menghapus penanda pemulihan tertunda', () async {
        await _db.update(
          'protection_states',
          {
            'restore_pending': 0,
            'last_checked_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'attempt_id = ?',
          whereArgs: [attemptId],
        );
      });

  // ---- Status PIN ----

  Future<void> savePinAttemptStatus({
    required String attemptId,
    required int failedAttempts,
    DateTime? lockedUntil,
  }) => _guard('menyimpan status percobaan PIN', () async {
    await _db.delete(
      'pin_attempt_status',
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
    );
    await _db.insert('pin_attempt_status', {
      'attempt_id': attemptId,
      'failed_attempts': failedAttempts,
      'locked_until': lockedUntil?.millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  });

  Future<({int failedAttempts, DateTime? lockedUntil})> loadPinAttemptStatus(
    String attemptId,
  ) => _guard('memuat status percobaan PIN', () async {
    final rows = await _db.query(
      'pin_attempt_status',
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
      limit: 1,
    );
    if (rows.isEmpty) return (failedAttempts: 0, lockedUntil: null);
    return (
      failedAttempts: rows.first['failed_attempts'] as int,
      lockedUntil: rows.first['locked_until'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              rows.first['locked_until'] as int,
            ),
    );
  });

  // ---- Retensi ----

  /// Pembersihan retensi: hapus HANYA attempt berakhir yang berumur lebih
  /// dari tujuh hari sejak berakhir, beserta event dan aksi pengawasnya.
  /// Attempt aktif/terkunci/recoveryPending tidak pernah dihapus.
  /// Mengembalikan daftar attemptId yang dihapus.
  Future<List<String>> runRetention({
    required DateTime now,
  }) => _guard('menjalankan retensi', () async {
    final cutoff = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final expired = await _db.query(
      'attempts',
      columns: ['attempt_id', 'session_id'],
      where: 'state = ? AND ended_at IS NOT NULL AND ended_at < ?',
      whereArgs: [AttemptState.ended.name, cutoff],
    );
    final ids = expired.map((row) => row['attempt_id'] as String).toList();
    for (final id in ids) {
      await _db.delete(
        'session_events',
        where: 'attempt_id = ?',
        whereArgs: [id],
      );
      await _db.delete(
        'supervisor_actions',
        where: 'attempt_id = ?',
        whereArgs: [id],
      );
      await _db.delete(
        'protection_states',
        where: 'attempt_id = ?',
        whereArgs: [id],
      );
      await _db.delete(
        'pin_attempt_status',
        where: 'attempt_id = ?',
        whereArgs: [id],
      );
      await _db.delete('attempts', where: 'attempt_id = ?', whereArgs: [id]);
    }
    // Hanya sesi dengan attempt kedaluwarsa yang menjadi kandidat.
    // Sesi guru yang belum dipakai harus tetap tersedia setelah boot.
    final expiredSessions = expired
        .map((row) => row['session_id'] as String)
        .toSet();
    for (final sessionId in expiredSessions) {
      final remaining = await _db.query(
        'attempts',
        columns: ['attempt_id'],
        where: 'session_id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (remaining.isEmpty) {
        await _db.delete(
          'form_checks',
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
        await _db.delete(
          'sessions',
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
      }
    }
    return ids;
  });
}
