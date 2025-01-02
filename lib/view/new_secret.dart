import 'package:flutter/material.dart';
import 'package:secrets/db/secret.dart';

class NewSecretView extends StatelessWidget {
  final _valueTEC = TextEditingController();
  final _titleTEC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  NewSecretView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Create new secret'),
          centerTitle: true,
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
                      decoration: const InputDecoration(labelText: "Title"),
                      controller: _titleTEC,
                      validator: _titleValidator,
                      autofocus: true,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: "Value"),
                      controller: _valueTEC,
                      validator: _valueValidator,
                    ),
                    TextButton(
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [Text("Save")],
                      ),
                      onPressed: () {
                        if (!(_formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        Navigator.of(context).pop(_buildSecret());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }

  Secret _buildSecret() {
    return Secret()
      ..title = _titleTEC.text
      ..value = _valueTEC.text
      ..createdUTC = DateTime.now()
      ..type = SecretType.text;
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
