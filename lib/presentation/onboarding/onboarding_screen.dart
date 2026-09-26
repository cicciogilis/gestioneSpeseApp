import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/onboarding_balance_choice_dialog.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<({String title, String subtitle, IconData icon})> _pages = [
    (
      title: 'Benvenuto in SpesApp!',
      subtitle: 'Gestisci spese, entrate e risparmi in modo semplice e ordinato',
      icon: Icons.account_balance_wallet,
    ),
    (
      title: 'Niente più inserimenti manuali',
      subtitle: 'Scansiona uno scontrino e lascia che l’AI inserisca automaticamente i dati.',
      icon: Icons.document_scanner,
    ),
    (
      title: 'Il tuo budget, sempre con te',
      subtitle: 'Definisci il tuo tetto di spesa,i tuoi obiettivi di risaparmio, e conserva i dati sul dispositivo.',
      icon: Icons.savings,
    ),
  ];

  void _showBalanceChoiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OnboardingBalanceChoiceDialog(
        onConfirm: (choice, amount) async {
          // onboarding_done is set inside the dialog's onConfirm
          if (mounted) {
            context.go('/');
          }
        },
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showBalanceChoiceDialog();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 120, color: Colors.green),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? Colors.green : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _showBalanceChoiceDialog,
                    child: const Text('Salta'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    child: Text(_currentPage == _pages.length - 1 ? 'Inizia' : 'Avanti'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}