import 'dart:math';

class Utils {
  static String GenerateId() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();

    String id = '';
    for (int i = 0; i < 10; i++) {
      id += chars[random.nextInt(chars.length)];
    }

    return id;
  }
}
