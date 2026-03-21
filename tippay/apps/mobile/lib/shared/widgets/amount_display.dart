import 'package:flutter/material.dart';

class AmountDisplay extends StatelessWidget {
  final int amountPaise;
  final double fontSize;
  final Color? color;

  const AmountDisplay({
    super.key,
    required this.amountPaise,
    this.fontSize = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final rupees = (amountPaise / 100).toStringAsFixed(amountPaise % 100 == 0 ? 0 : 2);
    return Text(
      '\u20B9$rupees',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
