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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(30),
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.maroon : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.maroon.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
              color: isSelected ? Colors.white : AppTheme.slate500,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: 'Inter', // Default font family assumption
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.slate500,
                  letterSpacing: isSelected ? 0.3 : 0,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
