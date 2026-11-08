import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../account/profile_screen.dart';
import '../account/settings_screen.dart';
import '../tutor/ai_tutor_screen.dart';
import '../translation/camera_translation_screen.dart';
import 'learning_plan_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color primaryBlue = Color(0xFF356AE6);
  static const Color darkBlue = Color(0xFF172B4D);
  static const Color backgroundColor = Color(0xFFF5F7FC);

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be available soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openCameraTranslation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraTranslationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Learner';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'LinguaVision AI',
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.account_circle_outlined, color: darkBlue),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined, color: darkBlue),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await authService.logout();
              } catch (error) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to log out.')),
                );
              }
            },
            icon: const Icon(Icons.logout, color: darkBlue),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Text(
                'Hello, $fullName!',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Ready to improve your language skills today?',
                style: TextStyle(fontSize: 14, color: Color(0xFF718096)),
              ),

              const SizedBox(height: 25),

              // Learning plan
              const LearningPlanCard(),

              const SizedBox(height: 28),

              // Progress statistics
              const Text(
                'Your progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.menu_book_rounded,
                      value: '0',
                      label: 'Words learned',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer_outlined,
                      value: '0 min',
                      label: 'Learning time',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department_outlined,
                      value: '0',
                      label: 'Day streak',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Learning features
              const Text(
                'Explore learning tools',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 14),

              _FeatureCard(
                icon: Icons.smart_toy_outlined,
                title: 'AI Tutor',
                description: 'Practice conversations with your AI assistant.',
                color: const Color(0xFFE9EEFF),
                iconColor: primaryBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AiTutorScreen(),
                    ),
                  );
                },
              ),

              _FeatureCard(
                icon: Icons.mic_none_rounded,
                title: 'Speaking Practice',
                description: 'Improve your pronunciation and fluency.',
                color: const Color(0xFFE5F6F0),
                iconColor: const Color(0xFF1C9B70),
                onTap: () => _showComingSoon(context, 'Speaking Practice'),
              ),

              _FeatureCard(
                icon: Icons.camera_alt_outlined,
                title: 'Camera Translation',
                description: 'Translate text directly from your photos.',
                color: const Color(0xFFFFF2E5),
                iconColor: const Color(0xFFE58A2B),
                onTap: () => _openCameraTranslation(context),
              ),

              _FeatureCard(
                icon: Icons.style_outlined,
                title: 'My Vocabulary',
                description: 'Save words and revise them with flashcards.',
                color: const Color(0xFFF2EAFE),
                iconColor: const Color(0xFF8B5CC7),
                onTap: () => _showComingSoon(context, 'My Vocabulary'),
              ),

              _FeatureCard(
                icon: Icons.location_on_outlined,
                title: 'GPS Challenges',
                description: 'Learn through real-life location challenges.',
                color: const Color(0xFFE5F1FC),
                iconColor: const Color(0xFF2583C7),
                onTap: () => _showComingSoon(context, 'GPS Challenges'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: HomeScreen.primaryBlue, size: 25),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: HomeScreen.darkBlue,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE8EDF5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: iconColor, size: 25),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: HomeScreen.darkBlue,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Color(0xFF718096),
        ),
        onTap: onTap,
      ),
    );
  }
}
