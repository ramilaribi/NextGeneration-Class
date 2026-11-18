import 'package:flutter_test/flutter_test.dart';
import 'package:ngclass/domain/model/meet_link.dart';

void main() {
  group('a visio link is cleaned before it is checked', () {
    test('the spaces a phone keyboard adds go', () {
      expect(cleanMeetLink('https: //www.whatsapp.com'), 'https://www.whatsapp.com');
      expect(cleanMeetLink('  https://meet.google.com/ abc-defg-hij \n'), 'https://meet.google.com/abc-defg-hij');
    });

    test('a capital or a missing "https://" is fixed, http becomes https', () {
      expect(cleanMeetLink('Https://meet.google.com/abc'), 'https://meet.google.com/abc');
      expect(cleanMeetLink('meet.google.com/abc-defg-hij'), 'https://meet.google.com/abc-defg-hij');
      expect(cleanMeetLink('http://zoom.us/j/123'), 'https://zoom.us/j/123');
      expect(cleanMeetLink('https:/meet.google.com/abc'), 'https://meet.google.com/abc');
    });

    test('an empty field stays empty; something that is not a link is refused', () {
      expect(cleanMeetLink('   '), '');
      expect(isValidMeetLink(cleanMeetLink('https://meet.google.com/abc')), isTrue);
      expect(isValidMeetLink(cleanMeetLink('bonjour')), isFalse);
      expect(isValidMeetLink(cleanMeetLink('ftp://files.example.com')), isFalse);
    });
  });
}
