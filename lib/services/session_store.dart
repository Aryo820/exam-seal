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
        CREATE TABLE IF NOT EXISTS prepared_protection_activations (
          session_id TEXT PRIMARY KEY,
          prepared_at INTEGER NOT NULL
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
    } catch (e) {
      throw StorageFailure('Gagal $action: $e');
    }
  }

  // ---- Sesi ----

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

  /// Hapus sesi guru beserta attempt, event, aksi pengawas, dan status
  /// proteksinya dalam satu transaksi. Penghapusan ditolak selama attempt
  /// sesi ini masih menahan (aktif, terkunci, menunggu pemulihan) atau
  /// pemulihan proteksi perangkatnya belum selesai: menghapusnya akan
  /// menghilangkan jejak yang dibutuhkan pemulihan OS (PRD FR12). Attempt
  /// berakhir tidak menahan, sehingga penanda pembatasan pengulangan lokal
  /// ikut terhapus; UI wajib memperingatkan hal itu lebih dulu (FR07).
  /// Mengembalikan daftar attemptId yang dihapus.
  Future<List<String>> deleteSession(String sessionId) =>
      _guard('menghapus sesi', () async {
        return _db.transaction((txn) async {
          final holding = await txn.query(
            'attempts',
            columns: ['attempt_id'],
            where: 'session_id = ? AND state IN (?, ?, ?)',
            whereArgs: [
              sessionId,
              AttemptState.active.name,
              AttemptState.locked.name,
              AttemptState.recoveryPending.name,
            ],
            limit: 1,
          );
          if (holding.isNotEmpty) {
            throw StorageFailure(
              'Sesi ini masih menahan percobaan siswa yang belum selesai. Minta pengawas menyelesaikannya lebih dulu.',
            );
          }
          final prepared = await txn.query(
            'prepared_protection_activations',
            columns: ['session_id'],
            where: 'session_id = ?',
            whereArgs: [sessionId],
            limit: 1,
          );
          if (prepared.isNotEmpty) {
            throw StorageFailure(
              'Pemulihan proteksi perangkat untuk sesi ini belum selesai. Coba lagi setelah pemulihan berhasil.',
            );
          }
          final attempts = await txn.query(
            'attempts',
            columns: ['attempt_id'],
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
          for (final row in attempts) {
            final attemptId = row['attempt_id'] as String;
            final pendingRestore = await txn.query(
              'protection_states',
              columns: ['attempt_id'],
              where: 'attempt_id = ? AND restore_pending = 1',
              whereArgs: [attemptId],
              limit: 1,
            );
            if (pendingRestore.isNotEmpty) {
              throw StorageFailure(
                'Pemulihan proteksi perangkat untuk sesi ini belum selesai. Coba lagi setelah pemulihan berhasil.',
              );
            }
            await txn.delete(
              'session_events',
              where: 'attempt_id = ?',
              whereArgs: [attemptId],
            );
            await txn.delete(
              'supervisor_actions',
              where: 'attempt_id = ?',
              whereArgs: [attemptId],
            );
            await txn.delete(
              'protection_states',
              where: 'attempt_id = ?',
              whereArgs: [attemptId],
            );
          }
          await txn.delete(
            'attempts',
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
          await txn.delete(
            'sessions',
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
          return attempts.map((row) => row['attempt_id'] as String).toList();
        });
      });

  ExamSession _sessionFromRow(Map<String, Object?> row) => ExamSession(
    schemaVersion: row['schema_version'] as int,
    sessionId: row['session_id'] as String,
    sessionCode: row['session_code'] as String,
    examName: row['exam_name'] as String,
    formUrl: Uri.parse(row['form_url'] as String),
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

  /// Tulis attempt aktif dan penanda pemulihan dalam satu transaksi. Pemanggil
  /// wajib menyiapkan [prepareProtectionActivation] sebelum mengubah OS.
  Future<String> startProtectedAttempt(
    ExamSession session, {
    required int attemptNumber,
    required bool secureWindowActive,
    required bool notificationProtectionActive,
    required bool notificationAccessGranted,
  }) => _guard('memulai attempt terlindungi', () async {
    final now = DateTime.now();
    final attemptId =
        'attempt-${session.sessionId}-$attemptNumber-${now.millisecondsSinceEpoch}';
    await _db.transaction((txn) async {
      final current = await txn.query(
        'attempts',
        columns: ['attempt_id'],
        where: 'state IN (?, ?, ?)',
        whereArgs: [
          AttemptState.active.name,
          AttemptState.locked.name,
          AttemptState.recoveryPending.name,
        ],
        limit: 1,
      );
      if (current.isNotEmpty) {
        throw StorageFailure('Masih ada attempt ujian yang belum selesai.');
      }
      await txn.insert('attempts', {
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
      await txn.insert('protection_states', {
        'attempt_id': attemptId,
        'secure_window_state': secureWindowActive ? 'active' : 'inactive',
        'notification_protection_state': notificationProtectionActive
            ? 'active'
            : 'inactive',
        'notification_access_granted': notificationAccessGranted ? 1 : 0,
        'restore_pending': 1,
        'restore_data': jsonEncode(const {'owned': 'examseal'}),
        'last_checked_at': now.millisecondsSinceEpoch,
      });
      await txn.delete(
        'prepared_protection_activations',
        where: 'session_id = ?',
        whereArgs: [session.sessionId],
      );
    });
    return attemptId;
  });

  /// Attempt "saat ini" yang menahan mode siswa: aktif, terkunci, atau
  /// menunggu pemulihan. Attempt berakhir bukan penahan; pengulangan
  /// membuat attempt baru.
  Future<StoredAttempt?> loadCurrentAttempt() =>
      _guard('memuat attempt tersimpan', () async {
        final statePlaceholders = List.filled(
          AttemptState.values.length,
          '?',
        ).join(', ');
        final unknownStates = await _db.query(
          'attempts',
          columns: ['state'],
          where: 'state NOT IN ($statePlaceholders)',
          whereArgs: AttemptState.values.map((state) => state.name).toList(),
          limit: 1,
        );
        if (unknownStates.isNotEmpty) {
          throw StorageFailure('State attempt tersimpan tidak dikenal.');
        }
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
    if (session == null) {
      throw StorageFailure(
        'Data sesi untuk attempt tersimpan tidak ditemukan.',
      );
    }
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

  AttemptState _stateFromName(String name) {
    for (final state in AttemptState.values) {
      if (state.name == name) return state;
    }
    throw StorageFailure('State attempt tersimpan tidak dikenal.');
  }

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

  Future<void> recordViolation({
    required String attemptId,
    required String eventType,
    required int counterAfter,
    required AttemptState state,
    required String correlationId,
  }) => _guard('mencatat pelanggaran', () async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      await txn.insert('session_events', {
        'event_id': 'event-$attemptId-$now-${eventType.hashCode.abs()}',
        'attempt_id': attemptId,
        'event_type': eventType,
        'occurred_at': now.millisecondsSinceEpoch,
        'counted_as_violation': 1,
        'counter_after': counterAfter,
        'correlation_id': correlationId,
      });
      await txn.update(
        'attempts',
        {
          'state': state.name,
          'violation_count': counterAfter,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
      );
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

  /// State akhir, alasan, dan audit pengawas harus tersimpan bersama sebelum
  /// pemanggil melepas pengaturan perangkat.
  Future<void> endAttemptWithSupervisorAction({
    required String attemptId,
    required int violationCount,
    required String reason,
  }) => _guard('mengakhiri attempt dengan otorisasi', () async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      await txn.update(
        'attempts',
        {
          'state': AttemptState.ended.name,
          'violation_count': violationCount,
          'ended_reason': reason,
          'ended_at': now.millisecondsSinceEpoch,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
      );
      await txn.insert('supervisor_actions', {
        'action_id': 'action-$attemptId-$now-end'.replaceAll(' ', '_'),
        'attempt_id': attemptId,
        'action_type': 'end',
        'authorized_at': now.millisecondsSinceEpoch,
        'result': 'ended',
      });
    });
  });

  // ---- Status proteksi ----

  /// Disimpan sebelum native mengubah FLAG_SECURE/DND. Bila proses mati pada
  /// celah ini, boot masih tahu bahwa native perlu dipulihkan.
  Future<void> prepareProtectionActivation(ExamSession session) => _guard(
    'menyiapkan pemulihan proteksi',
    () => _db.insert('prepared_protection_activations', {
      'session_id': session.sessionId,
      'prepared_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace),
  );

  Future<String?> loadPreparedProtectionSessionId() =>
      _guard('memuat persiapan proteksi', () async {
        final rows = await _db.query(
          'prepared_protection_activations',
          orderBy: 'prepared_at ASC',
          limit: 1,
        );
        return rows.isEmpty ? null : rows.first['session_id'] as String;
      });

  Future<void> clearPreparedProtectionActivation(String sessionId) => _guard(
    'menghapus persiapan proteksi',
    () => _db.delete(
      'prepared_protection_activations',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    ),
  );

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

  // ---- Retensi ----

  /// Pembersihan retensi: hapus HANYA attempt berakhir yang berumur lebih
  /// dari tujuh hari sejak berakhir, beserta event dan aksi pengawasnya.
  /// Attempt aktif/terkunci/recoveryPending atau pemulihan OS tertunda tidak
  /// pernah dihapus. Pembersihan data WebView tidak pernah dipanggil di sini;
  /// itu tetap tindakan terpisah setelah pengawas memeriksa pengiriman Form.
  /// Mengembalikan daftar attemptId yang dihapus.
  Future<List<String>> runRetention({
    required DateTime now,
  }) => _guard('menjalankan retensi', () async {
    return _db.transaction((txn) async {
      final cutoff = now
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;
      final expired = await txn.query(
        'attempts',
        columns: ['attempt_id', 'session_id'],
        where: '''
        state = ? AND ended_at IS NOT NULL AND ended_at < ?
        AND attempt_id NOT IN (
          SELECT attempt_id FROM protection_states WHERE restore_pending = 1
        )
      ''',
        whereArgs: [AttemptState.ended.name, cutoff],
      );
      final ids = expired.map((row) => row['attempt_id'] as String).toList();
      for (final id in ids) {
        await txn.delete(
          'session_events',
          where: 'attempt_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'supervisor_actions',
          where: 'attempt_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'protection_states',
          where: 'attempt_id = ?',
          whereArgs: [id],
        );
        await txn.delete('attempts', where: 'attempt_id = ?', whereArgs: [id]);
      }
      // Hanya sesi dengan attempt kedaluwarsa yang menjadi kandidat.
      // Sesi guru yang belum dipakai atau masih memulihkan proteksi tetap ada.
      final expiredSessions = expired
          .map((row) => row['session_id'] as String)
          .toSet();
      for (final sessionId in expiredSessions) {
        final remaining = await txn.query(
          'attempts',
          columns: ['attempt_id'],
          where: 'session_id = ?',
          whereArgs: [sessionId],
          limit: 1,
        );
        final restoring = await txn.query(
          'prepared_protection_activations',
          columns: ['session_id'],
          where: 'session_id = ?',
          whereArgs: [sessionId],
          limit: 1,
        );
        if (remaining.isEmpty && restoring.isEmpty) {
          await txn.delete(
            'sessions',
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
        }
      }
      return ids;
    });
  });
}
