import 'package:flutter/material.dart';

import '../../services/learning_service.dart';
import '../learning/learning_setup_screen.dart';

class LearningPlanCard extends StatefulWidget {
  const LearningPlanCard({super.key});

  @override
  State<LearningPlanCard> createState() => _LearningPlanCardState();
}

class _LearningPlanCardState extends State<LearningPlanCard> {
  final LearningService _learningService = LearningService();

  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = _learningService.getLearningProfile();
  }

  Future<void> _openSetup() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LearningSetupScreen()),
    );

    if (result == true && mounted) {
      setState(_loadProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _buildMessageCard(
            title: 'Unable to load your learning plan',
            description: 'Check your connection and try again.',
            buttonText: 'Retry',
            onPressed: () {
              setState(_loadProfile);
            },
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return _buildMessageCard(
            title: 'Your language journey starts here.',
            description: 'Choose your language, level and daily learning goal.',
            buttonText: 'Set up my learning plan',
            onPressed: _openSetup,
          );
        }

        final nativeLanguage = profile['native_language'] as String;
        final targetLanguage = profile['target_language'] as String;
        final level = profile['current_level'] as String;
        final goal = profile['learning_goal'] as String;
        final minutes = profile['daily_minutes'] as num;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF356AE6), Color(0xFF648BEE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 29),
              const SizedBox(height: 16),
              const Text(
                'Your learning plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              _infoRow(
                Icons.translate,
                'Learning',
                '$nativeLanguage → $targetLanguage',
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.signal_cellular_alt, 'Current level', level),
              const SizedBox(height: 12),
              _infoRow(Icons.flag_outlined, 'Main goal', goal),
              const SizedBox(height: 12),
              _infoRow(
                Icons.schedule,
                'Daily target',
                '${minutes.round()} minutes',
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _openSetup,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF356AE6),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Edit my learning plan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageCard({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF356AE6), Color(0xFF648BEE)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 29),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            description,
            style: const TextStyle(color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF356AE6),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
