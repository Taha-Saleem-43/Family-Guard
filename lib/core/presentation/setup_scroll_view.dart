import 'package:flutter/material.dart';

/// Keeps setup instructions and actions reachable on small screens and with a keyboard.
class SetupScrollView extends StatelessWidget {
  SetupScrollView({Key? key, required this.child})
    : super(key: key ?? child.key);
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: child,
      ),
    ),
  );
}
