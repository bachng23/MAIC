import 'package:flutter/material.dart';

/// MediAgent "Blue" stitch tokens — forms, primary actions, focus rings.
abstract final class MedBlueTokens {
  static const Color background = Color(0xFFF7F9FC);
  static const Color primary = Color(0xFF0066CC);
  static const Color primaryDark = Color(0xFF004E9F);
  static const Color ink = Color(0xFF0B3A70);
  static const Color body = Color(0xFF414753);
  static const Color muted = Color(0xFF4C616C);
  static const Color inputFill = Color(0xFFF2F4F7);
  static const Color borderSubtle = Color(0x1AC1C6D5);
  static const Color accentChip = Color(0xFFD1E4FF);
  static const Color error = Color(0xFFBA1A1A);

  static InputDecoration inputDecoration({
    required String hint,
    String? label,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: inputFill,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderSubtle, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.85)),
    );
  }

  static ButtonStyle primaryFilled({double height = 56}) {
    return FilledButton.styleFrom(
      minimumSize: Size.fromHeight(height),
      backgroundColor: primary,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
    );
  }

  static ButtonStyle secondaryOutlined({double height = 48}) {
    return OutlinedButton.styleFrom(
      minimumSize: Size.fromHeight(height),
      foregroundColor: primaryDark,
      side: const BorderSide(color: primary, width: 1.5),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}
