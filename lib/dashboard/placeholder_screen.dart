import 'package:flutter/material.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        backgroundColor: kBackgroundDark,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: kTextLight)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.engineering, size: 64, color: kPrimaryColor),
              const SizedBox(height: 24),
              Text(
                'Màn hình "$title" đang trong quá trình port code từ WMS-01.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: kTextLight,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Vui lòng quay lại sau.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: kTextGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
