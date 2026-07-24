import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/services/voice_intent_classifier.dart';
import 'package:shg_saathi/services/voice_recognition_service.dart';

/// Regression coverage for the keyword classifier that turns a real STT
/// transcript (arbitrary free text) into a bounded [VoiceIntent] — this is
/// new logic introduced when the AI Voice Assistant switched from a fixed
/// mock command list to a real on-device speech engine, and had no test
/// coverage of its own.
void main() {
  group('VoiceIntentClassifier.classify (English)', () {
    test('recognizes a loan-details command', () {
      expect(
        VoiceIntentClassifier.classify('Show my loan details', Language.en),
        VoiceIntent.loanDetails,
      );
    });

    test('recognizes a savings-this-month command', () {
      expect(
        VoiceIntentClassifier.classify('How much savings this month?', Language.en),
        VoiceIntent.savingsThisMonth,
      );
    });

    test('recognizes an add-savings command even though it also mentions savings', () {
      expect(
        VoiceIntentClassifier.classify('Add a savings entry', Language.en),
        VoiceIntent.addSavings,
      );
    });

    test('recognizes a read-announcements command', () {
      expect(
        VoiceIntentClassifier.classify('Read my announcements', Language.en),
        VoiceIntent.readAnnouncements,
      );
    });

    test('falls back to unknown for unrelated speech', () {
      expect(
        VoiceIntentClassifier.classify('What is the weather today', Language.en),
        VoiceIntent.unknown,
      );
    });

    test('falls back to unknown for an empty transcript', () {
      expect(VoiceIntentClassifier.classify('', Language.en), VoiceIntent.unknown);
      expect(VoiceIntentClassifier.classify('   ', Language.en), VoiceIntent.unknown);
    });

    test('is case-insensitive', () {
      expect(
        VoiceIntentClassifier.classify('SHOW MY LOAN DETAILS', Language.en),
        VoiceIntent.loanDetails,
      );
    });
  });

  group('VoiceIntentClassifier.classify (Hindi)', () {
    test('recognizes a loan-details command', () {
      expect(
        VoiceIntentClassifier.classify('मेरे ऋण का विवरण दिखाओ', Language.hi),
        VoiceIntent.loanDetails,
      );
    });

    test('recognizes an add-savings command', () {
      expect(
        VoiceIntentClassifier.classify('बचत जोड़ें', Language.hi),
        VoiceIntent.addSavings,
      );
    });

    test('recognizes a read-announcements command', () {
      expect(
        VoiceIntentClassifier.classify('मेरी घोषणाएं पढ़ो', Language.hi),
        VoiceIntent.readAnnouncements,
      );
    });
  });

  group('VoiceIntentClassifier.classify (Telugu)', () {
    test('recognizes a loan-details command', () {
      expect(
        VoiceIntentClassifier.classify('నా రుణ వివరాలు చూపించు', Language.te),
        VoiceIntent.loanDetails,
      );
    });

    test('recognizes a savings-this-month command', () {
      expect(
        VoiceIntentClassifier.classify('ఈ నెల పొదుపు ఎంత?', Language.te),
        VoiceIntent.savingsThisMonth,
      );
    });

    test('recognizes a read-announcements command', () {
      expect(
        VoiceIntentClassifier.classify('నా ప్రకటనలు చదవండి', Language.te),
        VoiceIntent.readAnnouncements,
      );
    });
  });
}
