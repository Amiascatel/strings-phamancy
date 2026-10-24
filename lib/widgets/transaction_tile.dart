import 'package:flutter/material.dart';

import '../models/stock_transaction.dart';
import '../utils/format.dart';

class TransactionTile extends StatelessWidget {
  final StockTransaction t;
  final bool showName;
  const TransactionTile(this.t, {super.key, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final (icon, color, qtyText) = switch (t.type) {
      TransactionType.stockIn =>
        (Icons.add_circle, Colors.green, '+${t.quantity}'),
      TransactionType.stockOut =>
        (Icons.remove_circle, Colors.red, '-${t.quantity}'),
      TransactionType.adjust => (Icons.tune, Colors.blueGrey, '=${t.quantity}'),
      TransactionType.sale =>
        (Icons.point_of_sale, Colors.blue, '-${t.quantity}'),
      TransactionType.saleReturn =>
        (Icons.undo, Colors.purple, '+${t.quantity}'),
    };
    final subtitle = [
      if (showName) t.type.label,
      dateTime(t.createdAt),
      if (t.note.isNotEmpty) t.note,
    ].join(' • ');
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(showName ? t.medicineName : t.type.label),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(qtyText,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text('Bal: ${t.balanceAfter}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
