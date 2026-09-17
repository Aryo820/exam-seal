// Sesi ujian satu pelaksanaan.

class ExamSession {
  ExamSession({
    required this.schemaVersion,
    required this.sessionId,
    required this.sessionCode,
    required this.examName,
    required this.formUrl,
    this.securityPolicyVersion = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int schemaVersion;
  final String sessionId;
  final String sessionCode;
  final String examName;
  final Uri formUrl;

  /// Versi kebijakan keamanan inti yang mengikat sesi (ambang kunci 3,
  /// proteksi layar wajib, navigasi dibatasi).
  final int securityPolicyVersion;

  final DateTime createdAt;

  /// Sesi dengan ID sama tetapi detail publik berbeda adalah konflik.
  bool sameIdentityAs(ExamSession other) =>
      sessionId == other.sessionId &&
      schemaVersion == other.schemaVersion &&
      sessionCode == other.sessionCode &&
      examName == other.examName &&
      securityPolicyVersion == other.securityPolicyVersion &&
      formUrl == other.formUrl;
}
