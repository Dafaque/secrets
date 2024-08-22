import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:secrets/db/manager.dart';
import 'package:secrets/preferences/manager.dart';

class SettingsView extends StatefulWidget {
  final PreferencesManager _prefs;
  final StorageManager _db;
  const SettingsView(this._prefs, this._db, {super.key});
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
        automaticallyImplyLeading: false,
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
              subtitle: const Text("Delete secrets after number of incorrect attempts to enter PIN"),
              trailing: NumberPicker(
                itemCount: 1,
                axis: Axis.horizontal,
                haptics: true,
                minValue: 0,
                maxValue: 9,
                value: _dropAfter,
                onChanged: _onDropAfterChanged,
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text("App Name"),
              subtitle: Text(widget._prefs.getAppName()),
            ),
          ),Card(
            child: ListTile(
              title: const Text("App Version"),
              subtitle: Text(widget._prefs.getAppVersion()),
            ),
          ),Card(
            child: ListTile(
              title: const Text("App Build Number"),
              subtitle: Text(widget._prefs.getAppBuildNumber()),
            ),
          )
        ],
      ),
    );
  }
  void _onDropAfterChanged(int dropAfter){
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
    widget._db.drop().then((_){
      SchedulerBinding.instance.addPostFrameCallback((_){
        Navigator.of(context).pop();
      });
    });
  }
}
