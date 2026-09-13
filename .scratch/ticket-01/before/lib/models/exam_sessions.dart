class ExamSession {
  const ExamSession({
    required this.schemaVersion,
    required this.sessionId,
    required this.sessionCode,
    required this.examName,
    required this.formUrl,
  });

  final int schemaVersion;
  final String sessionId;
  final String sessionCode;
  final String examName;
  final Uri formUrl;
}
