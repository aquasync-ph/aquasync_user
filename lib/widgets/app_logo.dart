import 'package:flutter/material.dart';

class AppAssets {
  static const String logo = 'assets/images/logo.png';
  static const String aquaSyncLogo = 'assets/images/aquasync_logo.png';
}

class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width = 180,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.water_drop_rounded, size: 48, color: Color(0xFF0284C7)),
            SizedBox(height: 6),
            Text(
              'AQUASYNC',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF075985),
                letterSpacing: 2.0,
              ),
            ),
          ],
        );
      },
    );
  }
}
