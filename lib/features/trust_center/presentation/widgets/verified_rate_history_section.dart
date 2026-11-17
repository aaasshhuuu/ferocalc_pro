import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/data_trust_models.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../../../../core/utils/date_formatter.dart';

class VerifiedRateHistorySection extends StatefulWidget {
  const VerifiedRateHistorySection({
    Key? key,
    required this.banks,
    this.initialBank,
  }) : super(key: key);

  final List<Bank> banks;
  final Bank? initialBank;

  @override
  State<VerifiedRateHistorySection> createState() => _VerifiedRateHistorySectionState();
}

class _VerifiedRateHistorySectionState extends State<VerifiedRateHistorySection> {
  Bank? _selectedBank;
  String _customerTypeFilter = 'ALL';
  bool? _isCallableFilter = true;

  bool _isLoading = false;
  String? _errorMessage;
  List<VerifiedRateHistoryEntry> _historyEntries = [];
  bool _hasHistoricalChanges = false;
  String? _backendNote;

  @override
  void initState() {
    super.initState();
    if (widget.banks.isNotEmpty) {
      _selectedBank = widget.initialBank ?? widget.banks.first;
      _loadHistory();
    }
  }

  @override
  void didUpdateWidget(covariant VerifiedRateHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBank != null && widget.initialBank?.id != _selectedBank?.id) {
      setState(() {
        _selectedBank = widget.initialBank;
      });
      _loadHistory();
    } else if (_selectedBank == null && widget.banks.isNotEmpty) {
      setState(() {
        _selectedBank = widget.banks.first;
      });
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    if (_selectedBank == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await VerifiedRateService.fetchHistory(
        _selectedBank!.id,
        customerType: _customerTypeFilter == 'ALL' ? null : _customerTypeFilter,
        isCallable: _isCallableFilter,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (res.hasError) {
            _errorMessage = res.errorMessage ?? 'Could not retrieve rate history.';
          } else {
            _historyEntries = res.history;
            _hasHistoricalChanges = res.hasHistoricalChanges;
            _backendNote = res.note;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load rate history: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A96E);
    const cyan = Color(0xFF38BDF8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VERIFIED RATE HISTORY & AUDITED TRANSITIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: gold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Publicly verified rate transitions for active bank partners. Only promoted rate cards and superseded historical slabs are exposed.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Bank Selector
        if (widget.banks.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No active verified banks available.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF132235),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gold.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Bank>(
                value: _selectedBank != null && widget.banks.any((b) => b.id == _selectedBank!.id)
                    ? widget.banks.firstWhere((b) => b.id == _selectedBank!.id)
                    : widget.banks.first,
                dropdownColor: const Color(0xFF132235),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: gold),
                items: widget.banks.map((b) {
                  return DropdownMenuItem<Bank>(
                    value: b,
                    child: Text(
                      b.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (Bank? newBank) {
                  if (newBank != null) {
                    setState(() {
                      _selectedBank = newBank;
                    });
                    _loadHistory();
                  }
                },
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Customer Type & Callable Filters
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip('All Customers', _customerTypeFilter == 'ALL', () {
              setState(() => _customerTypeFilter = 'ALL');
              _loadHistory();
            }),
            _buildFilterChip('Regular', _customerTypeFilter == 'REGULAR', () {
              setState(() => _customerTypeFilter = 'REGULAR');
              _loadHistory();
            }),
            _buildFilterChip('Senior Citizen', _customerTypeFilter == 'SENIOR_CITIZEN', () {
              setState(() => _customerTypeFilter = 'SENIOR_CITIZEN');
              _loadHistory();
            }),
            _buildFilterChip(
              _isCallableFilter == true
                  ? 'Callable'
                  : (_isCallableFilter == false ? 'Non-Callable' : 'All Products'),
              true,
              () {
                setState(() {
                  if (_isCallableFilter == true) {
                    _isCallableFilter = false;
                  } else if (_isCallableFilter == false) {
                    _isCallableFilter = null;
                  } else {
                    _isCallableFilter = true;
                  }
                });
                _loadHistory();
              },
              icon: Icons.filter_alt_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content Area
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: CircularProgressIndicator(color: gold, strokeWidth: 2.5),
            ),
          )
        else if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _loadHistory,
                  child: const Text('Retry', style: TextStyle(color: gold)),
                ),
              ],
            ),
          )
        else if (_historyEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_toggle_off, color: Colors.white54, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'No Historical Rate Changes Recorded',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _backendNote ??
                      'This bank currently has active verified baseline rates without historical revisions in the verified ledger.',
                  style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                ),
              ],
            ),
          )
        else ...[
          // Historical coverage limitation explanation (honest boundary)
          if (!_hasHistoricalChanges)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cyan.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cyan.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: cyan),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Initial Verified Baseline: All displayed slabs represent the current officially verified rate card. Historical rate change tracking began with the Phase 4.3 release.',
                      style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

          // Timeline of historical records
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _historyEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final entry = _historyEntries[idx];
              return _buildHistoryEntryCard(context, entry);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {IconData? icon}) {
    const gold = Color(0xFFC9A96E);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? gold.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? gold : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? gold : Colors.white54),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? gold : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntryCard(BuildContext context, VerifiedRateHistoryEntry entry) {
    const gold = Color(0xFFC9A96E);
    final hasTransition = entry.previousRate != null;
    final diff = entry.rateDifference;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isCurrent
              ? gold.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  entry.tenureDescription,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (entry.isCurrent ? const Color(0xFF10B981) : Colors.grey)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.isCurrent ? 'ACTIVE' : 'SUPERSEDED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: entry.isCurrent ? const Color(0xFF10B981) : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Rate transition display
          Row(
            children: [
              if (hasTransition) ...[
                Text(
                  '${entry.previousRate!.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white38,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
              ],
              Text(
                '${entry.interestRate.toStringAsFixed(2)}% p.a.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
              if (diff != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (diff >= 0 ? const Color(0xFF10B981) : Colors.amber)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: diff >= 0 ? const Color(0xFF10B981) : Colors.amber,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Customer and product type
          Row(
            children: [
              Text(
                '${entry.customerType} • ${entry.isCallable ? "Callable" : "Non-Callable"}',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              if (entry.rateCategory == 'SPECIAL_SCHEME') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.schemeName ?? 'Special Scheme',
                    style: const TextStyle(fontSize: 10, color: Colors.purpleAccent),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Date and provenance info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Effective Date:', style: TextStyle(fontSize: 10.5, color: Colors.white38)),
                    Text(
                      entry.effectiveFrom != null
                          ? DateFormatter.formatStandardDate(entry.effectiveFrom!)
                          : 'Not specified',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                    ),
                  ],
                ),
                if (entry.effectiveUntil != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Superseded On:', style: TextStyle(fontSize: 10.5, color: Colors.white38)),
                      Text(
                        DateFormatter.formatStandardDate(entry.effectiveUntil!),
                        style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
                if (entry.verifiedAt != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Audited & Verified:', style: TextStyle(fontSize: 10.5, color: Colors.white38)),
                      Text(
                        DateFormatter.formatStandardDate(entry.verifiedAt!),
                        style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (entry.sourceUrl != null && entry.sourceUrl!.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(entry.sourceUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, size: 12, color: gold),
                  SizedBox(width: 4),
                  Text(
                    'Official Circular Source',
                    style: TextStyle(
                      fontSize: 11,
                      color: gold,
                      decoration: TextDecoration.underline,
                      decorationColor: gold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 10, color: gold),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
