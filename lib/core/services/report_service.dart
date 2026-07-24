import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import '../models/budget_models.dart';

class ReportService {
  Future<File> exportDailyReport({
    required BudgetBuddyState state,
    required BudgetSummary summary,
  }) async {
    final pw.Document document = pw.Document();
    final List<ExpenseEntry> expenses = state.expenses
        .where((ExpenseEntry e) => e.source != 'togetherSpend')
        .toList()
      ..sort(
        (ExpenseEntry left, ExpenseEntry right) =>
            right.dateTime.compareTo(left.dateTime),
      );
    final List<DailyRecord> dailyRecords = state.dailyRecords.toList()
      ..sort(
        (DailyRecord left, DailyRecord right) =>
            right.date.compareTo(left.date),
      );

    document.addPage(
      pw.MultiPage(
        build: (pw.Context context) => <pw.Widget>[
          pw.Header(level: 0, child: pw.Text('BudgetBuddy Financial Report')),
          pw.SizedBox(height: 8),
          pw.Text('Profile: ${state.profile.displayName}'),
          pw.Text(
              'Generated: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Text('Summary',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border:
                pw.TableBorder.all(color: pdf.PdfColors.grey300, width: 0.5),
            columnWidths: <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: <pw.TableRow>[
              _buildKeyValueRow(
                  'Total budget', _formatReportAmount(summary.totalBudget)),
              _buildKeyValueRow(
                  'Total spent', _formatReportAmount(summary.totalSpent)),
              _buildKeyValueRow('Remaining balance',
                  _formatReportAmount(summary.remainingBalance)),
              _buildKeyValueRow(
                  'Savings', _formatReportAmount(summary.savings)),
              _buildKeyValueRow(
                  'Biggest category', summary.biggestExpenseCategory),
              _buildKeyValueRow('Expenses logged', expenses.length.toString()),
              _buildKeyValueRow(
                  'Savings records', dailyRecords.length.toString()),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Category breakdown',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border:
                pw.TableBorder.all(color: pdf.PdfColors.grey300, width: 0.5),
            children: <pw.TableRow>[
              _buildHeaderRow(<String>['Category', 'Amount']),
              ...summary.categoryTotals.entries.map(
                (MapEntry<String, double> entry) => _buildDataRow(
                  <String>[
                    entry.key,
                    _formatReportAmount(entry.value),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Recent expenses',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border:
                pw.TableBorder.all(color: pdf.PdfColors.grey300, width: 0.5),
            columnWidths: <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: <pw.TableRow>[
              _buildHeaderRow(
                  <String>['Date', 'Title', 'Category', 'Amount', 'Note']),
              ...expenses.map(
                (ExpenseEntry expense) => _buildDataRow(
                  <String>[
                    DateFormat('MMM d, yyyy h:mm a').format(expense.dateTime),
                    expense.title,
                    _expenseReportCategoryLabel(expense),
                    _formatReportAmount(expense.amount),
                    expense.note.isEmpty ? '-' : expense.note,
                  ],
                ),
              ),
            ],
          ),
          if (dailyRecords.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 16),
            pw.Text('Savings records',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border:
                  pw.TableBorder.all(color: pdf.PdfColors.grey300, width: 0.5),
              children: <pw.TableRow>[
                _buildHeaderRow(<String>[
                  'Date',
                  'Spent',
                  'Remaining',
                  'Savings',
                  'Top category'
                ]),
                ...dailyRecords.map(
                  (DailyRecord record) => _buildDataRow(
                    <String>[
                      DateFormat('MMM d, yyyy').format(record.date),
                      _formatReportAmount(record.totalSpent),
                      _formatReportAmount(record.remainingBalance),
                      _formatReportAmount(record.savings),
                      record.biggestExpenseCategory,
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (state.periodReports.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 16),
            pw.Text('Period reports',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border:
                  pw.TableBorder.all(color: pdf.PdfColors.grey300, width: 0.5),
              children: <pw.TableRow>[
                _buildHeaderRow(<String>[
                  'Period',
                  'Start',
                  'End',
                  'Limit',
                  'Spent',
                  'Saved'
                ]),
                ...state.periodReports.map(
                  (PeriodReport report) => _buildDataRow(
                    <String>[
                      report.period.label,
                      DateFormat('MMM d, yyyy').format(report.startDate),
                      DateFormat('MMM d, yyyy').format(report.endDate),
                      _formatReportAmount(report.limit),
                      _formatReportAmount(report.totalSpent),
                      _formatReportAmount(report.savedAmount),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final Directory directory = await getApplicationDocumentsDirectory();
    final File output = File(
        '${directory.path}${Platform.pathSeparator}BudgetBuddy_Daily_Report.pdf');
    await output.writeAsBytes(await document.save());
    return output;
  }

  Future<File> exportCsv({
    required BudgetBuddyState state,
    String fileName = 'BudgetBuddy_Expenses.csv',
    Iterable<ExpenseEntry>? expenses,
  }) async {
    final List<ExpenseEntry> rows = (expenses ?? state.expenses).toList()
      ..sort(
        (ExpenseEntry left, ExpenseEntry right) =>
            left.dateTime.compareTo(right.dateTime),
      );
    final StringBuffer buffer = StringBuffer('\uFEFF')
      ..writeln('"Date","Title","Sub Category","Category","Amount","Note","Source"');
    for (final ExpenseEntry expense in rows) {
      final String dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(expense.dateTime);
      final String subCategory = expense.spendCategory.trim().isEmpty
          ? _expenseReportCategoryLabel(expense)
          : expense.spendCategory.trim();
      buffer.writeln(
        '"$dateStr","${_escapeCsv(expense.title)}","${_escapeCsv(subCategory)}","${_escapeCsv(expense.category.label)}",${expense.amount.toStringAsFixed(2)},"${_escapeCsv(expense.note)}","${_escapeCsv(expense.source)}"',
      );
    }

    final Directory directory = await getApplicationDocumentsDirectory();
    final File output =
        File('${directory.path}${Platform.pathSeparator}$fileName');
    await output.writeAsString(buffer.toString());
    return output;
  }

  pw.TableRow _buildHeaderRow(List<String> cells) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey200),
      children: cells
          .map(
            (String cell) => pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                cell,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _buildDataRow(List<String> cells) {
    return pw.TableRow(
      children: cells
          .map(
            (String cell) => pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(cell),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _buildKeyValueRow(String key, String value) {
    return pw.TableRow(
      children: <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child:
              pw.Text(key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value),
        ),
      ],
    );
  }

  String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }

  String _expenseReportCategoryLabel(ExpenseEntry expense) {
    final String selectedCategory = expense.spendCategory.trim();
    if (selectedCategory.isNotEmpty) {
      return selectedCategory;
    }
    return expense.category.label;
  }

  String _formatReportAmount(double amount) {
    return amount.toStringAsFixed(2);
  }
}
