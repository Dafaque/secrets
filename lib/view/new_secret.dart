import 'package:flutter/material.dart';
import 'package:secrets/db/repository.dart';
import 'package:secrets/db/secret.dart';

class NewSecretView extends StatelessWidget {
  final DB _db;
  final _valueTEC = TextEditingController();
  final _titleTEC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  NewSecretView(this._db, {super.key});

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
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText:"Title"),
              controller: _titleTEC,
              validator: _titleValidator,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText:"Value"),
              controller: _valueTEC,
              validator: _valueValidator,
            ),
            OutlinedButton(onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) {
                return;
              }
              _saveSecret();
              Navigator.of(context).pop();
            }, child: const Text("Save")),
            const Text('Swipe down co discard', style: TextStyle(color: Colors.grey),),
            const Icon(Icons.arrow_downward, color: Colors.grey),
          ],
        ),
      )
    );
  }

  void _saveSecret() {
    Secret s = Secret()
        ..title=_titleTEC.text
        ..value=_valueTEC.text
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
