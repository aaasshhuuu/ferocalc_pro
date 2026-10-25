import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../injection_container.dart' as di;
import '../bloc/calculation_history_bloc.dart';
import '../widgets/calculation_history_card.dart';

class CalculationHistoryScreen extends StatefulWidget {
  const CalculationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CalculationHistoryScreen> createState() =>
      _CalculationHistoryScreenState();
}

class _CalculationHistoryScreenState extends State<CalculationHistoryScreen> {
  late final CalculationHistoryBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = di.sl<CalculationHistoryBloc>()..add(const LoadCalculationHistory());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _confirmClearAll(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'Are you sure you want to remove all saved calculations? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bloc.add(const ClearAllCalculationHistory());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calculation history cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Clear All',
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
      value: _bloc,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Calculation History',
          actions: [
            BlocBuilder<CalculationHistoryBloc, CalculationHistoryState>(
              builder: (context, state) {
                if (state is CalculationHistoryLoaded && state.entries.isNotEmpty) {
                  return IconButton(
                    key: const ValueKey('clear_all_history_button'),
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                    tooltip: 'Clear All',
                    onPressed: () => _confirmClearAll(context),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
            child: BlocConsumer<CalculationHistoryBloc, CalculationHistoryState>(
              listener: (context, state) {
                if (state is CalculationHistoryError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${state.message}')),
                  );
                }
              },
              builder: (context, state) {
                if (state is CalculationHistoryLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFC9A96E)),
                  );
                }

                if (state is CalculationHistoryLoaded) {
                  if (state.entries.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: Responsive.screenPadding(context),
                    itemCount: state.entries.length,
                    itemBuilder: (context, index) {
                      final entry = state.entries[index];
                      return Dismissible(
                        key: ValueKey('history_item_${entry.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white, size: 28),
                        ),
                        onDismissed: (_) {
                          _bloc.add(DeleteCalculationEntry(entry.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${entry.calculatorName} removed'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: CalculationHistoryCard(
                          entry: entry,
                          onTap: () async {
                            await context.push('/history/detail', extra: entry);
                            _bloc.add(const LoadCalculationHistory());
                          },
                        ),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A96E).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off,
              color: Color(0xFFC9A96E),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Calculation History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Completed calculations will automatically appear here for later viewing and export.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              key: const ValueKey('start_calculating_button'),
              text: 'Start Calculating',
              onPressed: () {
                context.go('/calculators');
              },
            ),
          ),
        ],
      ),
    );
  }
}
