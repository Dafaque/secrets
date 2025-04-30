import 'dart:convert';

import 'package:isar/isar.dart';

part 'secret.g.dart';

@collection
class Secret {
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  String? title;
  String? value;
  @enumerated
  SecretType type = SecretType.text;
  DateTime? createdUTC;

  Secret();

  @override
  String toString() {
    return jsonEncode({
      'id': id,
      'title': title,
      'value': value,
      'type': type.toString(),
    });
  }

  factory Secret.fromJson(String json) {
    var map = jsonDecode(json);
    return Secret()
      ..id = map['id']
      ..title = map['title']
      ..value = map['value']
      ..type = SecretType.values
          .firstWhere((e) => map['type'].toString().endsWith(e.name));
  }
}

enum SecretType { text }
