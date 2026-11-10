import 'package:chat/models/chat.dart';
import 'package:chat/models/message.dart';
import 'package:chat/theme/app_palette.dart';
import 'package:chat/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Chat model', () {
    test('direct chat id is the same for both users', () {
      expect(Chat.directId('b', 'a'), Chat.directId('a', 'b'));
      expect(Chat.directId('a', 'b'), 'a_b');
    });

    test('parses unread, typing and other member', () {
      final chat = Chat.fromMap('a_b', {
        'type': 'direct',
        'members': ['a', 'b'],
        'unread': {'a': 3},
        'typing': {'b': true, 'a': true},
      });
      expect(chat.isGroup, isFalse);
      expect(chat.unreadFor('a'), 3);
      expect(chat.unreadFor('b'), 0);
      expect(chat.otherMember('a'), 'b');
      expect(chat.typingUsers('a'), ['b']);
    });
  });

  group('Message model', () {
    test('summarises reactions by popularity', () {
      final m = Message.fromMap('1', {
        'text': 'hi',
        'senderId': 'a',
        'senderName': 'Alice',
        'reactions': {'a': '❤️', 'b': '🔥', 'c': '❤️'},
        'replyTo': {'id': '0', 'text': 'yo', 'senderName': 'Bob'},
      });
      expect(m.isPending, isTrue);
      expect(m.replyTo?.senderName, 'Bob');
      expect(m.reactionSummary.first.key, '❤️');
      expect(m.reactionSummary.first.value, 2);
    });
  });

  test('every palette builds a light and a dark theme', () {
    for (final spec in PaletteSpec.all) {
      for (final b in Brightness.values) {
        final theme = AppTheme.build(spec, b);
        expect(theme.brightness, b);
        expect(theme.extension<AppPalette>()?.spec.id, spec.id);
        expect(theme.colorScheme.primary, spec.primary);
      }
    }
  });
}
