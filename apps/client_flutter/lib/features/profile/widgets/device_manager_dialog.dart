import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/device.dart';
import '../../../core/repositories/device_repository.dart';
import '../../../core/theme/app_theme.dart';

class DeviceManagerDialog extends StatefulWidget {
  const DeviceManagerDialog({super.key});

  @override
  State<DeviceManagerDialog> createState() => _DeviceManagerDialogState();
}

class _DeviceManagerDialogState extends State<DeviceManagerDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pairingCodeController = TextEditingController();
  String _selectedPlatform = 'Linux';
  bool _isAdding = false;
  final String _currentDeviceCode = 'MRX-SEC-8F2B-914A';

  @override
  void dispose() {
    _nameController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  void _addDevice() async {
    final name = _nameController.text.trim();
    final code = _pairingCodeController.text.trim().toUpperCase();
    if (name.isEmpty) return;

    if (code.isEmpty || !code.startsWith('MRX-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez saisir le code unique chiffré affiché sur l\'appareil (format: MRX-SEC-XXXX-XXXX).',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newDev = Device(
      id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      platform: _selectedPlatform,
      status: 'ACTIVE',
      lastSeenText: 'Connecté à l\'instant',
      pairingCode: code,
      iconType: _selectedPlatform == 'Android'
          ? 'phone'
          : (_selectedPlatform == 'iPadOS' ? 'tablet' : 'laptop'),
    );

    final success = await context.read<DeviceRepository>().authorizeDevice(newDev);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quota strict de 3 appareils atteint. Révoquez d\'abord un appareil existant.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      _nameController.clear();
      _pairingCodeController.clear();
      setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devRepo = context.watch<DeviceRepository>();
    final activeDevices = devRepo.getActiveDevices();
    final allDevices = devRepo.getAllDevices();
    final activeCount = activeDevices.length;

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
                      'Appareils de Confiance',
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
            Row(
              children: [
                Text(
                  'Quota strict : $activeCount / 3 autorisés',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: activeCount >= 3 ? Colors.amber.shade800 : AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '• Configuration par code chiffré unique',
                  style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Encrypted pairing code of this current device
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, size: 18, color: Color(0xFF0043B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Code de couplage chiffré unique de cet appareil :',
                          style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A)),
                        ),
                        Text(
                          _currentDeviceCode,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0043B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code chiffré copié dans le presse-papier.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF0043B8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Form to add device if slot available
            if (_isAdding) ...[
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'appareil (ex: PC Salon)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pairingCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Code chiffré unique (ex: MRX-SEC-72A1-94F0)',
                        hintText: 'MRX-SEC-XXXX-XXXX',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          tooltip: 'Générer un code sécurisé',
                          onPressed: () {
                            _pairingCodeController.text =
                                'MRX-SEC-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).substring(4, 8).toUpperCase()}-${DateTime.now().microsecondsSinceEpoch.toRadixString(16).substring(4, 8).toUpperCase()}';
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPlatform,
                      decoration: const InputDecoration(
                        labelText: 'Plateforme',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Linux', child: Text('Poste Linux')),
                        DropdownMenuItem(value: 'macOS', child: Text('MacBook')),
                        DropdownMenuItem(value: 'Windows', child: Text('PC Windows')),
                        DropdownMenuItem(value: 'Android', child: Text('Smartphone Android')),
                        DropdownMenuItem(value: 'iPadOS', child: Text('iPad')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPlatform = val);
                      },
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
                          onPressed: _addDevice,
                          child: const Text('Autoriser l\'appareil'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (activeCount < 3) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _isAdding = true),
                icon: const Icon(Icons.add_to_queue, size: 18),
                label: const Text('Autoriser un nouvel appareil'),
              ),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: ListView.builder(
                itemCount: allDevices.length,
                itemBuilder: (context, index) {
                  final dev = allDevices[index];
                  final isRevoked = dev.status == 'REVOKED';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRevoked ? Colors.grey.shade100 : AppTheme.surfaceWarm,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRevoked ? Colors.grey.shade300 : const Color(0xFFDFE4ED),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          dev.iconType == 'laptop'
                              ? Icons.laptop_mac
                              : (dev.iconType == 'tablet'
                                  ? Icons.tablet_mac
                                  : Icons.phone_android),
                          size: 24,
                          color: isRevoked ? Colors.grey : AppTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  decoration: isRevoked ? TextDecoration.lineThrough : null,
                                  color: isRevoked ? Colors.grey : AppTheme.onSurface,
                                ),
                              ),
                              Text(
                                dev.lastSeenText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isRevoked ? Colors.grey : AppTheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Code chiffré : ${dev.pairingCode}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: isRevoked ? Colors.grey : const Color(0xFF0043B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!dev.isCurrentDevice && !isRevoked)
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () {
                              context.read<DeviceRepository>().revokeDevice(dev.id);
                            },
                            child: const Text('Révoquer'),
                          )
                        else if (dev.isCurrentDevice)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Actif',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          )
                        else if (isRevoked)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                            onPressed: () {
                              context.read<DeviceRepository>().deleteDevice(dev.id);
                            },
                            tooltip: 'Supprimer',
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
