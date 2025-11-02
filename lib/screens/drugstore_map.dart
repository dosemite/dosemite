import 'package:flutter/material.dart';
import '../utils/translations.dart';
import '../theme/language_controller.dart';

class DrugstoreMapScreen extends StatelessWidget {
  const DrugstoreMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // We build a single scrollable list where the map is the first item and the pharmacies follow.
    final pharmacies = List.generate(8, (i) => 'Pharmacy ${i + 1}');
    return ValueListenableBuilder(
      valueListenable: LanguageController.instance,
      builder: (context, _, __) {
        return Scaffold(
          body: SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140), // bottom padding so FAB doesn't cover items
              itemCount: 1 + pharmacies.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(Translations.nearbyPharmacies, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list))
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 260,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Icon(Icons.map_outlined, size: 72, color: Colors.grey)),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }

                final item = pharmacies[index - 1];
                return Column(
                  children: [
                    ListTile(
                      tileColor: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: const Icon(Icons.local_pharmacy, color: Colors.blue),
                      title: Text(item),
                      subtitle: Text('${Translations.openUntil} 9:00 PM'),
                      trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}