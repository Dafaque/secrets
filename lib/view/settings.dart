import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:secrets/preferences/manager.dart';

class SettingsView extends StatefulWidget {
  final PreferencesManager _prefs;
  const SettingsView(this._prefs, {super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text("Drop after"),
          subtitle: const Text("Delete secrets after number of incorrect attempts to enter PIN"),
          trailing: NumberPicker(
              minValue: 1,
              maxValue: 999,
              value: widget._prefs.dropAfter,
              onChanged: _onDropAfterChanged,
          ),
        )
      ],
    );
  }
  void _onDropAfterChanged(int dropAfter){

  }
}
