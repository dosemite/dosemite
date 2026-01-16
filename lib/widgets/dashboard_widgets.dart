import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../utils/translations.dart';

class LowSupplyBanner extends StatelessWidget {
  const LowSupplyBanner({super.key, required this.medications});

  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.lowStockWarning,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < medications.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == medications.length - 1 ? 0 : 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: textColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${Translations.lowStockMessage(medications[i].name, medications[i].remainingQuantity ?? 0)} ${Translations.pleaseRestockSoon}',
                      style: TextStyle(color: textColor, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BottomNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const BottomNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: kBottomNavigationBarHeight - -16,
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  Icon(icon, color: color, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 2),
            if (selected)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.medication,
    this.specificTime,
    this.onMarkTaken,
    this.onEdit,
    this.isMarking = false,
  });

  final Medication medication;
  final TimeOfDay? specificTime;
  final VoidCallback? onMarkTaken;
  final VoidCallback? onEdit;
  final bool isMarking;

  Color _badgeColorForPeriod(MedicationPeriod period, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (period) {
      case MedicationPeriod.morning:
        return scheme.primaryContainer.withOpacity(0.6);
      case MedicationPeriod.afternoon:
        return scheme.secondaryContainer.withOpacity(0.6);
      case MedicationPeriod.evening:
        return scheme.tertiaryContainer.withOpacity(0.6);
    }
  }

  IconData _iconForPeriod(MedicationPeriod period) {
    switch (period) {
      case MedicationPeriod.morning:
        return Icons.wb_sunny_outlined;
      case MedicationPeriod.afternoon:
        return Icons.medication_outlined;
      case MedicationPeriod.evening:
        return Icons.nightlight_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = _badgeColorForPeriod(medication.period, theme);
    final badgeIcon = _iconForPeriod(medication.period);

    final formattedTimes = specificTime != null
        ? specificTime!.format(context)
        : medication.times.map((t) => t.format(context)).join(', ');

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(badgeIcon, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${medication.name}, ${medication.dose}${medication.assignee != null ? Translations.forPerson(medication.assignee!) : ""}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          formattedTimes,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (medication.notes != null && medication.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        medication.notes!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isMarking
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: Translations.markMedicationTaken,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        medication.wasTakenToday
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: medication.wasTakenToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onMarkTaken,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
