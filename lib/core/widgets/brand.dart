import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({
    this.compact = false,
    this.showText = true,
    this.logoSize,
    super.key,
  });

  final bool compact;
  final bool showText;
  final double? logoSize;

  @override
  Widget build(BuildContext context) {
    final size = logoSize ?? (compact ? 42.0 : 62.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/logo_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showText) ...[
          SizedBox(width: compact ? 10 : 14),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: compact ? 14 : 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                    children: const [
                      TextSpan(
                        text: 'SMART ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'GRID',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                Text(
                  'V A L I D A T O R',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: AppColors.green,
                    letterSpacing: compact ? 1.8 : 2.8,
                    fontSize: compact ? 8 : 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
