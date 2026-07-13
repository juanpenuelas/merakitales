import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParentalGate {
  static Future<bool> verify(BuildContext context) async {
    final random = Random();
    // Generates two random digits between 2 and 9 for a simple adult-verification multiplication.
    final x = random.nextInt(8) + 2; 
    final y = random.nextInt(8) + 2;
    final correctAnswer = x * y;

    final languageCode = Localizations.localeOf(context).languageCode;
    final isSpanish = languageCode == 'es';

    final title = isSpanish ? 'Solo para adultos' : 'Adults only';
    final question = isSpanish
        ? 'Pregunta para adultos: ¿Cuánto es $x x $y?'
        : 'Adults only: What is $x x $y?';
    final cancelText = isSpanish ? 'Cancelar' : 'Cancel';
    final submitText = isSpanish ? 'Enviar' : 'Submit';
    final placeholder = isSpanish ? 'Tu respuesta' : 'Your answer';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ParentalGateDialog(
          x: x,
          y: y,
          correctAnswer: correctAnswer,
          title: title,
          question: question,
          cancelText: cancelText,
          submitText: submitText,
          placeholder: placeholder,
        );
      },
    );

    return result ?? false;
  }
}

class _ParentalGateDialog extends StatefulWidget {
  final int x;
  final int y;
  final int correctAnswer;
  final String title;
  final String question;
  final String cancelText;
  final String submitText;
  final String placeholder;

  const _ParentalGateDialog({
    required this.x,
    required this.y,
    required this.correctAnswer,
    required this.title,
    required this.question,
    required this.cancelText,
    required this.submitText,
    required this.placeholder,
  });

  @override
  _ParentalGateDialogState createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<_ParentalGateDialog> {
  late final TextEditingController textController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: const Color(0xFF1E1B4B), // Premium dark violet background
      title: Text(
        widget.title,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.question,
            style: GoogleFonts.readexPro(
              color: const Color(0xFFC7D2FE), // Soft glowing light violet
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: textController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: GoogleFonts.readexPro(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: GoogleFonts.readexPro(
                color: const Color(0xFF6366F1).withOpacity(0.6),
              ),
              filled: true,
              fillColor: const Color(0xFF312E81), // Violet input field background
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4338CA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2), // #7C3AED primary glow
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text(
            widget.cancelText,
            style: GoogleFonts.readexPro(
              color: const Color(0xFFC7D2FE),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED), // #7C3AED primary
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            final input = textController.text.trim();
            final userAnswer = int.tryParse(input);
            if (userAnswer == widget.correctAnswer) {
              Navigator.of(context).pop(true);
            } else {
              Navigator.of(context).pop(false);
            }
          },
          child: Text(
            widget.submitText,
            style: GoogleFonts.readexPro(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
