// [REPLACE] lib/widgets/orbit_loader.dart

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // Naya import
import '../theme/app_theme.dart';

class OrbitLoader extends StatelessWidget {
  final double size;
  const OrbitLoader({super.key, this.size = 120.0});

  @override
  Widget build(BuildContext context) {
    // SpinKit ka size original container se thoda chhota rakha hai
    // taaki yeh proportional dikhe.
    final spinnerSize = size / 2.2;

    return Center(
      child: SpinKitFadingCube(
        color: AppTheme.primaryBlue,
        size: spinnerSize,
      ),
    );
  }
}