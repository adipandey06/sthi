import 'package:flutter/material.dart';

class GoogleSigninButton extends StatelessWidget {
  const GoogleSigninButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive dimensions
        final buttonWidth =
            screenWidth > 600
                ? 350.0
                : screenWidth * 0.9; // Max 400px, or 90% of screen width
        final buttonHeight =
            screenWidth > 600
                ? 72.0
                : 48.0; // Smaller height for smaller screens
        final iconSize = buttonHeight * 0.5; // Icon scales with button height
        final fontSize =
            screenWidth > 600 ? 24.0 : 18.0; // Smaller font for smaller screens
        final horizontalPadding =
            screenWidth > 600 ? 32.0 : 16.0; // Adjust padding dynamically

        return SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: FloatingActionButton.large(
            splashColor: Colors.transparent,
            backgroundColor: Colors.white,
            hoverColor: Colors.black12,

            onPressed: () {},
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween, // Align left for better balance
                children: [
                  // Use AssetImage instead of Image.network for local assets
                  Image.asset(
                    'assets/google.png', // Ensure this is correctly added in pubspec.yaml
                    height: iconSize,
                    width: iconSize,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.error,
                        size: iconSize,
                      ); // Fallback for missing image
                    },
                  ),
                  Text(
                    "CONTINUE WITH GOOGLE",
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.black,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis, // Prevent text overflow
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
