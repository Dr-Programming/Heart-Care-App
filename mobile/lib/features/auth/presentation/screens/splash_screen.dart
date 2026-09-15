import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.headerBand,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.favorite, color: AppColors.critical, size: 48),
            SizedBox(height: 12),
            Text(
              'Libu Care',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
