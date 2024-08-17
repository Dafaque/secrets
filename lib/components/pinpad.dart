import 'package:flutter/material.dart';
import 'package:pin_keyboard/pin_keyboard.dart';

class PinPad extends StatefulWidget {
  final int _pinLen;
  final Function(String?) _onConfirm;
  const PinPad(this._pinLen, this._onConfirm, {super.key});

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = "";
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _pins(),
            ),
          ),
          PinKeyboard(
            length: widget._pinLen,
            onChange: _onChange,
            enableBiometric: false,
            // controller: widget._controller,
            onConfirm: widget._onConfirm,
            iconBackspace: const Icon(Icons.backspace),
          )
        ],
      ),
    );
  }

  void _onChange(String pin) {
    setState(() {
      _pin = pin;
    });
  }

  List<Icon> _pins() {
    final int pinLen = _pin.length;
    return List<Icon>.generate(
      widget._pinLen,
        (int idx) {
          if (idx+1 > pinLen) {
            return const Icon(Icons.circle_outlined);
          }
          return const Icon(Icons.circle);
        }
    );

  }
 }
