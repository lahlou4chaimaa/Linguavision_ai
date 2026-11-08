import 'package:flutter/material.dart';

import '../../services/learning_service.dart';

class LearningSetupScreen extends StatefulWidget {
  const LearningSetupScreen({super.key});

  @override
  State<LearningSetupScreen> createState() => _LearningSetupScreenState();
}

class _LearningSetupScreenState extends State<LearningSetupScreen> {
  final LearningService _learningService = LearningService();

  final List<String> _languages = [
    'Arabic',
    'English',
    'French',
    'Spanish',
    'German',
    'Italian',
    'Chinese',
    'Japanese',
    'Portuguese',
  ];

  final List<String> _levels = [
    'A1 - Beginner',
    'A2 - Elementary',
    'B1 - Intermediate',
    'B2 - Upper Intermediate',
    'C1 - Advanced',
    'C2 - Proficient',
  ];

  final List<String> _goals = [
    'Travel',
    'Studies',
    'Work and career',
    'Daily communication',
    'Personal development',
  ];

  String? _nativeLanguage = 'French';
  String? _targetLanguage = 'English';
  String? _currentLevel = 'A1 - Beginner';
  String? _learningGoal = 'Daily communication';

  double _dailyMinutes = 15;
  bool _isLoading = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await _learningService.getLearningProfile();

      if (profile != null && mounted) {
        setState(() {
          _nativeLanguage = profile['native_language'] as String;
          _targetLanguage = profile['target_language'] as String;
          _currentLevel = profile['current_level'] as String;
          _learningGoal = profile['learning_goal'] as String;
          _dailyMinutes = (profile['daily_minutes'] as num).toDouble();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load your learning profile.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nativeLanguage == _targetLanguage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose two different languages.')),
      );
      return;
    }

    if (_nativeLanguage == null ||
        _targetLanguage == null ||
        _currentLevel == null ||
        _learningGoal == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _learningService.saveLearningProfile(
        nativeLanguage: _nativeLanguage!,
        targetLanguage: _targetLanguage!,
        currentLevel: _currentLevel!,
        learningGoal: _learningGoal!,
        dailyMinutes: _dailyMinutes.round(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your learning plan has been saved.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save your plan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF172B4D),
          ),
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        title: const Text('Learning Setup'),
        backgroundColor: const Color(0xFFF5F7FC),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Build your learning plan',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B4D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tell us about your language goals. '
                    'We will use this information to personalize '
                    'your learning experience.',
                    style: TextStyle(color: Color(0xFF718096), height: 1.5),
                  ),
                  const SizedBox(height: 28),

                  _buildDropdown(
                    label: 'My native language',
                    value: _nativeLanguage,
                    items: _languages,
                    icon: Icons.translate,
                    onChanged: (value) {
                      setState(() => _nativeLanguage = value);
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildDropdown(
                    label: 'I want to learn',
                    value: _targetLanguage,
                    items: _languages,
                    icon: Icons.language,
                    onChanged: (value) {
                      setState(() => _targetLanguage = value);
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildDropdown(
                    label: 'My current level',
                    value: _currentLevel,
                    items: _levels,
                    icon: Icons.signal_cellular_alt,
                    onChanged: (value) {
                      setState(() => _currentLevel = value);
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildDropdown(
                    label: 'My main goal',
                    value: _learningGoal,
                    items: _goals,
                    icon: Icons.flag_outlined,
                    onChanged: (value) {
                      setState(() => _learningGoal = value);
                    },
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Daily learning time',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF172B4D),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Time per day',
                        style: TextStyle(color: Color(0xFF718096)),
                      ),
                      Text(
                        '${_dailyMinutes.round()} minutes',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF356AE6),
                        ),
                      ),
                    ],
                  ),

                  Slider(
                    value: _dailyMinutes,
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: const Color(0xFF356AE6),
                    onChanged: (value) {
                      setState(() => _dailyMinutes = value);
                    },
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF356AE6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 23,
                              width: 23,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save my learning plan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
