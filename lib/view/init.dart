import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class InitView extends StatefulWidget {
  const InitView({super.key});
  @override
  State<InitView> createState() => _InitViewState();
}
const _messageEnterPassCode = "Enter Passcode";
const _messageReEnterPassCode = "Re-Enter Passcode";
const _messageMismatch = "Passcode mismatch";
const _messageTooShort = "Passcode too short";

const int _pinLen = 6;
class _InitViewState extends State<InitView> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _pinputFocusNode = FocusNode();
  String _message = _messageEnterPassCode;
  String? _pin;
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    _pinputFocusNode.requestFocus();
    return Scaffold(
        body: SizedBox(
            width: size.width,
            height: size.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    "Creating new storage",
                    style: TextStyle(
                      fontSize: size.width * 0.07,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _message,
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w300, fontSize: size.width * 0.05),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  height: size.height * 0.05,
                ),
                Pinput(
                  length: _pinLen,
                  onSubmitted: _onSubmit,
                  onCompleted: _onComplete,
                  autofocus: true,
                  focusNode: _pinputFocusNode,
                  controller: _inputController,
                  obscureText: true,
                  obscuringCharacter: "#",
                ),
              ],
            )));
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
  void _onSubmit(String _) {
    _inputController.clear();
    setState(() {
      _message = _messageTooShort;
    });
  }
  void _onComplete(String pin) {
    _inputController.clear();
    if (pin.length < _pinLen) {
      setState(() {
        _message = _messageTooShort;
      });
      return;
    }
    if (_pin == null) {
      setState(() {
        _pin = pin;
        _message = _messageReEnterPassCode;
      });
      return;
    }
    if (_pin != pin) {
      setState(() {
        _pin = null;
        _message = _messageMismatch;
      });
      return;
    }
    _pinputFocusNode.unfocus();
    Navigator.of(context).pop(_pin);
  }
}