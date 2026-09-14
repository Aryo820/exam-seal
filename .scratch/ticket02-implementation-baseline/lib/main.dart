import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'core/exam_app.dart';
import 'services/exam_protection.dart';
import 'services/exam_session_controller.dart';
import 'services/session_store.dart';
import 'services/teacher_session_secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Penyimpanan privat aplikasi (PRD FR12): buka SQLite sekali di root.
  final databasePath = await getDatabasesPath();
  final db = await openDatabase(
    p.join(databasePath, 'examseal.db'),
    version: 1,
  );
  final store = await SessionStore.open(db);

  final controller = ExamSessionController(
    store: store,
    secrets: TeacherSessionSecrets.secure(),
    now: () => DateTime.now(),
  );
  controller.attachProtection(ExamProtection());

  runApp(ExamSealRoot(controller: controller));
}

/// Akar aplikasi untuk pengujian widget: menjaga [ExamApp] tetap dapat
/// dipakai dengan controller test.
class ExamSealRoot extends StatelessWidget {
  const ExamSealRoot({required this.controller, super.key});

  final ExamSessionController controller;

  @override
  Widget build(BuildContext context) => ExamApp(controller: controller);
}
