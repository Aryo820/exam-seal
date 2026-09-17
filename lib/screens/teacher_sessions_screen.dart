import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import 'create_session_screen.dart';
import 'session_qr_screen.dart';

/// Stitch T01 - Daftar sesi lokal pada HP guru.
class TeacherSessionsScreen extends StatefulWidget {
  const TeacherSessionsScreen({
    this.sessions = const [],
    this.canCreateSession = true,
    this.canDeleteSession = true,
    this.onCreateSession,
    this.onShowQr,
    this.onDeleteSession,
    this.loadSessions,
    super.key,
  });

  final List<ExamSession> sessions;
  final bool canCreateSession;
  final bool canDeleteSession;
  final FutureOr<void> Function()? onCreateSession;
  final ValueChanged<ExamSession>? onShowQr;

  /// Hapus satu sesi; mengembalikan pesan kegagalan, atau null bila berhasil.
  /// Konfirmasi dan pemuatan ulang daftar dilakukan layar ini.
  final Future<String?> Function(ExamSession session)? onDeleteSession;

  final Future<List<ExamSession>> Function()? loadSessions;

  @override
  State<TeacherSessionsScreen> createState() => _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends State<TeacherSessionsScreen> {
  late List<ExamSession> sessions = widget.sessions;
  bool _loading = false;
  String? _error;
  String? _deleteError;
  String? _deletingSessionId;

  @override
  void initState() {
    super.initState();
    if (widget.loadSessions != null) unawaited(_load());
  }

  Future<void> _load() async {
    final load = widget.loadSessions;
    if (load == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loaded = await load();
      if (mounted) setState(() => sessions = loaded);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Daftar sesi tidak dapat dibuka. Pastikan percobaan siswa sudah selesai dan penyimpanan tersedia, lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSession(ExamSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
        title: const Text('Hapus sesi ini?'),
        content: Text(
          'Sesi "${session.examName}", seluruh riwayat percobaan lokalnya, dan '
          'penanda pembatasan pengulangan lokal ikut terhapus. Perangkat ini '
          'tidak lagi mengenali percobaan lama untuk sesi tersebut. Status '
          'berakhir bukan bukti jawaban Google Forms sudah terkirim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Sesi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final callback = widget.onDeleteSession;
    setState(() {
      _deletingSessionId = session.sessionId;
      _deleteError = null;
    });
    try {
      final failure = callback == null ? null : await callback(session);
      if (!mounted) return;
      if (failure != null) {
        setState(() => _deleteError = failure);
        return;
      }
      if (widget.loadSessions == null) {
        setState(
          () => sessions = sessions
              .where((item) => item.sessionId != session.sessionId)
              .toList(),
        );
      } else {
        await _load();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _deleteError =
              'Sesi belum dapat dihapus. Periksa penyimpanan lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _deletingSessionId = null);
    }
  }

  Future<void> _createSession(BuildContext context) async {
    final callback = widget.onCreateSession;
    if (callback != null) {
      await callback();
      if (mounted) await _load();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Sesi Guru',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFD6D6D6)),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          const Text(
            'Sesi ujian',
            style: TextStyle(
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kelola sesi Google Forms yang dibuat dan disimpan di perangkat ini.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF595959),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F3F3),
              border: Border(
                left: BorderSide(color: Color(0xFF171717), width: 4),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone_android_outlined, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sesi tersimpan lokal di HP ini. Tidak ada sinkronisasi cloud atau pemantauan siswa.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading || _error != null || !widget.canCreateSession
                ? null
                : () => _createSession(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Buat QR Ujian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (!widget.canCreateSession) ...[
            const SizedBox(height: 12),
            const Text(
              'Perubahan sesi ditahan selama percobaan siswa berlangsung.',
              style: TextStyle(fontSize: 13, color: Color(0xFF595959)),
            ),
          ],
          if (_deleteError != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3F2),
                border: Border(
                  left: BorderSide(color: Color(0xFFB42318), width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 20,
                        color: Color(0xFFB42318),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deleteError!,
                          semanticsLabel: _deleteError,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() => _deleteError = null),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sesi tersimpan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${sessions.length} sesi',
                style: const TextStyle(fontSize: 13, color: Color(0xFF595959)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(_error!, semanticsLabel: _error),
            TextButton(onPressed: _load, child: const Text('Coba Lagi')),
          ] else if (sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD6D6D6)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.inbox_outlined, size: 28),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada sesi ujian',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Buat sesi baru untuk menyiapkan ujian dan QR yang akan dipindai siswa.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF595959),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final session in sessions) ...[
              _SessionCard(
                session: session,
                deleting: _deletingSessionId == session.sessionId,
                onDelete: widget.canDeleteSession && _deletingSessionId == null
                    ? () => _deleteSession(session)
                    : null,
                onShowQr: () {
                  final callback = widget.onShowQr;
                  if (callback != null) {
                    callback(session);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SessionQrScreen(session: session),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    ),
  );
}

/// Tindakan per sesi yang dipilih dari lembar tindakan.
enum _SessionAction { delete }

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onShowQr,
    this.onDelete,
    this.deleting = false,
  });

  final ExamSession session;
  final VoidCallback onShowQr;

  /// Null bila penghapusan sedang ditahan, misalnya percobaan siswa belum
  /// selesai; lembar tindakan tetap terbuka dan menjelaskan penahannya.
  final VoidCallback? onDelete;

  final bool deleting;

  Future<void> _openActions(BuildContext context) async {
    final action = await showModalBottomSheet<_SessionAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (_) =>
          _SessionActionsSheet(session: session, canDelete: onDelete != null),
    );
    if (action == _SessionAction.delete) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF737373)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                session.examName,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (deleting)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: () => _openActions(context),
                tooltip: 'Opsi sesi',
                color: const Color(0xFF171717),
                icon: const Icon(Icons.more_vert_rounded),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Kode sesi: ${session.sessionCode}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF595959)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onShowQr,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: const Color(0xFF171717),
            side: const BorderSide(color: Color(0xFF171717)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          icon: const Icon(Icons.qr_code_2, size: 20),
          label: const Text('Tampilkan QR'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Menampilkan QR ini tidak membuat sesi baru.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF595959)),
        ),
      ],
    ),
  );
}

/// Lembar tindakan satu sesi (ikon more_vert). Tindakan destruktif tetap
/// meminta konfirmasi dialog setelah dipilih; lembar ini tidak mengubah
/// sesi atau attempt.
class _SessionActionsSheet extends StatelessWidget {
  const _SessionActionsSheet({required this.session, required this.canDelete});

  final ExamSession session;
  final bool canDelete;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.examName,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kode sesi: ${session.sessionCode}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF595959)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFD6D6D6)),
        InkWell(
          onTap: canDelete
              ? () => Navigator.of(context).pop(_SessionAction.delete)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 22,
                  color: canDelete
                      ? const Color(0xFFB42318)
                      : const Color(0xFF595959),
                ),
                const SizedBox(width: 12),
                Text(
                  'Hapus Sesi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: canDelete
                        ? const Color(0xFFB42318)
                        : const Color(0xFF595959),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (canDelete)
          const SizedBox(height: 8)
        else ...[
          const Divider(height: 1, color: Color(0xFFD6D6D6)),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Text(
              'Penghapusan sesi ditahan selama percobaan siswa berlangsung.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF595959),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
