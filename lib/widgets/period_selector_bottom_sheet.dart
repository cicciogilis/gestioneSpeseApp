import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/selected_period_provider.dart';
import '../../data/repositories/transaction_repository.dart';

const List<String> _monthLabels = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

const List<String> _monthLabelsShort = [
  'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
  'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
];

class PeriodSelectorBottomSheet extends ConsumerStatefulWidget {
  final List<int> availableYears;

  const PeriodSelectorBottomSheet({
    super.key,
    required this.availableYears,
  });

  @override
  ConsumerState<PeriodSelectorBottomSheet> createState() => _PeriodSelectorBottomSheetState();
}

class _PeriodSelectorBottomSheetState extends ConsumerState<PeriodSelectorBottomSheet> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _yearConfirmed = false;
  final Map<int, GlobalKey> _yearKeys = {};
  bool _scrolledToCurrent = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(selectedPeriodProvider);
    _selectedYear = current.year;
    _selectedMonth = current.month;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scrolledToCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentYear();
      });
      _scrolledToCurrent = true;
    }
  }

  void _scrollToCurrentYear() {
    final now = DateTime.now();
    final key = _yearKeys[now.year];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _onYearTapped(int year) {
    final now = DateTime.now();
    setState(() {
      _selectedYear = year;
      _selectedMonth = (year == now.year) ? now.month : 1;
      _yearConfirmed = true;
    });
  }

  void _onMonthTapped(int month) {
    setState(() => _selectedMonth = month);
  }

  void _onConfirm() {
    ref
        .read(selectedPeriodProvider.notifier)
        .setPeriod(_selectedYear, _selectedMonth);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Anno',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.availableYears.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final year = widget.availableYears[i];
                  final isSelected = year == _selectedYear && _yearConfirmed;
                  return ChoiceChip(
                    key: _yearKeys.putIfAbsent(year, () => GlobalKey()),
                    label: Text(year.toString()),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => _onYearTapped(year),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            AnimatedOpacity(
              opacity: _yearConfirmed ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_yearConfirmed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.date_range_outlined,
                            size: 16,
                            color: _yearConfirmed
                                ? theme.colorScheme.primary
                                : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Mese',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _yearConfirmed
                                ? theme.colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                        if (!_yearConfirmed) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(seleziona prima un anno)',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 2.0,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (_, i) {
                        final month = i + 1;
                        final isSelected = _yearConfirmed && month == _selectedMonth;
                        return InkWell(
                          onTap: () => _onMonthTapped(month),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _monthLabelsShort[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _yearConfirmed ? _onConfirm : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _yearConfirmed
                    ? 'Conferma — ${_monthLabels[_selectedMonth - 1]} $_selectedYear'
                    : 'Seleziona un anno per continuare',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openPeriodSelector({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final availableYears = await TransactionRepository().getAvailableYears();

  final now = DateTime.now();
  final pastYears = List.generate(6, (i) => now.year - 1 - i);
  final futureYears = List.generate(6, (i) => now.year + i);
  final allYears = {...availableYears, ...pastYears, ...futureYears}.toList()
    ..sort();

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PeriodSelectorBottomSheet(
      availableYears: allYears,
    ),
  );
}
