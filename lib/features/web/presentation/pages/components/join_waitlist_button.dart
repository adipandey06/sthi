import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JoinWaitlistButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double? buttonWidth;
  final double? buttonHeight;
  const JoinWaitlistButton({super.key, required this.onPressed, this.buttonWidth, this.buttonHeight});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonWidth ?? 256,
      height: buttonHeight ?? 60,
      child: FloatingActionButton.extended(
        elevation: 8,
        backgroundColor: Colors.white,
        splashColor: Colors.transparent,
        hoverColor: Colors.black26,
        label: Text('Join Waitlist',
        style: GoogleFonts.inter(
          color: Colors.black,
          letterSpacing: 0.0,
          fontSize: 20,
          fontWeight: FontWeight.w600
        )),
        onPressed: onPressed,
      ),
    );
  }
}
