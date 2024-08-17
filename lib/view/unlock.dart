import 'package:flutter/material.dart';
import 'package:secrets/components/pinpad.dart';

class UnlockView extends StatefulWidget {
  final int _try;
  const UnlockView(this._try, {super.key});
  @override
  State<UnlockView> createState() => _UnlockViewState();
}
const _messageEnterPassCode = "Enter Passcode";
const _messageEnterPassCodeAgain = "Enter Passcode again";
const _messageTooShort = "Passcode too short";

const int _pinLen = 6;
class _UnlockViewState extends State<UnlockView> {
  String _message = _messageEnterPassCode;

  @override
  Widget build(BuildContext context) {
    if (_message != _messageTooShort && widget._try > 0) {
      _message = _messageEnterPassCodeAgain;
    }
    return Scaffold(
        appBar: AppBar(
          title: Text(_message),
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
        body: PinPad(_pinLen, _onComplete),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
  void _onComplete(String? pin) {
    if (pin == null || pin.length < _pinLen) {
      setState(() {
        _message = _messageTooShort;
      });
      return;
    }
    Navigator.of(context).pop(pin);
  }
}