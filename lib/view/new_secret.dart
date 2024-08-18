import 'package:flutter/material.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/repository.dart';
import 'package:secrets/db/secret.dart';

class NewSecretView extends StatelessWidget {
  final DB _db;
  final EncryptionManager _enc;
  final _valueTEC = TextEditingController();
  final _titleTEC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  NewSecretView(this._db,this._enc, {super.key});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: const Text('Create new secret'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText:"Title"),
                    controller: _titleTEC,
                    validator: _titleValidator,
                    autofocus: true,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText:"Value"),
                    controller: _valueTEC,
                    validator: _valueValidator,
                  ),
                  TextButton(
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Save")
                      ],
                    ),
                    onPressed: () {
                      if (!(_formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      _saveSecret();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const Padding(
                padding:  EdgeInsets.all(20.0),
                child: Row(
                    children: <Widget>[
                      Expanded(
                          child: Divider()
                      ),
                      Text("OR"),
                      Expanded(
                          child: Divider()
                      ),
                    ]
                ),
              ),
              const Text('Swipe down to discard'),
              const Icon(Icons.arrow_downward),
            ],
          ),
        ),
      )
    );
  }

  void _saveSecret() {
    Secret s = Secret()
        ..title=_titleTEC.text
        ..value=_enc.encryptAES(_valueTEC.text)
        ..createdUTC=DateTime.now()
        ..type=SecretType.text;
    _db.addSecret(s);
  }

  String? _titleValidator(String? val) {
    if (val == null || val.isEmpty || val.length < 3) {
      return "title must contain at least 3 symbols";
    }
    return null;
  }
  String? _valueValidator(String? val) {
    if (val == null || val.isEmpty) {
      return "value cannot be empty";
    }
    return null;
  }
}
