import 'dart:math';

import 'package:flutter/material.dart';
import 'package:secrets/components/pinpad.dart';

class InitView extends StatefulWidget {
  const InitView({super.key});
  @override
  State<InitView> createState() => _InitViewState();
}

const _messageEnterPin = "Create PIN";
const _messageVerifyPin = "Verify PIN";
const _messagePinMissmatch = "PIN does not match";

const int _pinLen = 6;
class _InitViewState extends State<InitView> {
  String? _pin;
  String _message = _messageEnterPin;
  final PinPadController _controller = PinPadController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(_message),
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
        body: PinPad(_pinLen, _controller,_onConfirm)
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
  void _onConfirm(String? pin) {
    if (_pin == null) {
      _controller.reset();
      setState(() {
        _pin = pin;
        _message = _messageVerifyPin;
      });
      return;
    }
    if (_pin != pin) {
      _controller.reset();
      setState(() {
        _pin = null;
        _message = _messagePinMissmatch;
      });
      return;
    }
    Navigator.of(context).pop(_pin);
  }
}