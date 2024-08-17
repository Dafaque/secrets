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
}

enum SecretType {text}