import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';

/// Stitch S09 - Sesi Berakhir.
class EndedScreen extends StatefulWidget {
  const EndedScreen({
    required this.session,
    required this.endReason,
    required this.settingsRestored,
    required this.retryRestoreSettings,
    required this.onReturnHome,
    super.key,
  });

  final ExamSession session;
  final String endReason;
  final bool settingsRestored;
  final FutureOr<bool> Function() retryRestoreSettings;
  final VoidCallback onReturnHome;

  @override
  State<EndedScreen> createState() => _EndedScreenState();
}

class _EndedScreenState extends State<EndedScreen> {
  late bool _settingsRestored;
  bool _restoring = false;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    _settingsRestored = widget.settingsRestored;
  }

  Future<void> _retryRestoreSettings() async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _restoreError = null;
    });
    try {
      final restored = await widget.retryRestoreSettings();
      if (!mounted) return;
      setState(() {
        _settingsRestored = restored;
        _restoreError = restored
            ? null
            : 'Pengaturan perangkat belum dapat dipulihkan. Coba lagi.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _restoreError =
              'Pengaturan perangkat belum dapat dipulihkan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 24,
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                'ExamSeal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFD6D6D6)),
          ),
        ),
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.examName,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kode sesi: ${widget.session.sessionCode}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF595959),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(
                        height: 2,
                        thickness: 2,
                        color: Color(0xFF171717),
                      ),
                      const SizedBox(height: 32),
                      const Icon(
                        Icons.check_circle_outline,
                        size: 36,
                        color: Color(0xFF216E4E),
                        semanticLabel: 'Sesi berakhir',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sesi ujian berakhir',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFF3F3F3),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ALASAN PENGAKHIRAN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF595959),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.endReason,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Status ini bukan nilai dan bukan bukti bahwa Google Forms menerima jawaban.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF595959),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _settingsRestored
                                ? const Color(0xFFEDF7F1)
                                : const Color(0xFFFFF4DF),
                            border: Border(
                              left: BorderSide(
                                color: _settingsRestored
                                    ? const Color(0xFF216E4E)
                                    : const Color(0xFF8A4B08),
                                width: 4,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _settingsRestored
                                    ? Icons.settings_backup_restore
                                    : Icons.warning_amber_outlined,
                                color: _settingsRestored
                                    ? const Color(0xFF216E4E)
                                    : const Color(0xFF8A4B08),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _settingsRestored
                                      ? 'Pengaturan perangkat berhasil dipulihkan.'
                                      : 'Pengaturan perangkat belum selesai dipulihkan.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_settingsRestored) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _restoring ? null : _retryRestoreSettings,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          child: Text(
                            _restoring
                                ? 'Memulihkan Pengaturan...'
                                : 'Coba Pulihkan Lagi',
                          ),
                        ),
                        if (_restoreError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _restoreError!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFFB42318),
                            ),
                          ),
                        ],
                      ],
                      const Spacer(),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: _settingsRestored
                            ? widget.onReturnHome
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        child: const Text(
                          'Kembali ke Beranda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
