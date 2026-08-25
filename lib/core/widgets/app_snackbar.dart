import 'package:flutter/material.dart';

class AppSnackBar {
  static void show(BuildContext context, String message, {bool error = false, bool success = false}) {
    Color bg = Colors.grey;
    if (error) bg = Colors.redAccent;
    if (success) bg = Colors.green;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
