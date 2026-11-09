import 'package:flutter/material.dart';

import '../theme.dart';

class NavItem {
  const NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Bottom bar: the selected tab is a solid rounded pill holding icon + label.
class OrbixNavBar extends StatelessWidget {
  const OrbixNavBar({super.key, required this.items, required this.index, required this.onTap});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Tokens.surface, border: Border(top: BorderSide(color: Tokens.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].label,
                    child: InkWell(
                      key: Key('tab_${items[i].label}'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: i == index ? Tokens.primary : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(items[i].icon, color: i == index ? Colors.white : Tokens.muted),
                          const SizedBox(height: 2),
                          Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: i == index ? FontWeight.w600 : FontWeight.w400, color: i == index ? Colors.white : Tokens.muted)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
