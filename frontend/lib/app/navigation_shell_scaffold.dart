import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationShellScaffold extends StatelessWidget {
  const NavigationShellScaffold({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home, label: 'Home'),
    (icon: Icons.medication, label: 'Meds'),
    (icon: Icons.monitor_heart, label: 'Monitor'),
    (icon: Icons.description, label: 'Reports'),
    (icon: Icons.account_circle, label: 'Profile'),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xCCF7F9FB),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1429333D),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final active = index == navigationShell.currentIndex;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFDDEAFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 21,
                          color: active ? const Color(0xFF0B3A70) : const Color(0xFF6D7A76),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active ? const Color(0xFF0B3A70) : const Color(0xFF6D7A76),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
