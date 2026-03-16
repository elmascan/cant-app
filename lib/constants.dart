import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFEFF6FF);
  static const primaryDark = Color(0xFF1D4ED8);
  static const secondary = Color(0xFF059669);
  static const accent = Color(0xFFEA580C);
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
}

class AppConfig {
  static const supabaseUrl = 'https://fdufywtmebyuihjznahp.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWZ5d3RtZWJ5dWloanpuYWhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMjI0MjIsImV4cCI6MjA4ODc5ODQyMn0.mCiA7-ayDYdV6BvcmsOxel6zy8ZHSyCcrqzanuIgYhw';
}

const List<Map<String, String>> kSports = [
  {'name': 'Football', 'emoji': '⚽'},
  {'name': 'Basketball', 'emoji': '🏀'},
  {'name': 'Tennis', 'emoji': '🎾'},
  {'name': 'Volleyball', 'emoji': '🏐'},
  {'name': 'Swimming', 'emoji': '🏊'},
  {'name': 'Running', 'emoji': '🏃'},
  {'name': 'Cycling', 'emoji': '🚴'},
  {'name': 'Badminton', 'emoji': '🏸'},
  {'name': 'Table Tennis', 'emoji': '🏓'},
  {'name': 'Bouldering', 'emoji': '🧗'},
  {'name': 'Yoga', 'emoji': '🧘'},
  {'name': 'Hiking', 'emoji': '🥾'},
  {'name': 'PlayStation', 'emoji': '🎮'},
  {'name': 'Drinking', 'emoji': '🍺'},
];

String getSportEmoji(String sport) {
  final match = kSports.firstWhere(
    (s) => s['name']!.toLowerCase() == sport.toLowerCase(),
    orElse: () => {'emoji': '🏃'},
  );
  return match['emoji']!;
}
