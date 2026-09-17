import 'dart:async';

import 'package:flutter/material.dart';

import '../services/form_url_policy.dart';

/// Stitch T02 - Data awal untuk membuat sesi guru.
class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({this.createSession, super.key});

  final FutureOr<bool> Function(String examName, Uri formUrl)? createSession;

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _examNameController = TextEditingController();
  final _formUrlController = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _examNameController.dispose();
    _formUrlController.dispose();
    super.dispose();
  }

  String? _validateExamName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Nama ujian wajib diisi.';
    if (name.length > 200) return 'Nama ujian maksimal 200 karakter.';
    return null;
  }

  String? _validateFormUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Link Google Forms wajib diisi.';
    final uri = Uri.tryParse(text);
    if (text.length > 2048 || uri == null || !isAllowedGoogleFormUrl(uri)) {
      return 'Gunakan link forms.gle atau docs.google.com/forms yang valid.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final formUrl = Uri.parse(_formUrlController.text.trim());
    final createSession = widget.createSession;
    if (createSession == null) {
      setState(
        () => _saveError =
            'Penyimpanan sesi belum tersedia. QR belum dapat dibuat.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final created = await createSession(
        _examNameController.text.trim(),
        formUrl,
      );
      if (!mounted) return;
      if (created) {
        setState(() => _saving = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.of(context).pop(true);
          }
        });
      } else {
        setState(
          () => _saveError =
              'Sesi belum diterbitkan. Periksa ruang penyimpanan dan kunci layar HP, lalu coba lagi.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError =
              'Sesi belum diterbitkan. Periksa ruang penyimpanan dan kunci layar HP, lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buat Sesi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFD6D6D6)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Buat sesi ujian',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Masukkan Google Forms untuk langsung membuat QR ujian.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xFF595959),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(
                  height: 2,
                  thickness: 2,
                  color: Color(0xFF171717),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _examNameController,
                  textInputAction: TextInputAction.next,
                  maxLength: 200,
                  validator: _validateExamName,
                  decoration: const InputDecoration(
                    labelText: 'Nama ujian',
                    hintText: 'Contoh: Matematika Kelas XI',
                    helperText: 'Ditampilkan kepada siswa bersama kode sesi.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _formUrlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: _validateFormUrl,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Link Google Forms',
                    hintText: 'https://docs.google.com/forms/d/e/.../viewform',
                    helperText: 'Gunakan link pengisian Form, bukan link edit.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF4DF),
                    border: Border(
                      left: BorderSide(color: Color(0xFF8A4B08), width: 4),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ketentuan Form pilot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Form harus dapat diisi tanpa login Google, tanpa upload file atau layanan luar, serta tanpa akses siswa ke edit respons atau kirim respons lain.',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Periksa link sebelum dibagikan. QR akan langsung dibuat setelah sesi disimpan.',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_saveError != null) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _saveError!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Buat QR Ujian',
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
      ),
    ),
  );
}
