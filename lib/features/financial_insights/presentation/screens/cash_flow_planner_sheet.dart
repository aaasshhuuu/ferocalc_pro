import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/financial_profile.dart';

/// Interactive modal sheet to configure or edit the local Cash Flow Profile.
class CashFlowPlannerSheet extends StatefulWidget {
  const CashFlowPlannerSheet({
    Key? key,
    required this.initialProfile,
    required this.onSave,
    required this.onClear,
  }) : super(key: key);

  final FinancialProfile initialProfile;
  final ValueChanged<FinancialProfile> onSave;
  final VoidCallback onClear;

  static Future<void> show(
    BuildContext context, {
    required FinancialProfile profile,
    required ValueChanged<FinancialProfile> onSave,
    required VoidCallback onClear,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CashFlowPlannerSheet(
        initialProfile: profile,
        onSave: onSave,
        onClear: onClear,
      ),
    );
  }

  @override
  State<CashFlowPlannerSheet> createState() => _CashFlowPlannerSheetState();
}

class _CashFlowPlannerSheetState extends State<CashFlowPlannerSheet> {
  static const Color gold = Color(0xFFC9A96E);

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _incomeController;
  late TextEditingController _essentialController;
  late TextEditingController _discretionaryController;
  late TextEditingController _emiController;
  late TextEditingController _savingsController;
  late TextEditingController _emergencyController;

  late int _emergencyTargetMonths;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _incomeController = TextEditingController(
      text: p.monthlyIncome > 0 ? p.monthlyIncome.toStringAsFixed(0) : '',
    );
    _essentialController = TextEditingController(
      text: p.essentialExpenses > 0 ? p.essentialExpenses.toStringAsFixed(0) : '',
    );
    _discretionaryController = TextEditingController(
      text: p.discretionaryExpenses > 0
          ? p.discretionaryExpenses.toStringAsFixed(0)
          : '',
    );
    _emiController = TextEditingController(
      text: p.monthlyEmi > 0 ? p.monthlyEmi.toStringAsFixed(0) : '',
    );
    _savingsController = TextEditingController(
      text: p.declaredSavings > 0 ? p.declaredSavings.toStringAsFixed(0) : '',
    );
    _emergencyController = TextEditingController(
      text: p.emergencySavings > 0 ? p.emergencySavings.toStringAsFixed(0) : '',
    );
    _emergencyTargetMonths = p.emergencyTargetMonths;
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _essentialController.dispose();
    _discretionaryController.dispose();
    _emiController.dispose();
    _savingsController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  double _parseField(TextEditingController controller) {
    final text = controller.text.replaceAll(',', '').trim();
    if (text.isEmpty) return 0.0;
    final val = double.tryParse(text);
    if (val == null || val < 0) return 0.0;
    // Cap at sensible bound: ₹100 Crores
    return val.clamp(0.0, 1000000000.0);
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.initialProfile.copyWith(
      monthlyIncome: _parseField(_incomeController),
      essentialExpenses: _parseField(_essentialController),
      discretionaryExpenses: _parseField(_discretionaryController),
      monthlyEmi: _parseField(_emiController),
      declaredSavings: _parseField(_savingsController),
      emergencySavings: _parseField(_emergencyController),
      emergencyTargetMonths: _emergencyTargetMonths,
      updatedAt: DateTime.now(),
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  Future<void> _handleConfirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text(
              'Reset Cash Flow Profile?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'This will clear all monthly income, expenses, and savings inputs from your device. Your saved calculation history and financial goals will NOT be deleted.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Profile'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onClear();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xFF161F30) : Colors.white;
    final cardBorder =
        isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: gold,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cash Flow Planner',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Stored strictly on your device',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Privacy notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gold.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: gold, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Privacy First: FeroCalc never links your bank accounts or transmits your financial profile to servers.',
                          style: TextStyle(fontSize: 12, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section 1: Income
                _buildSectionTitle('1. Monthly Income', Icons.payments_outlined),
                _buildNumberField(
                  controller: _incomeController,
                  label: 'Monthly Take-Home Income (₹)',
                  hint: 'e.g. 85000',
                  helper: 'Net post-tax earnings credited to your bank account',
                ),
                const SizedBox(height: 16),

                // Section 2: Outflows
                _buildSectionTitle('2. Monthly Outflows', Icons.trending_down),
                _buildNumberField(
                  controller: _essentialController,
                  label: 'Essential Living Expenses (₹)',
                  hint: 'e.g. 35000',
                  helper: 'Rent, groceries, utilities, basic medical, insurance',
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  controller: _discretionaryController,
                  label: 'Discretionary Expenses (₹)',
                  hint: 'e.g. 15000',
                  helper: 'Dining out, shopping, entertainment, subscriptions',
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  controller: _emiController,
                  label: 'Committed Debt & EMIs (₹)',
                  hint: 'e.g. 18000',
                  helper: 'Home, vehicle, personal loans, credit card EMIs',
                ),
                const SizedBox(height: 12),
                _buildNumberField(
                  controller: _savingsController,
                  label: 'Declared Monthly Savings & SIPs (₹)',
                  hint: 'e.g. 12000',
                  helper: 'Mutual fund SIPs, PPF, RD, NPS, gold contributions',
                ),
                const SizedBox(height: 20),

                // Section 3: Emergency Fund
                _buildSectionTitle('3. Emergency Fund', Icons.health_and_safety_outlined),
                _buildNumberField(
                  controller: _emergencyController,
                  label: 'Current Liquid Emergency Savings (₹)',
                  hint: 'e.g. 150000',
                  helper: 'Savings account balances + liquid mutual funds',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Target Coverage Duration',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [3, 6, 9, 12].map((months) {
                    final isSelected = _emergencyTargetMonths == months;
                    return ChoiceChip(
                      label: Text(
                        '$months Months${months == 6 ? ' (Standard)' : ''}',
                      ),
                      selected: isSelected,
                      selectedColor: gold.withOpacity(0.25),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF8B6B23))
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _emergencyTargetMonths = months);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    if (widget.initialProfile.isConfigured) ...[
                      OutlinedButton.icon(
                        onPressed: _handleConfirmClear,
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        label: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleSave,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(
                          'Save & Calculate',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: gold),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helper,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11), // up to ₹999 Crores
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null; // optional fields
        final numVal = double.tryParse(val.replaceAll(',', '').trim());
        if (numVal == null || numVal < 0) {
          return 'Please enter a valid positive number';
        }
        if (numVal > 1000000000) {
          return 'Value exceeds ₹100 Crore limit';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        prefixText: '₹ ',
        prefixStyle: TextStyle(
          color: gold,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.grey.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
