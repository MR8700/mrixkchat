import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/memory_item.dart';
import '../../../core/repositories/assistant_repository.dart';
import '../../../core/theme/app_theme.dart';

class MemoryManagerDialog extends StatefulWidget {
  const MemoryManagerDialog({super.key});

  @override
  State<MemoryManagerDialog> createState() => _MemoryManagerDialogState();
}

class _MemoryManagerDialogState extends State<MemoryManagerDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _saveNewMemory() {
    final title = _titleController.text.trim();
    final detail = _detailController.text.trim();
    if (title.isEmpty) return;

    final newItem = MemoryItem(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      detail: detail.isNotEmpty ? detail : 'Ajouté manuellement par vous',
      category: 'Personnel',
      createdAt: 'À l\'instant',
    );

    context.read<AssistantRepository>().addMemory(newItem);
    _titleController.clear();
    _detailController.clear();
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final assistantRepo = context.watch<AssistantRepository>();
    final memories = assistantRepo.getAllMemories();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.shield, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'Mémoire & Souvenirs protégés',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Text(
              'Contrôlez les informations conservées exclusivement sur cet appareil.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // Add new memory toggle
            if (!_isAdding)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _isAdding = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un souvenir manuellement'),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWarm,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDFE4ED)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre ou information clé',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _detailController,
                      decoration: const InputDecoration(
                        labelText: 'Détails ou contexte',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isAdding = false),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _saveNewMemory,
                          child: const Text('Enregistrer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            const Text(
              'Informations actuellement retenues :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // List of memories
            Expanded(
              child: ListView.builder(
                itemCount: memories.length,
                itemBuilder: (context, index) {
                  final mem = memories[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDFE4ED)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          mem.isActive ? Icons.verified : Icons.lock_outline,
                          size: 20,
                          color: mem.isActive ? AppTheme.secondary : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mem.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: mem.isActive
                                      ? AppTheme.onSurface
                                      : AppTheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                mem.detail,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            mem.isActive ? Icons.toggle_on : Icons.toggle_off,
                            color: mem.isActive ? AppTheme.secondary : Colors.grey,
                            size: 28,
                          ),
                          onPressed: () {
                            context.read<AssistantRepository>().toggleMemoryActive(mem.id);
                          },
                          tooltip: mem.isActive ? 'Désactiver' : 'Activer',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () {
                            context.read<AssistantRepository>().deleteMemory(mem.id);
                          },
                          tooltip: 'Oublier définitivement',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
