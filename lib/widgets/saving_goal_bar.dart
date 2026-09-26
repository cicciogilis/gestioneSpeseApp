import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/saving_goal_provider.dart';

class SavingGoalBar extends ConsumerWidget {
  const SavingGoalBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingGoalAsync = ref.watch(savingGoalProvider);

    return savingGoalAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(
          'Errore nel calcolo dell\'obiettivo di risparmio',
          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
        ),
      ),
      data: (data) {
        if (!data.hasEntrate) {
          return _buildNoEntrateState();
        }

        if (!data.isConfigured) {
          return _buildNotConfiguredState();
        }

        return _buildProgressBar(data);
      },
    );
  }

  Widget _buildNoEntrateState() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Obiettivo di risparmio',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 20,
              width: double.infinity,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nessuna entrata registrata questo mese',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfiguredState() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Obiettivo di risparmio',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Obiettivo non configurato. Vai in Impostazioni → Budget per impostarlo.',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(SavingGoalData data) {
    final percentuale = (data.percentuale * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Obiettivo di risparmio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '$percentuale%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: data.percentuale > 0.3
                      ? const Color(0xFF4CAF50)
                      : data.percentuale > 0.1
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: data.percentuale,
              minHeight: 20,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'Risparmiato: €${data.risparmiato.toStringAsFixed(2)} / €${data.obiettivoRisparmioMese.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}