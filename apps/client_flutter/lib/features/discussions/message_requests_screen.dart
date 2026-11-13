import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/message_request.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';

class MessageRequestsScreen extends StatelessWidget {
  const MessageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<MessageRepository>();
    final requests = repository.getPendingMessageRequests();
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes de message')),
      body: requests.isEmpty
          ? const Center(
              child: Text('Aucune demande de message pour le moment.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _RequestCard(request: requests[index]),
            ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final MessageRequest request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await context
          .read<MessageRepository>()
          .acceptMessageRequest(widget.request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${widget.request.senderName} a été ajouté à vos contacts.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’accepter : $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ignore() async {
    setState(() => _busy = true);
    try {
      await context
          .read<MessageRepository>()
          .ignoreMessageRequest(widget.request);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’ignorer : $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                    name: request.senderName,
                    avatarUrl: request.senderAvatar,
                    radius: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.senderName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(request.senderHandle,
                          style: const TextStyle(
                              color: AppTheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.person_add_alt_1_outlined,
                    color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(request.content),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cette personne ne figure pas encore dans vos contacts.',
              style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _ignore,
                    child: const Text('Ignorer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _accept,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.person_add_alt_1),
                    label: const Text('Ajouter et accepter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
