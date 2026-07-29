import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/admin_role_preview_provider.dart';
import '../../../providers/subscription_provider.dart';

/// Brzo prebacivanje uloge za admina — pregled aplikacije bez ograničenja.
class AdminRoleSwitcher extends ConsumerWidget {
  const AdminRoleSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adminPremiumBypassProvider)) {
      return const SizedBox.shrink();
    }

    final selected = ref.watch(adminRolePreviewProvider);

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.orange.shade800, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    compact ? 'Admin pregled uloge' : 'Admin — pregled uloge',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 14 : 16,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 6),
              Text(
                'Prebaci se u bilo koju ulogu i testiraj aplikaciju bez paywalla i limita.',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: adminPreviewRoleOptions.map((option) {
                final role = option.$1;
                final label = option.$2;
                final isSelected = selected == role;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) {
                    ref
                        .read(adminRolePreviewProvider.notifier)
                        .setPreviewRole(role);
                  },
                  selectedColor: Colors.orange.shade700,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.orange.shade900,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.orange.shade700
                        : Colors.orange.shade200,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Aktivno: ${adminPreviewRoleLabel(selected)} · sve opcije otključane',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPreviewBanner extends ConsumerWidget {
  const AdminPreviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adminPremiumBypassProvider)) {
      return const SizedBox.shrink();
    }

    final role = ref.watch(adminRolePreviewProvider);
    return Material(
      color: Colors.orange.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.orange.shade900),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Admin pregled: ${adminPreviewRoleLabel(role)} — bez ograničenja',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
