import 'package:flutter/material.dart';

import '../../../services/tutor_history_service.dart';
import '../ai_tutor_screen.dart';

class TutorHistoryScreen extends StatefulWidget {
  const TutorHistoryScreen({super.key});

  @override
  State<TutorHistoryScreen> createState() => _TutorHistoryScreenState();
}

class _TutorHistoryScreenState extends State<TutorHistoryScreen> {
  final TutorHistoryService _historyService = TutorHistoryService();

  List<Map<String, dynamic>> _conversations = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversations = await _historyService.getConversations();

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteConversation(Map<String, dynamic> conversation) async {
    final id = conversation['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete conversation?'),
          content: const Text(
            'This conversation and all its messages will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _historyService.deleteConversation(id);

      if (!mounted) return;

      setState(() {
        _conversations.removeWhere((item) => item['id'] == id);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Conversation deleted.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete conversation: $error')),
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return '';

    final localDate = date.toLocal();
    final now = DateTime.now();

    if (localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day) {
      return 'Today, ${localDate.hour.toString().padLeft(2, '0')}:'
          '${localDate.minute.toString().padLeft(2, '0')}';
    }

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Conversation History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B4D),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadConversations,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3478F6)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 45),
              const SizedBox(height: 12),
              const Text('Unable to load conversations'),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadConversations,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 65,
                color: Color(0xFFB5C5DB),
              ),
              const SizedBox(height: 18),
              const Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF253858),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your AI Tutor conversations will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiTutorScreen()),
                  ).then((_) => _loadConversations());
                },
                icon: const Icon(Icons.add),
                label: const Text('Start a conversation'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final conversation = _conversations[index];

          final id = conversation['id'] as String;
          final title = conversation['title']?.toString() ?? 'New conversation';

          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFEAEFF5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FF),
                child: Icon(Icons.smart_toy_outlined, color: Color(0xFF3478F6)),
              ),
              title: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF253858),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _formatDate(conversation['updated_at']),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              trailing: IconButton(
                tooltip: 'Delete',
                onPressed: () => _deleteConversation(conversation),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiTutorScreen(conversationId: id),
                  ),
                ).then((_) => _loadConversations());
              },
            ),
          );
        },
      ),
    );
  }
}
