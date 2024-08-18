import 'package:flutter/material.dart';
import 'package:secrets/components/pinpad.dart';

class UnlockView extends StatefulWidget {
  final int _try;
  final int _dropAfter;
  const UnlockView(this._try, this._dropAfter, {super.key});
  @override
  State<UnlockView> createState() => _UnlockViewState();
}
const _messageEnterPassCode = "Enter Passcode";
const _messageAttemptsLeft = "attempts left";

const int _pinLen = 6;
class _UnlockViewState extends State<UnlockView> {
  String _title = _messageEnterPassCode;
  final PinPadController _controller = PinPadController();
  @override
  Widget build(BuildContext context) {
    if (widget._try > 0) {
      _title = "${widget._dropAfter - widget._try} $_messageAttemptsLeft";
    }
    return Scaffold(
        appBar: AppBar(
          title: Text(_title),
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
        body: PinPad(_pinLen, _controller, _onComplete),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
  void _onComplete(String? pin) {
    Navigator.of(context).pop(pin);
  }
}