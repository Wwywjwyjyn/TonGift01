import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData get dark {
    const bg = Color(AppColors.bg);
    const card = Color(AppColors.card);
    const yellow = Color(AppColors.yellow);
    const text = Color(AppColors.text);
    const dim = Color(AppColors.textDim);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Vazirmatn',
      colorScheme: const ColorScheme.dark(
        primary: yellow,
        onPrimary: Color(0xFF111111),
        secondary: yellow,
        surface: Color(AppColors.surface),
        onSurface: text,
        error: Color(AppColors.red),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          color: text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(AppColors.stroke)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: Color(AppColors.stroke), thickness: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(AppColors.surface),
        selectedItemColor: yellow,
        unselectedItemColor: dim,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11),
        unselectedLabelStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(color: dim, fontFamily: 'Vazirmatn'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(AppColors.stroke)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(AppColors.stroke)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: yellow, width: 1.4),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontFamily: 'Vazirmatn', color: text, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontFamily: 'Vazirmatn', color: text, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontFamily: 'Vazirmatn', color: text),
        bodySmall: TextStyle(fontFamily: 'Vazirmatn', color: dim),
        labelSmall: TextStyle(fontFamily: 'Vazirmatn', color: dim),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(fontFamily: 'Vazirmatn', color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(AppColors.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(AppColors.card),
        labelStyle: TextStyle(fontFamily: 'Vazirmatn', color: text, fontSize: 12),
        side: BorderSide(color: Color(AppColors.stroke)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: yellow,
        selectionColor: Color(AppColors.yellowDim),
        selectionHandleColor: yellow,
      ),
    );
  }
}
