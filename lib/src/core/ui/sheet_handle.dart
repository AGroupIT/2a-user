import 'package:flutter/material.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

