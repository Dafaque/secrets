import 'dart:math';


String randomHexString(int length) {
  Random random = Random();
  StringBuffer sb = StringBuffer();
  for (var i = 0; i < length; i++) {
    sb.write(random.nextInt(16).toRadixString(16));
  }
  return sb.toString();
}