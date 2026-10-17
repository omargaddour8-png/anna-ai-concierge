import 'package:flutter/material.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text("Anna is typing..."),
        ],
      ),
    );
  }
}