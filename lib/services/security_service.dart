import 'package:encrypt/encrypt.dart';

class SecurityService {
  static final _key = Key.fromUtf8('QubicoTransportes2024SecureKey!!');
  static final _iv = IV.fromLength(16);
  static final _encrypter = Encrypter(AES(_key));

  static String encrypt(String text) {
    if (text.isEmpty) return text;
    final encrypted = _encrypter.encrypt(text, iv: _iv);
    return encrypted.base64;
  }

  static String decrypt(String base64Text) {
    if (base64Text.isEmpty) return base64Text;
    try {
      return _encrypter.decrypt64(base64Text, iv: _iv);
    } catch (e) {
      return base64Text;
    }
  }

  static String hashPassword(String password) {
    if (password.isEmpty) return password;
    return encrypt(password);
  }

  static bool verifyPassword(String inputPassword, String dbPasswordHash) {
    final encryptedInput = encrypt(inputPassword);
    return encryptedInput == dbPasswordHash;
  }
}
