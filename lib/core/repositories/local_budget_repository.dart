
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_models.dart';

class LocalBudgetRepository {
  static const String _boxName = 'budgetbuddy_cache';
  static const String _stateKey = 'budgetbuddy_state';
  static const String _themeKey = 'theme_mode';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _loggedInKey = 'logged_in';
  static const String _onboardingKey = 'onboarding_complete';

  Box<String>? _box;
  SharedPreferences? _prefs;

  Future<void> _ensureReady() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>(_boxName);
    }
  }

  Future<BudgetBuddyState> loadState() async {
    await _ensureReady();
    final String? rawState = _box!.get(_stateKey);

    BudgetBuddyState state = rawState == null || rawState.isEmpty
        ? BudgetBuddyState.initial()
        : BudgetBuddyState.decode(rawState);

    final String themeName = _prefs?.getString(_themeKey) ?? state.themeMode.name;
    final bool notificationsEnabled = _prefs?.getBool(_notificationsKey) ?? state.notificationsEnabled;
    final bool loggedIn = _prefs?.getBool(_loggedInKey) ?? state.loggedIn;
    final bool onboardingComplete = _prefs?.getBool(_onboardingKey) ?? state.onboardingComplete;

    state = state.copyWith(
      themeMode: ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      notificationsEnabled: notificationsEnabled,
      loggedIn: loggedIn,
      onboardingComplete: onboardingComplete,
      isBootstrapping: false,
    );

    return state;
  }

  Future<void> saveState(BudgetBuddyState state) async {
    await _ensureReady();
    await _box!.put(_stateKey, state.encode());
    await _prefs!.setString(_themeKey, state.themeMode.name);
    await _prefs!.setBool(_notificationsKey, state.notificationsEnabled);
    await _prefs!.setBool(_loggedInKey, state.loggedIn);
    await _prefs!.setBool(_onboardingKey, state.onboardingComplete);
  }

  Future<void> clearAll() async {
    await _ensureReady();
    await _box!.clear();
    await _prefs!.clear();
  }
}