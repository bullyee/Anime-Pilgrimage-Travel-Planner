import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/utils/chinese_converter.dart';

void main() {
  group('ChineseConverter', () {
    test('toSimplified converts Traditional Chinese to Simplified', () {
      expect(ChineseConverter.toSimplified('吹響吧！上低音號'), '吹响吧！上低音号');
      expect(ChineseConverter.toSimplified('孤獨搖滾！'), '孤独摇滚！');
      expect(ChineseConverter.toSimplified('輕音少女'), '轻音少女');
      expect(ChineseConverter.toSimplified('涼宮春日的憂鬱'), '凉宫春日的忧郁');
      expect(ChineseConverter.toSimplified('搖曳露營△'), '摇曳露营△');
      expect(ChineseConverter.toSimplified('咒術迴戰'), '咒术回战');
      expect(ChineseConverter.toSimplified('轉生史萊姆'), '转生史莱姆');
      expect(ChineseConverter.toSimplified('命運石之門'), '命运石之门');
      expect(ChineseConverter.toSimplified('進擊的巨人'), '进击的巨人');
      expect(ChineseConverter.toSimplified('魔法少女小圓'), '魔法少女小圆');
      expect(ChineseConverter.toSimplified('葬送的芙莉蓮'), '葬送的芙莉莲');
      expect(ChineseConverter.toSimplified('東京都'), '东京都');
      expect(ChineseConverter.toSimplified('宇治市'), '宇治市');
    });

    test('toSimplified preserves empty, English, Japanese, and symbols', () {
      expect(ChineseConverter.toSimplified(''), '');
      expect(ChineseConverter.toSimplified('Sound! Euphonium'), 'Sound! Euphonium');
      expect(ChineseConverter.toSimplified('けいおん!'), 'けいおん!');
      expect(ChineseConverter.toSimplified('★☆♪'), '★☆♪');
    });

    test('toTraditional converts Simplified Chinese to Traditional', () {
      expect(ChineseConverter.toTraditional('吹响吧！上低音号'), '吹響吧！上低音號');
      expect(ChineseConverter.toTraditional('轻音少女'), '輕音少女');
      expect(ChineseConverter.toTraditional('孤独摇滚！'), '孤獨搖滾！');
      expect(ChineseConverter.toTraditional('东京都'), '東京都');
      expect(ChineseConverter.toTraditional(''), '');
    });

    test('normalize strips punctuation and converts to lowercase simplified', () {
      expect(ChineseConverter.normalize('吹響吧！上低音號'), '吹响吧上低音号');
      expect(ChineseConverter.normalize(' K-ON! 輕音少女 '), 'kon轻音少女');
      expect(ChineseConverter.normalize(''), '');
    });

    test('getAliases returns known aliases and nicknames', () {
      final spyAliases = ChineseConverter.getAliases('間諜家家酒');
      expect(spyAliases, contains('间谍过家家'));

      final euphoniumAliases = ChineseConverter.getAliases('京吹');
      expect(euphoniumAliases, contains('吹响吧！上低音号'));

      final frierenAliases = ChineseConverter.getAliases('芙莉蓮');
      expect(frierenAliases, contains('葬送的芙莉莲'));

      expect(ChineseConverter.getAliases(''), isEmpty);
      expect(ChineseConverter.getAliases('   '), isEmpty);
    });
  });
}
