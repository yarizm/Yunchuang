import 'package:flutter/material.dart';

/// 「本书防剧透范围」里的一个选项。选中的那项用更深的底色、描边和勾
/// 标出来，一眼能看出当前生效的是哪一档。
class SpoilerChoiceTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const SpoilerChoiceTile({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.88)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          selected: selected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: Icon(icon),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
