import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/preferences/manager.dart';
import 'package:secrets/view/sync.dart';
import 'package:secrets/crypto/manager.dart';

class SettingsView extends StatefulWidget {
  final PreferencesManager _prefs;
  final StorageManager _db;
  final EncryptionManager _enc;
  const SettingsView(this._prefs, this._db, this._enc, {super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int _dropAfter = 1;
  @override
  void initState() {
    _dropAfter = widget._prefs.getDropAfter();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text("Settings"),
        actions: [
          IconButton(
            onPressed: _showDropDbDialog,
            icon: const Icon(Icons.cleaning_services_rounded),
          )
        ],
      ),
      body: ListView(
        children: [
          Card(
            child: ListTile(
              title: const Text("Drop After"),
              subtitle: const Text(
                  "Delete secrets after number of incorrect attempts to enter PIN"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _dropAfter > 0
                        ? () => _onDropAfterChanged(_dropAfter - 1)
                        : null,
                  ),
                  Text(
                    '$_dropAfter',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _dropAfter < 9
                        ? () => _onDropAfterChanged(_dropAfter + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text("Sync"),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SyncView(widget._db, widget._enc, widget._prefs),
                      ),
                    ),
                    child: const Text('Host'),
                  ),
                  ElevatedButton(
                    onPressed: null,
                    child: const Text('Client'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text("App Name"),
              subtitle: Text(widget._prefs.getAppName()),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text("App Version"),
              subtitle: Text(widget._prefs.getAppVersion()),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text("App Build Number"),
              subtitle: Text(widget._prefs.getAppBuildNumber()),
            ),
          )
        ],
      ),
    );
  }

  void _onDropAfterChanged(int dropAfter) {
    setState(() {
      _dropAfter = dropAfter;
    });
    widget._prefs.setDropAfter(_dropAfter);
  }

  void _showDropDbDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Remove all data"),
          content: const Text("Are you sure?"),
          actions: [
            TextButton(
              onPressed: _dropDB,
              child: Text(
                'Delete all',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Cancel'),
            )
          ],
        );
      },
    );
  }

  void _dropDB() {
    Navigator.of(context).pop();
    widget._db.drop().then((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
    });
  }
}
