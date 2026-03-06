import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_notifier.dart';

/// 外观设置区块
/// 允许用户选择应用主题模式（浅色、深色、跟随系统）
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsNotifier>(
      builder: (context, notifier, _) {
        final ThemeMode currentMode = notifier.settings.themeMode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '外观',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildThemeModeSelector(context, notifier, currentMode),
          ],
        );
      },
    );
  }

  Widget _buildThemeModeSelector(
    BuildContext context,
    SettingsNotifier notifier,
    ThemeMode currentMode,
  ) {
    final List<({ThemeMode mode, String label, IconData icon})> options = [
      (mode: ThemeMode.system, label: '跟随系统', icon: Icons.brightness_auto),
      (mode: ThemeMode.light, label: '浅色', icon: Icons.light_mode),
      (mode: ThemeMode.dark, label: '深色', icon: Icons.dark_mode),
    ];

    return Wrap(
      spacing: 12,
      children: options.map((option) {
        final bool isSelected = currentMode == option.mode;
        return GestureDetector(
          onTap: () => notifier.updateThemeMode(option.mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  option.icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 4),
                Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
