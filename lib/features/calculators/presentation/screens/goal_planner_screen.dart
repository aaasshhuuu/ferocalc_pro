import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/calculator_purpose_card.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/input_slider_field.dart';
import '../../../../core/widgets/result_display_card.dart';
import '../../../../injection_container.dart' as di;
import '../../../goals/domain/models/financial_goal.dart';
import '../../../goals/domain/models/goal_projection.dart';
import '../../../goals/presentation/bloc/goal_bloc.dart';
import '../../../history/data/models/calculation_history_entry.dart';
import '../../../history/presentation/helper/calculation_history_saver.dart';

class GoalPlannerScreen extends StatefulWidget {
  const GoalPlannerScreen({
    Key? key,
    this.initialGoal,
    this.initialEntry,
    this.initialTabIndex = 0,
  }) : super(key: key);

  final FinancialGoal? initialGoal;
  final CalculationHistoryEntry? initialEntry;
  final int initialTabIndex;

  @override
  State<GoalPlannerScreen> createState() => _GoalPlannerScreenState();
}

class _GoalPlannerScreenState extends State<GoalPlannerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final GoalBloc _goalBloc;

  // Editing state for goals
  String? _editingGoalId;
  GoalCategory _selectedCategory = GoalCategory.homePurchase;
  final TextEditingController _goalNameCtrl =
      TextEditingController(text: 'Home Purchase');

  double _targetAmount = 5000000;
  double _currentSavings = 500000;
  double _years = 5;
  bool _isInflationEnabled = true;
  double _inflationRate = 6.0;
  double _expectedReturn = 12.0;

  // Scenario analysis simulation state
  double _scenarioMonthlySavings = 45000;

  late GoalProjection _projection;
  late GoalScenarioResult _scenarioResult;

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _goalBloc = di.sl<GoalBloc>()..add(const LoadGoals());

    // Restore from initialGoal or initialEntry if provided
    if (widget.initialGoal != null) {
      _loadGoalData(widget.initialGoal!);
      _tabController.index = 1;
    } else if (widget.initialEntry != null) {
      _loadEntryData(widget.initialEntry!);
      _tabController.index = 1;
    } else {
      _calculate();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _goalNameCtrl.dispose();
    _goalBloc.close();
    super.dispose();
  }

  void _loadGoalData(FinancialGoal goal) {
    _editingGoalId = goal.id;
    _selectedCategory = goal.category;
    _goalNameCtrl.text = goal.name;
    _targetAmount = goal.targetAmount;
    _currentSavings = goal.currentSavings;
    _years = (goal.targetMonths / 12.0).clamp(1.0, 40.0);
    _isInflationEnabled = goal.isInflationEnabled;
    _inflationRate = goal.annualInflationRate;
    _expectedReturn = goal.expectedAnnualReturn;
    _calculate();
  }

  void _loadEntryData(CalculationHistoryEntry entry) {
    _editingGoalId = null;
    if (entry.customName != null && entry.customName!.isNotEmpty) {
      _goalNameCtrl.text = entry.customName!;
    } else if (entry.inputs.containsKey('Goal Name')) {
      _goalNameCtrl.text = entry.inputs['Goal Name']!;
    }

    final target = entry.getNumericInput('targetAmount') ??
        entry.getNumericInput('Current Target Cost') ??
        entry.getNumericInput('Target Amount');
    if (target != null && target > 0) _targetAmount = target;

    final savings = entry.getNumericInput('currentSavings') ??
        entry.getNumericInput('Current Savings');
    if (savings != null && savings >= 0) _currentSavings = savings;

    final yrs = entry.getNumericInput('years') ??
        entry.getNumericInput('Time Horizon');
    if (yrs != null && yrs > 0) _years = yrs;

    final inf = entry.getNumericInput('inflationRate') ??
        entry.getNumericInput('Expected Inflation');
    if (inf != null && inf >= 0) _inflationRate = inf;

    final ret = entry.getNumericInput('expectedReturn') ??
        entry.getNumericInput('Expected Return');
    if (ret != null && ret >= 0) _expectedReturn = ret;

    _calculate();
  }

  void _calculate() {
    final months = (_years * 12).round().clamp(1, 480);
    _projection = GoalProjection.calculate(
      targetAmount: _targetAmount,
      currentSavings: _currentSavings,
      targetMonths: months,
      isInflationEnabled: _isInflationEnabled,
      inflationRate: _inflationRate,
      expectedReturn: _expectedReturn,
    );

    // Default scenario monthly savings to required contribution if uninitialized or previously matched
    if (_scenarioMonthlySavings <= 0 ||
        (_scenarioMonthlySavings - _projection.monthlyContribution).abs() < 100) {
      _scenarioMonthlySavings = _projection.monthlyContribution.roundToDouble();
    }

    _scenarioResult = GoalProjection.simulateScenario(
      targetAmount: _targetAmount,
      currentSavings: _currentSavings,
      months: months,
      isInflationEnabled: _isInflationEnabled,
      inflationRate: _inflationRate,
      expectedReturn: _expectedReturn,
      actualMonthlyContribution: _scenarioMonthlySavings,
    );
  }

  void _onCategoryChanged(GoalCategory cat) {
    setState(() {
      _selectedCategory = cat;
      if (_goalNameCtrl.text.isEmpty ||
          GoalCategory.values.any((GoalCategory c) => c.label == _goalNameCtrl.text)) {
        _goalNameCtrl.text = cat.label;
      }
    });
  }

  void _saveGoalToDashboard() {
    final now = DateTime.now();
    final months = (_years * 12).round().clamp(1, 480);
    final targetDate = now.add(Duration(days: (months * 30.44).round()));

    final goal = FinancialGoal(
      id: _editingGoalId ?? '${now.millisecondsSinceEpoch}_goal',
      name: _goalNameCtrl.text.trim().isNotEmpty
          ? _goalNameCtrl.text.trim()
          : _selectedCategory.label,
      category: _selectedCategory,
      targetAmount: _targetAmount,
      currentSavings: _currentSavings,
      targetMonths: months,
      targetDate: targetDate,
      isInflationEnabled: _isInflationEnabled,
      annualInflationRate: _inflationRate,
      expectedAnnualReturn: _expectedReturn,
      monthlyContribution: _projection.monthlyContribution,
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    _goalBloc.add(AddGoal(goal));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editingGoalId != null
              ? 'Goal "${goal.name}" updated!'
              : 'Goal "${goal.name}" added to Dashboard!',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    // Switch to Dashboard tab to display the updated goal
    _tabController.animateTo(0);
  }

  void _calculateAndSaveHistory() {
    _calculate();
    setState(() {});

    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'goal',
      calculatorName: 'Goal Planner',
      customName: _goalNameCtrl.text.trim().isNotEmpty
          ? _goalNameCtrl.text.trim()
          : _selectedCategory.label,
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Monthly Required',
      primaryResultValue: _currencyFormat.format(_projection.monthlyContribution),
      category: 'Planning',
      rawInputs: {
        'targetAmount': _targetAmount,
        'currentSavings': _currentSavings,
        'years': _years,
        'inflationRate': _inflationRate,
        'expectedReturn': _expectedReturn,
        'category': _selectedCategory.name,
      },
    );
  }

  Map<String, String> _getInputs() => {
        'Goal Name': _goalNameCtrl.text.trim(),
        'Category': _selectedCategory.label,
        'Current Target Cost': _currencyFormat.format(_targetAmount),
        'Current Savings Allocated': _currencyFormat.format(_currentSavings),
        'Time Horizon': '${_years.toStringAsFixed(1)} Years',
        'Inflation Rate': _isInflationEnabled
            ? '${_inflationRate.toStringAsFixed(1)}%'
            : 'Disabled',
        'Expected Return': '${_expectedReturn.toStringAsFixed(1)}%',
      };

  Map<String, String> _getResults() => {
        'Monthly Contribution Required':
            _currencyFormat.format(_projection.monthlyContribution),
        'Inflation-Adjusted Target':
            _currencyFormat.format(_projection.inflationAdjustedTarget),
        'Future Value of Current Savings':
            _currencyFormat.format(_projection.futureSavingsValue),
        'Remaining Target Gap':
            _currencyFormat.format(_projection.remainingGap),
        'Total Projected Contributions':
            _currencyFormat.format(_projection.totalContributions),
        'Projected Investment Growth':
            _currencyFormat.format(_projection.projectedGrowth),
      };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Goal Planner: ${_goalNameCtrl.text}',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Goal Planner: ${_goalNameCtrl.text}',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _showUpdateSavingsDialog(FinancialGoal goal) {
    final ctrl = TextEditingController(text: goal.currentSavings.toStringAsFixed(0));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Savings: ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target: ${_currencyFormat.format(goal.targetAmount)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Current Saved Amount (₹)',
                prefixText: '₹ ',
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newSavings = double.tryParse(ctrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
              if (newSavings != null && newSavings >= 0) {
                _goalBloc.add(UpdateGoalSavingsEvent(goal.id, newSavings));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Updated savings to ${_currencyFormat.format(newSavings)}',
                    ),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              'Update',
              style: TextStyle(color: Color(0xFFC9A96E), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGoal(FinancialGoal goal) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "${goal.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _goalBloc.add(DeleteGoalEvent(goal.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Goal "${goal.name}" deleted')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _goalBloc,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Financial Goal Planner',
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'Export PDF',
              onPressed: () => _exportPdf(context),
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              tooltip: 'Share',
              onPressed: () => _shareResult(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
            child: Column(
              children: [
                Container(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFC9A96E),
                    indicatorWeight: 3,
                    labelColor: const Color(0xFFC9A96E),
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.dashboard_outlined),
                        text: 'Goal Dashboard',
                      ),
                      Tab(
                        icon: Icon(Icons.calculate_outlined),
                        text: 'Planner & Scenarios',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDashboardTab(context),
                      _buildPlannerTab(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: GOAL DASHBOARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDashboardTab(BuildContext context) {
    return BlocBuilder<GoalBloc, GoalState>(
      builder: (context, state) {
        if (state is GoalLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFC9A96E)),
          );
        }

        if (state is GoalLoaded) {
          if (state.goals.isEmpty) {
            return _buildEmptyDashboardState(context);
          }

          return ListView(
            padding: Responsive.screenPadding(context),
            physics: const BouncingScrollPhysics(),
            children: [
              // Combined Summary Card
              _buildCombinedMetricsCard(state),
              const SizedBox(height: 20),

              // Goals List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACTIVE GOALS (${state.activeGoals.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFFC9A96E),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18, color: Color(0xFFC9A96E)),
                    label: const Text(
                      'New Goal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC9A96E),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _editingGoalId = null;
                        _goalNameCtrl.text = 'New Goal';
                      });
                      _tabController.animateTo(1);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Individual Goal Cards
              ...state.goals.map((goal) => _buildGoalCard(goal)),
              const SizedBox(height: 32),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCombinedMetricsCard(GoalLoaded state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2340), Color(0xFF151828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC9A96E).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL SAVINGS PROGRESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFFC9A96E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A96E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.overallProgressPercent.toStringAsFixed(1)}% Saved',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC9A96E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.overallProgressPercent / 100.0,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC9A96E)),
            ),
          ),
          const SizedBox(height: 16),

          // Stat Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Target Total',
                  _currencyFormat.format(state.totalTargetAmount),
                  Icons.flag,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Current Saved',
                  _currencyFormat.format(state.totalSavedAmount),
                  Icons.savings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Monthly Needed',
                  '${_currencyFormat.format(state.totalMonthlyRequired)}/mo',
                  Icons.trending_up,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Status Count',
                  '${state.completedGoals.length} Done • ${state.atRiskGoals.length} At Risk',
                  Icons.info_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFC9A96E)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(FinancialGoal goal) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Category icon, Name, Status Pill, Popup menu
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: goal.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    goal.category.icon,
                    color: goal.category.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            goal.category.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${goal.remainingTimeText}',
                            style: TextStyle(
                              fontSize: 11,
                              color: goal.isAtRisk
                                  ? Colors.redAccent
                                  : const Color(0xFF00E5FF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: goal.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: goal.status.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    goal.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: goal.status.color,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  tooltip: 'Goal Actions',
                  onSelected: (action) {
                    switch (action) {
                      case 'update_savings':
                        _showUpdateSavingsDialog(goal);
                        break;
                      case 'edit_planner':
                        _loadGoalData(goal);
                        _tabController.animateTo(1);
                        break;
                      case 'toggle_pause':
                        final newStatus = goal.status == GoalStatus.paused
                            ? GoalStatus.active
                            : GoalStatus.paused;
                        _goalBloc.add(ToggleGoalStatusEvent(goal.id, newStatus));
                        break;
                      case 'toggle_complete':
                        final newStatus = goal.isCompleted
                            ? GoalStatus.active
                            : GoalStatus.completed;
                        _goalBloc.add(ToggleGoalStatusEvent(goal.id, newStatus));
                        break;
                      case 'delete':
                        _confirmDeleteGoal(goal);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'update_savings',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 10),
                          Text('Update Savings'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit_planner',
                      child: Row(
                        children: [
                          Icon(Icons.tune, size: 18, color: Color(0xFFC9A96E)),
                          SizedBox(width: 10),
                          Text('Scenario & Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_pause',
                      child: Row(
                        children: [
                          Icon(
                            goal.status == GoalStatus.paused
                                ? Icons.play_arrow
                                : Icons.pause,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 10),
                          Text(goal.status == GoalStatus.paused ? 'Resume Goal' : 'Pause Goal'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_complete',
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 10),
                          Text(goal.isCompleted ? 'Mark Active' : 'Mark Completed'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Delete Goal', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar & Percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_currencyFormat.format(goal.currentSavings)} of ${_currencyFormat.format(goal.targetAmount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${goal.progressPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC9A96E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 8,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isCompleted
                      ? const Color(0xFF00E5FF)
                      : (goal.isAtRisk ? Colors.redAccent : const Color(0xFFC9A96E)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Metrics: Required monthly & Target Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Target: ${goal.formattedTargetDate}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward, size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      '${_currencyFormat.format(goal.monthlyContribution)}/mo needed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDashboardState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A96E).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: Color(0xFFC9A96E),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Financial Goals Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Plan multiple financial targets—home down payments, child education, emergency funds, or retirement—with inflation protection and automated monthly contribution tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              key: const ValueKey('create_first_goal_button'),
              text: 'Create Your First Goal',
              onPressed: () {
                _tabController.animateTo(1);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: PLANNER & SCENARIO ANALYSIS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPlannerTab(BuildContext context) {
    return SingleChildScrollView(
      padding: Responsive.screenPadding(context),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category selector chips
          const Text(
            'GOAL CATEGORY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFFC9A96E),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: GoalCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.black : cat.color,
                    ),
                    label: Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFC9A96E),
                    backgroundColor: Theme.of(context).cardColor,
                    onSelected: (_) => _onCategoryChanged(cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Goal Form Card
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Goal Name',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _goalNameCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                InputSliderField(
                  label: 'Target Cost of Goal',
                  value: _targetAmount,
                  min: 10000,
                  max: 50000000,
                  prefix: '₹',
                  onChanged: (val) {
                    setState(() {
                      _targetAmount = val;
                      _calculate();
                    });
                  },
                ),
                const SizedBox(height: 16),
                InputSliderField(
                  label: 'Current Savings Allocated',
                  value: _currentSavings,
                  min: 0,
                  max: 20000000,
                  prefix: '₹',
                  onChanged: (val) {
                    setState(() {
                      _currentSavings = val;
                      _calculate();
                    });
                  },
                ),
                const SizedBox(height: 16),
                InputSliderField(
                  label: 'Years to Achieve',
                  value: _years,
                  min: 1,
                  max: 40,
                  suffix: ' Yrs',
                  onChanged: (val) {
                    setState(() {
                      _years = val;
                      _calculate();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Adjust for Inflation',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: _isInflationEnabled,
                      activeThumbColor: const Color(0xFFC9A96E),
                      onChanged: (val) {
                        setState(() {
                          _isInflationEnabled = val;
                          _calculate();
                        });
                      },
                    ),
                  ],
                ),
                if (_isInflationEnabled) ...[
                  const SizedBox(height: 8),
                  InputSliderField(
                    label: 'Expected Inflation Rate',
                    value: _inflationRate,
                    min: 1,
                    max: 15,
                    suffix: '%',
                    onChanged: (val) {
                      setState(() {
                        _inflationRate = val;
                        _calculate();
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                InputSliderField(
                  label: 'Expected Annual Return',
                  value: _expectedReturn,
                  min: 0,
                  max: 30,
                  suffix: '%',
                  onChanged: (val) {
                    setState(() {
                      _expectedReturn = val;
                      _calculate();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Calculate / Save Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientButton(
                key: const ValueKey('calculate_button'),
                text: 'Calculate & Save History',
                onPressed: _calculateAndSaveHistory,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                key: const ValueKey('save_to_dashboard_button'),
                icon: const Icon(Icons.bookmark_add, size: 18),
                label: Text(_editingGoalId != null ? 'Update Goal in Dashboard' : 'Save Goal to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveGoalToDashboard,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Projections Display Card
          ResultDisplayCard(
            mainLabel: 'Monthly Contribution Required',
            mainValue: _currencyFormat.format(_projection.monthlyContribution),
            subResults: [
              SubResult(
                label: 'Future Inflation-Adjusted Goal',
                value: _currencyFormat.format(_projection.inflationAdjustedTarget),
              ),
              SubResult(
                label: 'Future Value of Current Savings',
                value: _currencyFormat.format(_projection.futureSavingsValue),
              ),
              SubResult(
                label: 'Remaining Target Gap',
                value: _currencyFormat.format(_projection.remainingGap),
              ),
              SubResult(
                label: 'Total Expected Contributions',
                value: _currencyFormat.format(_projection.totalContributions),
              ),
              SubResult(
                label: 'Projected Investment Growth',
                value: _currencyFormat.format(_projection.projectedGrowth),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════
          // SCENARIO ANALYSIS SECTION
          // ═══════════════════════════════════════════════════════════════
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFC9A96E).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: Color(0xFFC9A96E)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SCENARIO ANALYSIS: TEST WHAT-IF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFFC9A96E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adjust your monthly savings to see if you achieve your target or face a shortfall at your target horizon.',
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),

                InputSliderField(
                  label: 'Simulated Monthly Savings',
                  value: _scenarioMonthlySavings,
                  min: 0,
                  max: 200000,
                  prefix: '₹',
                  onChanged: (val) {
                    setState(() {
                      _scenarioMonthlySavings = val;
                      _calculate();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Scenario outcome banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _scenarioResult.isAchieved
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _scenarioResult.isAchieved
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _scenarioResult.isAchieved
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: _scenarioResult.isAchieved
                            ? const Color(0xFF10B981)
                            : Colors.redAccent,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _scenarioResult.isAchieved
                                  ? 'Target Achieved! Surplus: ${_currencyFormat.format(_scenarioResult.surplus)}'
                                  : 'Shortfall: ${_currencyFormat.format(_scenarioResult.shortfall)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _scenarioResult.isAchieved
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Accumulated ${_currencyFormat.format(_scenarioResult.totalAccumulated)} vs target ${_currencyFormat.format(_scenarioResult.targetCost)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Assumption: Monthly contributions at end of month with effective compounding. Current savings grow at selected return. Investment return and inflation figures are planning assumptions, not guarantees or financial advice.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Calculator Purpose Card (preserves calculator purpose tests)
          const CalculatorPurposeCard(calculatorId: 'goal'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
