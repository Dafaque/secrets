import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/secret.dart';
import 'package:spoiler_widget/spoiler_widget.dart';

class SecretView extends StatefulWidget {
  final Secret _secret;
  final EncryptionManager _enc;
  const SecretView(this._enc, this._secret, {super.key});

  @override
  State<SecretView> createState() => _SecretViewState();
}

class _SecretViewState extends State<SecretView> {
  String val = "decrypting...";
  bool _secretDecrypted = true;
  @override
  void initState() {
    try {
      val = widget._enc.decryptAES(widget._secret.value!);
    } catch (_) {
      val = "Unable to decrypt this secret";
      _secretDecrypted = false;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget._secret.title ?? "Untitled"),
          centerTitle: true,
        ),
        body: Card(
          child: ListTile(
            title: const Text("Value"),
            subtitle: RepaintBoundary(
              child: SpoilerText(
                config: const TextSpoilerConfig(
                  isEnabled: true,
                  maxParticleSize: 1.5,
                  particleDensity: .4,
                  particleSpeed: 0.3,
                  fadeRadius: 3,
                  enableFadeAnimation: true,
                  enableGestureReveal: true,

                  // selection:
                  //     TextSelection(baseOffset: 0, extentOffset: val.length),
                ),
                text: val,
              ),
            ),
            trailing: _secretDecrypted
                ? IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: val),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Secret copied to clipboard")));
                    },
                  )
                : null,
          ),
        ));
  }
}
