import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/budget_models.dart';
import '../utils/formatters.dart';

class ReportService {
  Future<File> exportDailyReport({
    required BudgetBuddyState state,
    required BudgetSummary summary,
  }) async {
    final pw.Document document = pw.Document();

    document.addPage(
      pw.MultiPage(
        build: (pw.Context context) => <pw.Widget>[
          pw.Header(level: 0, child: pw.Text('BudgetBuddy Daily Report')),
          pw.SizedBox(height: 8),
          pw.Text('Profile: ${state.profile.displayName}'),
          pw.Text('Date: ${formatShortDate(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Text('Total budget: ${formatPeso(summary.totalBudget)}'),
          pw.Text('Total spent: ${formatPeso(summary.totalSpent)}'),
          pw.Text('Remaining balance: ${formatPeso(summary.remainingBalance)}'),
          pw.Text('Savings: ${formatPeso(summary.savings)}'),
          pw.SizedBox(height: 16),
          pw.Text(
              'Biggest expense category: ${summary.biggestExpenseCategory}'),
          pw.SizedBox(height: 12),
          pw.Text('Category breakdown'),
          pw.SizedBox(height: 6),
          ...summary.categoryTotals.entries.map(
            (MapEntry<String, double> entry) =>
                pw.Text('${entry.key}: ${formatPeso(entry.value)}'),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Smart insights'),
          pw.SizedBox(height: 6),
          ...summary.recommendedActions
              .map((String tip) => pw.Bullet(text: tip)),
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
    final Iterable<ExpenseEntry> rows = expenses ?? state.expenses;
    final StringBuffer buffer = StringBuffer()
      ..writeln('Date,Title,Category,Amount,Note,Source');
    for (final ExpenseEntry expense in rows) {
      buffer.writeln(
        '${formatShortDate(expense.dateTime)},"${expense.title.replaceAll('"', '""')}",${expense.category.label},${expense.amount.toStringAsFixed(2)},"${expense.note.replaceAll('"', '""')}",${expense.source}',
      );
    }

    final Directory directory = await getApplicationDocumentsDirectory();
    final File output =
        File('${directory.path}${Platform.pathSeparator}$fileName');
    await output.writeAsString(buffer.toString());
    return output;
  }
}
