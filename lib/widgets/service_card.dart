import 'package:flutter/material.dart';

class ServiceCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const ServiceCard({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Center(
              child: Text(
                title,
                textAlign:
                    TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}