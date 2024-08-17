import 'package:flutter/material.dart';
import 'package:secrets/components/dismissible.dart';
import 'package:secrets/crypto/manager.dart';
import 'package:secrets/db/repository.dart';
import 'package:secrets/db/secret.dart';
import 'package:secrets/view/new_secret.dart';
import 'package:secrets/view/secret.dart';

class SecretsView extends StatefulWidget {
  final DB _db;
  final EncryptionManager _enc;
  const SecretsView(this._db, this._enc, {super.key});

  @override
  State<SecretsView> createState() => _SecretsViewState();
}

class _SecretsViewState extends State<SecretsView> {
  List<Secret>? _secrets;
  int totalSecrets = 0;
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
    totalSecrets = widget._db.countSecrets();
    super.initState();
  }
  void _search(String query) {
    if (query.length < 3) {
      setState(() {
        _secrets = null;
      });
      return;
    }
    setState(() {
      _secrets = widget._db.listSecrets(query);
      totalSecrets = widget._db.countSecrets();
    });
  }
  void _showNewSecretSheet() {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (_) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: NewSecretView(widget._db, widget._enc),
        ),
    ).then((_){
      setState(() {
        String query = _searchController.text;
        if (query.length >= 3) {
          _secrets = widget._db.listSecrets(query);
        }
        totalSecrets = widget._db.countSecrets();
      });
    });
  }
  void _showSecretSheet(Secret s) {
    showModalBottomSheet(
        context: context,
        builder: (_) => SecretView(widget._enc, s),
    );
  }
  void _onTileDismissed(String id) {
    widget._db.deleteSecret(id);
  }
  Widget _content(BuildContext context) {
    if (_secrets == null) {
      return Center(
          child: RichText(text: TextSpan(
              text: "Start typing to find among your",
              children: [
                TextSpan(
                    text: " $totalSecrets ",
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
    return Flexible(child: ListView.builder( //TODO mb remove flexible?
      itemBuilder: _buildListView,
      itemCount: _secrets!.length,
      scrollDirection: Axis.vertical,
    ));

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

