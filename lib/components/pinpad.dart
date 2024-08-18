import 'package:flutter/material.dart';
import 'package:pin_keyboard/pin_keyboard.dart';

class PinPad extends StatefulWidget {
  final int _pinLen;
  final PinPadController _controller;
  final Function(String?) _onConfirm;
  const PinPad(this._pinLen, this._controller, this._onConfirm, {super.key});
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = "";
  @override
  void initState() {
    widget._controller.state = this;
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              children: _pins(cs),
            ),
          ),
          PinKeyboard(
            length: widget._pinLen,
            onChange: _onChange,
            enableBiometric: false,
            // controller: widget._controller,
            onConfirm: widget._onConfirm,
            iconBackspace: Icon(Icons.backspace, color: cs.secondary,),
            textColor: cs.secondary,
          )
        ],
      ),
    );
  }
  void reset(){
    setState(() {
      _pin = "";
    });
  }
  void _onChange(String pin) {
    setState(() {
      _pin = pin;
    });
  }

  List<Icon> _pins(ColorScheme cs) {
    final int pinLen = _pin.length;
    return List<Icon>.generate(
      widget._pinLen,
        (int idx) {
          if (idx+1 > pinLen) {
            return Icon(Icons.circle_outlined, color: cs.secondaryContainer,);
          }
          return Icon(Icons.circle, color: cs.secondary);
        }
    );

  }
}

class PinPadController {
  _PinPadState? state;
  void reset(){
    state?.reset();
  }
}