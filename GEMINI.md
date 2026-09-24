# Workspace Development Rules & Preferences

## 1. Direct Edit Protocol (Strict)
- **Direct Edits Only**: When the user requests changes, immediately edit the code using `replace_file_content`, `multi_replace_file_content`, or `write_to_file`.
- **NO flutter analyze / dart analyze**: NEVER run `flutter analyze` or `dart analyze` after making edits.
- **NO flutter test**: NEVER run `flutter test` or any test suites unless the user explicitly asks to run tests.
- **Minimize Execution Time**: Prioritize fast turnaround. Avoid running slow shell commands or test runners in background/foreground.

## 2. Code Quality & Verification
- Perform syntax, null-safety, and type-checks manually in-code before writing files.
- Double-check line ranges, brackets, and parameter names without running terminal analyzers.

## 3. Design System & Palette Consistency
- **Unified Color Palette**:
  - **Dark Red (`#991B1B`)**: Expenses, delete actions, over-limit warnings, negative balances.
  - **Gold (`#D97706`)**: Target budgets, edit actions, daily history counts, monthly records, alerts.
  - **Dark Green (`#0F766E`)**: Remaining safe balance, details / view actions, save / submit confirmations.
- **Solid Action Buttons**:
  - **Edit**: Full solid Gold background (`#D97706`) with white text and icon.
  - **Delete**: Full solid Dark Red background (`#991B1B`) with white text and icon.
  - **Details**: Full solid Dark Green background (`#0F766E`) with white text and icon.
