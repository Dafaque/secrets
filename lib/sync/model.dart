import 'dart:convert';

enum SyncState {
  ready,
  error,
  processing,
  done,
  waitingForClient,
  waitingForHost,
}

class SyncStatus {
  final SyncState state;
  final String message;

  SyncStatus(this.state, this.message);
}

class AddrInfo {
  final String ip;
  final int port;
  final List<int> key;

  AddrInfo(this.ip, this.port, this.key);

  String toUrl() {
    final keyStr = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'sync://?ip=$ip&port=$port&key=$keyStr';
  }

  static AddrInfo? fromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'sync') return null;

      final ip = uri.queryParameters['ip'];
      final portStr = uri.queryParameters['port'];
      final keyStr = uri.queryParameters['key'];
      if (ip == null || portStr == null || keyStr == null) return null;

      final port = int.parse(portStr);
      final keyList = <int>[];
      for (var i = 0; i < keyStr.length; i += 2) {
        keyList.add(int.parse(keyStr.substring(i, i + 2), radix: 16));
      }
      return AddrInfo(ip, port, keyList);
    } catch (e) {
      return null;
    }
  }
}

class SyncMessage {
  final String type;
  final String? payload;

  SyncMessage(this.type, {this.payload});

  String encode() {
    if (payload != null) {
      final p = base64Encode(utf8.encode(payload!));
      return '$type:$p';
    }
    return type;
  }

  static SyncMessage? decode(String data) {
    final parts = data.split(':');
    if (parts.isEmpty) return null;

    final type = parts[0];
    final payload =
        parts.length > 1 ? utf8.decode(base64Decode(parts[1])) : null;
    return SyncMessage(type, payload: payload);
  }

  String toProtocol() {
    final message = encode();
    return '${message.length} $message';
  }

  static SyncMessage? fromProtocol(String data) {
    final spaceIndex = data.indexOf(' ');
    if (spaceIndex == -1) return null;

    final length = int.parse(data.substring(0, spaceIndex));
    final message = data.substring(spaceIndex + 1);
    if (message.length != length) return null;
    return decode(message);
  }
}
