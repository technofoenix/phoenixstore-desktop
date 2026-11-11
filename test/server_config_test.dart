import 'package:flutter_test/flutter_test.dart';
import 'package:phoenixstore_desktop/core/config/server_config.dart';

void main() {
  group('normalize', () {
    test('a domain without scheme becomes https', () {
      expect(ServerConfig.normalize('api.shop.dz'), 'https://api.shop.dz');
    });

    test('localhost without scheme stays http', () {
      expect(ServerConfig.normalize('localhost:4000'), 'http://localhost:4000');
      expect(ServerConfig.normalize('127.0.0.1:4000'), 'http://127.0.0.1:4000');
    });

    test('strips trailing slashes and a pasted /api/v1', () {
      expect(
        ServerConfig.normalize('https://api.shop.dz/api/v1/'),
        'https://api.shop.dz',
      );
    });

    test('an explicit scheme is kept', () {
      expect(
        ServerConfig.normalize('http://api.shop.dz'),
        'http://api.shop.dz',
      );
    });
  });

  group('isAllowed', () {
    test('https is always allowed', () {
      expect(ServerConfig.isAllowed('https://api.shop.dz'), isTrue);
      expect(
        ServerConfig.isAllowed('https://192.168.1.10', allowLan: false),
        isTrue,
      );
    });

    test('http is allowed for loopback only', () {
      expect(
        ServerConfig.isAllowed('http://localhost:4000', allowLan: false),
        isTrue,
      );
      expect(
        ServerConfig.isAllowed('http://127.0.0.1:4000', allowLan: false),
        isTrue,
      );
      expect(
        ServerConfig.isAllowed('http://api.shop.dz', allowLan: false),
        isFalse,
      );
    });

    test('http to a LAN address only when LAN testing is on (debug)', () {
      expect(
        ServerConfig.isAllowed('http://192.168.1.10:4000', allowLan: false),
        isFalse,
      );
      expect(
        ServerConfig.isAllowed('http://192.168.1.10:4000', allowLan: true),
        isTrue,
      );
      expect(
        ServerConfig.isAllowed('http://172.20.0.5', allowLan: true),
        isTrue,
      );
      expect(
        ServerConfig.isAllowed('http://172.40.0.5', allowLan: true),
        isFalse,
      );
      expect(
        ServerConfig.isAllowed('http://api.shop.dz', allowLan: true),
        isFalse,
      );
    });

    test('empty or malformed URLs are refused', () {
      expect(ServerConfig.isAllowed(''), isFalse);
      expect(ServerConfig.isAllowed('ftp://api.shop.dz'), isFalse);
      expect(ServerConfig.isAllowed('https://'), isFalse);
    });
  });
}
