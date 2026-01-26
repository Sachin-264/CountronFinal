// [NEW FILE] lib/widgets/success_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';

class SuccessScreen extends StatefulWidget {
  final String message;
  const SuccessScreen({super.key, required this.message});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {

  @override
  void initState() {
    super.initState();
    // 2.5 second ke baad automatically pichli screen par wapas jaein
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/success.json', // Aapki Lottie file
              width: 400,
              height: 400,
              repeat: false,
            ),
            const SizedBox(height: 24),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              // Bebas Neue font yahaan theme se apply hoga
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkText
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }
}