import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetbuddy/core/models/budget_models.dart';

void main() {
  group('ThemeMode default on initial install', () {
    test('BudgetBuddyState.initial() defaults to light theme', () {
      final BudgetBuddyState state = BudgetBuddyState.initial();
      expect(state.themeMode, equals(ThemeMode.light));
    });

    test('BudgetBuddyState.fromJson without themeMode defaults to light theme', () {
      final BudgetBuddyState state = BudgetBuddyState.fromJson(<String, dynamic>{});
      expect(state.themeMode, equals(ThemeMode.light));
    });

    test('BudgetBuddyState.fromJson with legacy system theme maps to light theme', () {
      final BudgetBuddyState state = BudgetBuddyState.fromJson(<String, dynamic>{
        'themeMode': 'system',
      });
      expect(state.themeMode, equals(ThemeMode.light));
    });

    test('BudgetBuddyState.fromJson preserves dark theme if explicitly set', () {
      final BudgetBuddyState state = BudgetBuddyState.fromJson(<String, dynamic>{
        'themeMode': 'dark',
      });
      expect(state.themeMode, equals(ThemeMode.dark));
    });
  });
}
