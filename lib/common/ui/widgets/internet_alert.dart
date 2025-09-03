import 'package:flutter/material.dart';

class InternetAlert extends StatelessWidget {
  final bool isConnected;
  const InternetAlert({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            isConnected
                ? Icon(
                  Icons.sentiment_satisfied_rounded,
                  color: Colors.green,
                  size: 50,
                )
                : Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 50,
                ),
            Text(
              isConnected
                  ? "Internet is back."
                  : "No Internet Connection",
            ),
          ],
        ),
      ),
    );
  }
}
