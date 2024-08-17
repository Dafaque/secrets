import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/secret.dart';

class SecretView extends StatefulWidget {
  final Secret _secret;
  final EncryptionManager _enc;
  const SecretView(
      this._enc,
      this._secret,
      {super.key});

  @override
  State<SecretView> createState() => _SecretViewState();
}

class _SecretViewState extends State<SecretView> {
  String val = "decrypting...";
  @override
  void initState() {
    val = widget._enc.decryptAES(widget._secret.value!);
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget._secret.title ?? "Untitled"),
        leading: const Icon(Icons.text_snippet),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
        body: Card(
          child: ListTile(
            title: const Text("Value"),
            subtitle: Text(val),
            trailing: const Icon(Icons.copy),
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text:val),
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:  Text("Secret copied to clipboard")));
            },
          ),
        )
    );
  }
}
