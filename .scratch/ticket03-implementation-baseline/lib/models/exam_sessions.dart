/// Sesi ujian satu pelaksanaan (PRD §7: ExamSession). `schemaVersion` 2
/// membawa bahan verifikasi PIN (`pinSalt`, `pinVerifier`) di payload QR;
/// PIN mentah tidak pernah masuk QR. Schema 1 ditolak saat decode.
class ExamSession {
  ExamSession({
    required this.schemaVersion,
    required this.sessionId,
    required this.sessionCode,
    required this.examName,
    required this.formUrl,
    this.pinSalt,
    this.pinVerifier,
    this.securityPolicyVersion = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int schemaVersion;
  final String sessionId;
  final String sessionCode;
  final String examName;
  final Uri formUrl;

  /// Bahan verifikasi PIN sesi ini (base64). Null hanya pada data lama
  /// yang belum dimigrasi; alur produksi selalu mengisi keduanya.
  final String? pinSalt;
  final String? pinVerifier;

  /// Versi kebijakan keamanan inti yang mengikat sesi (ambang kunci 3,
  /// proteksi layar wajib, navigasi dibatasi).
  final int securityPolicyVersion;

  final DateTime createdAt;

  /// Sesi identik bila ID, URL Form, dan bahan verifikasi PIN sama.
  /// Payload dengan ID sama tetapi URL/verifier berbeda adalah konflik
  /// yang harus ditolak, bukan menimpa (FR02).
  bool sameIdentityAs(ExamSession other) =>
      sessionId == other.sessionId &&
      schemaVersion == other.schemaVersion &&
      sessionCode == other.sessionCode &&
      examName == other.examName &&
      securityPolicyVersion == other.securityPolicyVersion &&
      formUrl == other.formUrl &&
      pinSalt == other.pinSalt &&
      pinVerifier == other.pinVerifier;
}
