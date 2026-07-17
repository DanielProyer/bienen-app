import 'package:flutter/material.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

class DurchsichtKarte extends StatelessWidget {
  final Durchsicht d;
  final VoidCallback onTap;
  const DurchsichtKarte({super.key, required this.d, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final teile = <String>[
      if (d.staerkeWabengassen != null) '${d.staerkeWabengassen} Gassen',
      if (d.auffaelligkeiten.isNotEmpty) d.auffaelligkeiten.join(', '),
      if ((d.massnahmen ?? '').isNotEmpty) d.massnahmen!,
    ];
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('${d.durchgefuehrtAm.day}.${d.durchgefuehrtAm.month}.${d.durchgefuehrtAm.year}'),
        subtitle: teile.isEmpty ? null : Text(teile.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: d.weiselzustand == null
            ? null
            : Chip(label: Text(d.weiselzustand!), visualDensity: VisualDensity.compact),
      ),
    );
  }
}
