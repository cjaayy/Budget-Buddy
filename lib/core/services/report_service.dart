import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import '../models/budget_models.dart';

class ReportService {
  static const String backupSchemaVersion = '2.0';

  // ---------------------------------------------------------------------------
  // 1. PDF REPORT GENERATION
  // ---------------------------------------------------------------------------

  /// Generates a complete PDF report for a specific [month] or [isAllTime].
  Future<File> exportPdfReport({
    required BudgetBuddyState state,
    DateTime? month,
    bool isAllTime = true,
  }) async {
    final Uint8List bytes = await generatePdfBytes(
      state: state,
      month: month,
      isAllTime: isAllTime,
    );

    final String sanitizedMonth = month != null
        ? '${month.year}_${month.month.toString().padLeft(2, '0')}'
        : 'all_time';
    final String fileName = 'BudgetBuddy_Report_$sanitizedMonth.pdf';

    final Directory directory = await getApplicationDocumentsDirectory();
    final File output = File('${directory.path}${Platform.pathSeparator}$fileName');
    await output.writeAsBytes(bytes);
    return output;
  }

  /// Backward-compatible alias for existing callers.
  Future<File> exportDailyReport({
    required BudgetBuddyState state,
    required BudgetSummary summary,
    DateTime? month,
    bool isAllTime = true,
  }) =>
      exportPdfReport(state: state, month: month, isAllTime: isAllTime);

  /// Generates the raw PDF bytes suitable for Printing.sharePdf or printing.
  Future<Uint8List> generatePdfBytes({
    required BudgetBuddyState state,
    DateTime? month,
    bool isAllTime = true,
  }) async {
    final pw.Document document = pw.Document();

    // 1. Filter transactions according to selected range
    final List<ExpenseEntry> expenses = state.expenses.where((ExpenseEntry e) {
      if (isAllTime || month == null) return true;
      return e.dateTime.year == month.year && e.dateTime.month == month.month;
    }).toList()
      ..sort((ExpenseEntry a, ExpenseEntry b) => b.dateTime.compareTo(a.dateTime));

    final List<DailyRecord> dailyRecords = state.dailyRecords.where((DailyRecord r) {
      if (isAllTime || month == null) return true;
      return r.date.year == month.year && r.date.month == month.month;
    }).toList()
      ..sort((DailyRecord a, DailyRecord b) => b.date.compareTo(a.date));

    final List<BudgetEntry> budgetEntries = state.budgetEntries.where((BudgetEntry b) {
      if (isAllTime || month == null) return true;
      return b.date.year == month.year && b.date.month == month.month;
    }).toList();

    // 2. Financial totals calculation
    final double totalBudgetEntries =
        budgetEntries.fold(0.0, (double sum, BudgetEntry b) => sum + b.amount);
    final double fallbackBudget = (!isAllTime && month != null)
        ? (state.settings.monthlyLimit ?? (state.settings.dailyLimit ?? 0.0) * 30)
        : (state.settings.monthlyLimit ?? 0.0);
    final double totalBudget =
        totalBudgetEntries > 0 ? totalBudgetEntries : fallbackBudget;

    final double totalSpent =
        expenses.fold(0.0, (double sum, ExpenseEntry e) => sum + e.amount);
    final double netSafeBalance = totalBudget - totalSpent;
    final double periodSavings = dailyRecords.fold(
      0.0,
      (double sum, DailyRecord r) => sum + r.savings,
    );

    // 3. Category Breakdown Aggregation
    final Map<String, double> categoryTotals = <String, double>{};
    for (final ExpenseEntry expense in expenses) {
      final String label = _expenseCategoryLabel(expense);
      categoryTotals[label] = (categoryTotals[label] ?? 0.0) + expense.amount;
    }

    final String dateRangeLabel = isAllTime || month == null
        ? 'All-Time Full Financial Report'
        : DateFormat('MMMM yyyy').format(month);

    final String userName = state.profile.displayName.trim().isNotEmpty
        ? state.profile.displayName.trim()
        : 'Budget Buddy User';

    final pdf.PdfColor tealGreen = pdf.PdfColor.fromHex('#0F766E');
    final pdf.PdfColor darkRed = pdf.PdfColor.fromHex('#991B1B');
    final pdf.PdfColor goldAmber = pdf.PdfColor.fromHex('#D97706');
    final pdf.PdfColor cardBg = pdf.PdfColor.fromHex('#F8FAFC');
    final pdf.PdfColor borderColor = pdf.PdfColor.fromHex('#E2E8F0');
    final pdf.PdfColor textPrimary = pdf.PdfColor.fromHex('#0F172A');
    final pdf.PdfColor textSecondary = pdf.PdfColor.fromHex('#64748B');

    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        header: (pw.Context context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                'Budget Buddy Financial Report',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: tealGreen,
                ),
              ),
              pw.Text(
                dateRangeLabel,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
        footer: (pw.Context context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                'Confidential - 100% Local Device Export',
                style: pw.TextStyle(fontSize: 8, color: textSecondary),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: textSecondary),
              ),
            ],
          ),
        ),
        build: (pw.Context context) => <pw.Widget>[
          // Header Branding Block
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: cardBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              border: pw.Border.all(color: borderColor, width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      'BUDGET BUDDY REPORT',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: tealGreen,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Account: $userName',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Period: $dateRangeLabel',
                      style: pw.TextStyle(fontSize: 10, color: textSecondary),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text(
                      'Generated on',
                      style: pw.TextStyle(fontSize: 9, color: textSecondary),
                    ),
                    pw.Text(
                      DateFormat('MMM d, yyyy h:mm a').format(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        color: tealGreen,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'Verified Local Data',
                        style: pw.TextStyle(
                          color: pdf.PdfColors.white,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Financial Summary Block
          pw.Row(
            children: <pw.Widget>[
              // Total Budget
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: pdf.PdfColor.fromHex('#F0FDFA'),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: tealGreen, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        'TOTAL BUDGET / INPUTS',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: tealGreen,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'PHP ${totalBudget.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: tealGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),

              // Total Expenses
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: pdf.PdfColor.fromHex('#FEF2F2'),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: darkRed, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        'TOTAL EXPENSES / OUTPUTS',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: darkRed,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'PHP ${totalSpent.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: darkRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),

              // Net Safe Balance / Savings
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: netSafeBalance >= 0
                        ? pdf.PdfColor.fromHex('#F0FDF4')
                        : pdf.PdfColor.fromHex('#FEF2F2'),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(
                      color: netSafeBalance >= 0 ? goldAmber : darkRed,
                      width: 1,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        netSafeBalance >= 0
                            ? 'NET SAFE BALANCE'
                            : 'DEFICIT / OVERSPENT',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: netSafeBalance >= 0 ? goldAmber : darkRed,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'PHP ${netSafeBalance.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: netSafeBalance >= 0 ? goldAmber : darkRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // Category Breakdown Section
          if (categoryTotals.isNotEmpty) ...<pw.Widget>[
            pw.Text(
              'Category Breakdown',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: textPrimary,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: <String>[
                'Category',
                'Total Spent (PHP)',
                '% of Total Expenses',
              ],
              data: categoryTotals.entries.map((MapEntry<String, double> entry) {
                final double percentage =
                    totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
                return <String>[
                  entry.key,
                  'PHP ${entry.value.toStringAsFixed(2)}',
                  '${percentage.toStringAsFixed(1)}%',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                color: pdf.PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: tealGreen),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: <int, pw.Alignment>{
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              oddRowDecoration: pw.BoxDecoration(color: cardBg),
            ),
            pw.SizedBox(height: 18),
          ],

          // Detailed Expense Breakdown
          pw.Text(
            'Categorized Expense Transactions (${expenses.length} Records)',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: textPrimary,
            ),
          ),
          pw.SizedBox(height: 8),
          if (expenses.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: cardBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Text(
                'No expense transactions logged for this reporting period.',
                style: pw.TextStyle(fontSize: 10, color: textSecondary),
              ),
            )
          else
            pw.Table.fromTextArray(
              headers: <String>[
                'Date',
                'Category',
                'Title / Description',
                'Scope',
                'Amount (PHP)',
              ],
              data: expenses.map((ExpenseEntry e) {
                final String scope =
                    e.source == 'togetherSpend' ? 'Together' : 'Personal';
                return <String>[
                  DateFormat('MMM d, yyyy h:mm a').format(e.dateTime),
                  _expenseCategoryLabel(e),
                  e.title.trim().isNotEmpty
                      ? e.title
                      : (e.note.trim().isNotEmpty ? e.note : '-'),
                  scope,
                  'PHP ${e.amount.toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                color: pdf.PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: darkRed),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: <int, pw.Alignment>{
                4: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              oddRowDecoration: pw.BoxDecoration(color: cardBg),
            ),

          // Daily Records Section (Savings History)
          if (dailyRecords.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 18),
            pw.Text(
              'Daily Rollover & Savings Vault History (${dailyRecords.length} Days)',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: textPrimary,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: <String>[
                'Date',
                'Daily Spent',
                'Remaining',
                'Saved to Vault',
                'Top Category',
              ],
              data: dailyRecords.map((DailyRecord r) {
                return <String>[
                  DateFormat('MMM d, yyyy').format(r.date),
                  'PHP ${r.totalSpent.toStringAsFixed(2)}',
                  'PHP ${r.remainingBalance.toStringAsFixed(2)}',
                  'PHP ${r.savings.toStringAsFixed(2)}',
                  r.biggestExpenseCategory,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                color: pdf.PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: goldAmber),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: <int, pw.Alignment>{
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              oddRowDecoration: pw.BoxDecoration(color: cardBg),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  // ---------------------------------------------------------------------------
  // 2. CSV EXPORT ENGINE
  // ---------------------------------------------------------------------------

  /// Generates a structured CSV file with all transactions (Inputs, Outputs, Savings).
  Future<File> exportCsv({
    required BudgetBuddyState state,
    DateTime? month,
    bool isAllTime = true,
    String? fileName,
  }) async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    // 1. Filter and Collect Expenses (Outputs)
    final Iterable<ExpenseEntry> filteredExpenses = state.expenses.where((ExpenseEntry e) {
      if (isAllTime || month == null) return true;
      return e.dateTime.year == month.year && e.dateTime.month == month.month;
    });

    for (final ExpenseEntry expense in filteredExpenses) {
      rows.add(<String, dynamic>{
        'date': expense.dateTime,
        'type': 'Expense',
        'category': _expenseCategoryLabel(expense),
        'description': expense.title.isNotEmpty ? expense.title : expense.note,
        'amount': -expense.amount,
        'scope': expense.source == 'togetherSpend' ? 'Together' : 'Personal',
      });
    }

    // 2. Collect Budget Entries (Inputs)
    final Iterable<BudgetEntry> filteredBudgets = state.budgetEntries.where((BudgetEntry b) {
      if (isAllTime || month == null) return true;
      return b.date.year == month.year && b.date.month == month.month;
    });

    for (final BudgetEntry budget in filteredBudgets) {
      rows.add(<String, dynamic>{
        'date': budget.date,
        'type': 'Budget Allocation',
        'category': 'Budget',
        'description': 'Daily Target Budget',
        'amount': budget.amount,
        'scope': 'Personal',
      });
    }

    // 3. Collect Vault Log Entries (Savings deposits/withdrawals)
    final Iterable<VaultLogEntry> filteredVault = state.vaultLog.where((VaultLogEntry v) {
      if (isAllTime || month == null) return true;
      return v.dateTime.year == month.year && v.dateTime.month == month.month;
    });

    for (final VaultLogEntry log in filteredVault) {
      final bool isDeposit = log.type == VaultLogType.deposit;
      rows.add(<String, dynamic>{
        'date': log.dateTime,
        'type': isDeposit ? 'Savings Deposit' : 'Savings Withdrawal',
        'category': 'Vault Savings',
        'description': log.description,
        'amount': isDeposit ? log.amount : -log.amount,
        'scope': log.isTogether ? 'Together' : 'Personal',
      });
    }

    // Sort chronologically
    rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Construct CSV String
    final StringBuffer buffer = StringBuffer('\uFEFF');
    buffer.writeln(
      '"Date","Type","Category","Description","Amount (PHP)","Scope"',
    );

    for (final Map<String, dynamic> row in rows) {
      final DateTime date = row['date'] as DateTime;
      final String dateStr =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
      final String type = row['type'] as String;
      final String category = row['category'] as String;
      final String description = (row['description'] as String).trim();
      final double amount = row['amount'] as double;
      final String scope = row['scope'] as String;

      buffer.writeln(
        '"$dateStr","${_escapeCsv(type)}","${_escapeCsv(category)}","${_escapeCsv(description)}",${amount.toStringAsFixed(2)},"${_escapeCsv(scope)}"',
      );
    }

    final String sanitizedMonth = month != null
        ? '${month.year}_${month.month.toString().padLeft(2, '0')}'
        : 'all_time';
    final String resolvedFileName =
        fileName ?? 'budget_buddy_report_$sanitizedMonth.csv';

    final Directory directory = await getApplicationDocumentsDirectory();
    final File output =
        File('${directory.path}${Platform.pathSeparator}$resolvedFileName');
    await output.writeAsString(buffer.toString());
    return output;
  }

  // ---------------------------------------------------------------------------
  // 3. JSON BACKUP & RESTORE SERIALIZATION ENGINE
  // ---------------------------------------------------------------------------

  /// Creates a structured backup JSON string with metadata.
  String createBackupJson(BudgetBuddyState state) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': backupSchemaVersion,
      'appName': 'Budget Buddy',
      'backupDate': DateTime.now().toIso8601String(),
      'profileName': state.profile.displayName,
      'data': state.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Validates and parses raw backup JSON text into a [BudgetBuddyState].
  /// Supports both standard metadata-wrapped backups and raw state backups.
  BudgetBuddyState validateAndParseBackup(String rawJson) {
    final String clean = rawJson.replaceAll('\uFEFF', '').trim();
    if (clean.isEmpty) {
      throw const FormatException('Selected backup file is empty.');
    }

    final dynamic decoded = jsonDecode(clean);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON root format: Expected an object.');
    }

    // Case 1: Wrapped with metadata
    if (decoded.containsKey('data') && decoded['data'] is Map) {
      final Map<String, dynamic> dataMap =
          (decoded['data'] as Map).cast<String, dynamic>();
      _validateDataSchema(dataMap);
      return BudgetBuddyState.fromJson(dataMap);
    }

    // Case 2: Direct state serialization (backward compatibility)
    _validateDataSchema(decoded);
    return BudgetBuddyState.fromJson(decoded);
  }

  void _validateDataSchema(Map<String, dynamic> map) {
    final bool hasExpenses = map.containsKey('expenses');
    final bool hasProfile = map.containsKey('profile');
    final bool hasSettings = map.containsKey('settings');

    if (!hasExpenses && !hasProfile && !hasSettings) {
      throw const FormatException(
        'JSON data does not match the Budget Buddy database schema.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _expenseCategoryLabel(ExpenseEntry expense) {
    final String selectedCategory = expense.spendCategory.trim();
    if (selectedCategory.isNotEmpty) {
      return selectedCategory;
    }
    return expense.category.label;
  }

  String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }
}
