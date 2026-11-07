import 'package:flutter/material.dart';

/// Four quick links on the Home tab. [onSelected] gets the admin's category
/// name (the value saved on `products/{id}/category`).
class CategoryShortcuts extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const CategoryShortcuts({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Shortcut(Icons.memory, 'Processors', 'Processors', Colors.blue, onSelected),
        _Shortcut(Icons.videogame_asset, 'Graphics', 'Graphics', Colors.orange, onSelected),
        _Shortcut(Icons.storage, 'Storage', 'Storage', Colors.green, onSelected),
        _Shortcut(Icons.bolt, 'Power', 'Power Supply', Colors.amber.shade800, onSelected),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final String category;
  final Color color;
  final ValueChanged<String> onSelected;

  const _Shortcut(this.icon, this.label, this.category, this.color, this.onSelected);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(category),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}