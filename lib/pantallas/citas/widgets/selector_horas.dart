import 'package:flutter/material.dart';

class SelectorHoras extends StatelessWidget {
  final List<String> horas;
  final String? pre;
  const SelectorHoras({super.key, required this.horas, this.pre});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: horas.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final h = horas[i];
          return ListTile(
            title: Text(h),
            trailing: pre == h ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(h),
          );
        },
      ),
    );
  }
}
