import 'package:flutter/material.dart';

class SwipeForDeleteComponent extends StatelessWidget {
  final String _key;
  final Widget _child;
  final void Function(String) _callback;
  const SwipeForDeleteComponent(
      this._key,
      this._child,
      this._callback,
      {super.key}
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: Key(_key),
      background: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.error,
        ),
        // color: Colors.redAccent,

        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Icon(
                Icons.delete,
                color: colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
      direction: DismissDirection.endToStart,
      child: _child,
      onDismissed: (_) {
        _callback(_key);
      },
    );
  }
}
