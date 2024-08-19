import 'package:flutter/material.dart';
import 'package:secrets/components/dismissible.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/db/secret.dart';
import 'package:secrets/view/new_secret.dart';
import 'package:secrets/view/secret.dart';

class SecretsView extends StatefulWidget {
  final StorageManager _db;
  final EncryptionManager _enc;
  const SecretsView(this._db, this._enc, {super.key});

  @override
  State<SecretsView> createState() => _SecretsViewState();
}

class _SecretsViewState extends State<SecretsView> {
  List<Secret>? _secrets;
  int _totalSecrets = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            // cursorColor: Colors.white,
            decoration: const InputDecoration(
              hintText: 'Search...',
              // hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
            ),
            onChanged: _search,
          ),
          actions: const [
            IconButton(onPressed: null, icon: Icon(Icons.settings))
          ],
        ),
        body: _content(context),
      floatingActionButton: FloatingActionButton(
          onPressed: _showNewSecretSheet,
          child: const Icon(Icons.add),
      ),
    );
  }
  @override
  void initState() {
    widget._db.countSecrets().then((int secretsCount) {
      setState(() {
        _totalSecrets = secretsCount;
      });
    });
    super.initState();
  }
  void _search(String query) {
    if (query.length < 3) {
      setState(() {
        _secrets = null;
      });
      return;
    }
    widget._db.listSecrets(query).then((List<Secret> secrets) {
      setState(() {
        _secrets = secrets;
      });
    });
  }
  void _showNewSecretSheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (_) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: NewSecretView(),
        ),
    ).then((dynamic val){
      Secret? s = val as Secret?;
      if (s == null) {
        return;
      }
      s.value = widget._enc.encryptAES(s.value!);
      widget._db.addSecret(s).then((_){
        _showSuccessSnackBar();
      }).then((_){
        String query = _searchController.text;
        if (query.length >= 3) {
          widget._db.listSecrets(query).then((List<Secret> secrets) {
            setState(() {
              _secrets = secrets;
            });
          });
          return;
        }
        widget._db.countSecrets().then((int countSecrets){
          setState(() {
            _totalSecrets = countSecrets;
          });
        });
      }).catchError((_){
        _showFailSnackBar();
      });
    });
  }
  void _showSuccessSnackBar() {
    return _showSnackBar("Secrets updated");
  }
  void _showFailSnackBar() {
    return _showSnackBar("Secrets update failed");
  }
  void _showSnackBar(String msg){
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Text(msg),
        )
    );
  }
  void _showSecretSheet(Secret s) {
    showModalBottomSheet(
        context: context,
        builder: (_) => SecretView(widget._enc, s),
    );
  }
  void _onTileDismissed(String id) {
    widget._db.deleteSecret(id).then((_){
      _showSuccessSnackBar();
    }).catchError((_){
      _showFailSnackBar();
    });
  }
  Widget _content(BuildContext context) {
    if (_secrets == null) {
      return Center(
          child: RichText(text: TextSpan(
              text: "Start typing to find among your",
              children: [
                TextSpan(
                    text: " $_totalSecrets ",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )
                ),
                const TextSpan(
                  text: "secrets",
                )
              ]
          ),
          ));
    }
    if (_secrets!.isEmpty) {
      return const Center(
        child: Text("No secrets found"),
      );
    }
    return ListView.builder(
      itemBuilder: _buildListView,
      itemCount: _secrets!.length,
      scrollDirection: Axis.vertical,
    );

  }
  Widget _buildListView(BuildContext context, int idx) {
    Secret s = _secrets![idx];
    IconData leadingIcon;
    switch (s.type) {
      case SecretType.text:
        leadingIcon = Icons.text_snippet;
    }

    return SwipeForDeleteComponent(
      s.id.toString(),
      Card(child: ListTile(
        leading: Icon(leadingIcon),
        title: Text(s.title ?? "unset"),
        style: ListTileStyle.list,
        onTap: () {
          _showSecretSheet(s);
        },
      )),
      _onTileDismissed,
    );
  }
}

