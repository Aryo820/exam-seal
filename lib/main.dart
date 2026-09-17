import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'core/exam_app.dart';
import 'services/exam_protection.dart';
import 'services/exam_session_controller.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await startExamSeal();
}

Future<void> startExamSeal({
  Future<ExamSessionController> Function()? openController,
}) async {
  final open = openController ?? _openController;
  try {
    runApp(ExamSealRoot(controller: await open()));
  } catch (_) {
    runApp(
      StorageFailureApp(
        onRetry: () => unawaited(startExamSeal(openController: open)),
      ),
    );
  }
}

Future<ExamSessionController> _openController() async {
  // Penyimpanan privat aplikasi (PRD FR12): buka SQLite sekali di root.
  final databasePath = await getDatabasesPath();
  final db = await openDatabase(
    p.join(databasePath, 'examseal.db'),
    version: 1,
  );
  final store = await SessionStore.open(db);

  final controller = ExamSessionController(
    store: store,
    now: () => DateTime.now(),
  );
  controller.attachProtection(ExamProtection());

  return controller;
}

class StorageFailureApp extends StatelessWidget {
  const StorageFailureApp({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ExamSeal',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_outlined, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Penyimpanan ujian tidak dapat dibuka. Minta pengawas memeriksa perangkat sebelum ujian dilanjutkan.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Coba Pulihkan'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Akar aplikasi untuk pengujian widget: menjaga [ExamApp] tetap dapat
/// dipakai dengan controller test.
class ExamSealRoot extends StatelessWidget {
  const ExamSealRoot({required this.controller, super.key});

  final ExamSessionController controller;

  @override
  Widget build(BuildContext context) => ExamApp(controller: controller);
}
