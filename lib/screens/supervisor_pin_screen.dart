import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SupervisorPinScreen extends StatefulWidget {
  const SupervisorPinScreen({
    required this.verifyPin,
    this.heading = 'Periksa ujian terkunci',
    this.description =
        'Pengawas memasukkan PIN lima digit untuk membuka keputusan penanganan ujian.',
    this.initialFailedAttempts = 0,
    this.initialLockedUntil,
    this.onAttemptStateChanged,
    super.key,
  });

  final FutureOr<bool> Function(String pin) verifyPin;
  final String heading;
  final String description;
  final int initialFailedAttempts;
  final DateTime? initialLockedUntil;
  final void Function(int failedAttempts, DateTime? lockedUntil)?
  onAttemptStateChanged;

  @override
  State<SupervisorPinScreen> createState() => _SupervisorPinScreenState();
}

class _SupervisorPinScreenState extends State<SupervisorPinScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  late int _failedAttempts;
  DateTime? _lockedUntil;
  late int _remainingSeconds;
  String? _error;
  bool _checking = false;

  bool get _locked => _remainingSeconds > 0;

  @override
  void initState() {
    super.initState();
    _failedAttempts = widget.initialFailedAttempts;
    _lockedUntil = widget.initialLockedUntil;
    final milliseconds =
        _lockedUntil?.difference(DateTime.now()).inMilliseconds ?? 0;
    _remainingSeconds = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    if (_locked) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _failedAttempts = 0;
          _lockedUntil = null;
          _remainingSeconds = 0;
          _error = null;
        });
        widget.onAttemptStateChanged?.call(0, null);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _submit() async {
    if (_checking || _locked || _controller.text.length != 5) return;
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      if (await widget.verifyPin(_controller.text)) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final attempts = _failedAttempts + 1;
      final lockedUntil = attempts >= 5
          ? DateTime.now().add(const Duration(seconds: 30))
          : null;
      _controller.clear();
      if (!mounted) return;
      setState(() {
        _failedAttempts = attempts;
        _lockedUntil = lockedUntil;
        _remainingSeconds = lockedUntil == null ? 0 : 30;
        _error = lockedUntil == null
            ? 'PIN salah. Periksa kembali lalu coba lagi.'
            : null;
      });
      widget.onAttemptStateChanged?.call(attempts, lockedUntil);
      if (lockedUntil != null) _startTimer();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'PIN tidak dapat diperiksa. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = _remainingSeconds;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PIN Pengawas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFD6D6D6)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 32,
                color: Color(0xFF171717),
                semanticLabel: 'Verifikasi pengawas',
              ),
              const SizedBox(height: 16),
              Text(
                widget.heading,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF595959),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_locked && !_checking,
                obscureText: true,
                obscuringCharacter: '●',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [],
                enableSuggestions: false,
                autocorrect: false,
                maxLength: 5,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'PIN pengawas (5 digit)',
                  hintText: '•••••',
                  counterText: '',
                  errorText: _error,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    borderSide: BorderSide(color: Color(0xFF234A78), width: 2),
                  ),
                ),
              ),
              if (remainingSeconds > 0) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    color: const Color(0xFFFEF3F2),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Color(0xFFB42318),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Terlalu banyak percobaan. Coba lagi dalam $remainingSeconds detik.',
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed:
                    _controller.text.length == 5 && !_locked && !_checking
                    ? _submit
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: _checking
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verifikasi PIN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              const Text(
                'PIN tidak ditampilkan atau disimpan oleh layar ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF595959),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
