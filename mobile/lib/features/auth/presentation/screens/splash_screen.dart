import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/header_band.dart';

/// Shown only while the session is read from disk. The router redirects away
/// as soon as that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: <Widget>[
          HeaderBand(),
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
