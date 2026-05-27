import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Reusable filter toggle component for switching between options
/// Used in admin users tab and petugas permintaan tab
class FilterToggle extends StatelessWidget {
  final List<FilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const FilterToggle({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.map((option) {
          return Expanded(
            child: _FilterButton(
              value: option.value,
              label: option.label,
              icon: option.icon,
              isSelected: selectedValue == option.value,
              onTap: () => onChanged(option.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterOption {
  final String value;
  final String label;
  final IconData icon;

  const FilterOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _FilterButton extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.value,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.slate900.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.maroon : AppTheme.slate500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.maroon : AppTheme.slate500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
