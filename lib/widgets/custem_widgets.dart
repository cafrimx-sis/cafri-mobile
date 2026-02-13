import 'package:flutter/material.dart';

class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  const BrandedAppBar({super.key, required this.title, this.actions, this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 0,
      toolbarHeight: 64,
      leading: leading,
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            width: 36,
            child: Image.asset('assets/cafrilogo.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = Text(label, style: const TextStyle(fontWeight: FontWeight.w700));
    return icon == null
        ? ElevatedButton(onPressed: onPressed, child: child)
        : ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: child);
  }
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const SurfaceCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
