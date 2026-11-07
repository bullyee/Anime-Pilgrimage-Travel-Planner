import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_planner/features/anime/models/indexed_anime_work.dart';
import 'package:trip_planner/features/anime/providers/anime_search_providers.dart';
import 'package:trip_planner/features/anime/services/multilingual_anime_search_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('anime_search_test_');
    MultilingualAnimeSearchService.instance.clearMemoryIndex();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Mock g.json index format: [works, pageSize, version]
  // Work row format: [id, cnTitle, 0, jpTitle, city, 0, img, 0, platform, lat, lng, zoom, coords, ...]
  List<Object> createWorkRow({
    required int id,
    required String cn,
    required String jp,
    String city = '京都市',
    String platform = 'TV',
    int spotCount = 2,
    String? img,
  }) {
    final coords = <Object>[];
    for (var i = 0; i < spotCount; i++) {
      coords.addAll(['spot_$i', 35.0 + i * 0.01, 135.7 + i * 0.01, 1]);
    }

    return [
      id,
      cn,
      0,
      jp,
      city,
      0,
      img ?? 0,
      0,
      platform,
      35.0,
      135.7,
      11,
      coords,
    ];
  }

  final mockWorks = [
    createWorkRow(
      id: 1424,
      cn: '轻音少女',
      jp: 'けいおん！',
      city: '京都市',
      spotCount: 20,
      img: '/images/1424/cover.jpg',
    ),
    createWorkRow(
      id: 115908,
      cn: '吹响吧！上低音号',
      jp: '響け！ユーフォニアム',
      city: '宇治市',
      spotCount: 45,
    ),
    createWorkRow(
      id: 364450,
      cn: '孤独摇滚！',
      jp: 'ぼっち・ざ・ろっく！',
      city: '下北沢',
      spotCount: 30,
    ),
    createWorkRow(
      id: 253,
      cn: '凉宫春日的忧郁',
      jp: '涼宮ハルヒの憂鬱',
      city: '西宮市',
      spotCount: 15,
    ),
    createWorkRow(
      id: 236465,
      cn: '摇曳露营△',
      jp: 'ゆるキャン△',
      city: '山梨県',
      spotCount: 50,
    ),
    createWorkRow(
      id: 398647,
      cn: '葬送的芙莉莲',
      jp: '葬送のフリーレン',
      city: '半田市',
      spotCount: 10,
    ),
    createWorkRow(
      id: 341852,
      cn: '间谍过家家',
      jp: 'SPY×FAMILY',
      city: '東京都',
      spotCount: 8,
    ),
  ];

  String createMockIndexJson(List<List<Object>> works) {
    return jsonEncode([works, 250, 'v1.0.0']);
  }

  group('IndexedAnimeWork', () {
    test('fromAnitabiRow parses g.json row correctly', () {
      final row = createWorkRow(
        id: 115908,
        cn: '吹响吧！上低音号',
        jp: '響け！ユーフォニアム',
        city: '宇治市',
        spotCount: 3,
        img: '/images/115908/thumb.jpg',
      );

      final work = IndexedAnimeWork.fromAnitabiRow(row);
      expect(work.bangumiId, '115908');
      expect(work.japaneseTitle, '響け！ユーフォニアム');
      expect(work.chineseTitle, '吹响吧！上低音号');
      expect(work.traditionalTitle, '吹響吧！上低音號');
      expect(work.city, '宇治市');
      expect(work.spotCount, 3);
      expect(work.coverUrl,
          'https://image.anitabi.cn/115908/thumb.jpg?plan=h160');

      final subject = work.toBangumiSubject();
      expect(subject.id, '115908');
      expect(subject.name, '響け！ユーフォニアム');
      expect(subject.nameCn, '吹響吧！上低音號');
      expect(subject.summary, contains('宇治市'));
      expect(subject.summary, contains('3'));
    });

    test('calculateRelevance scores exact, prefix, and alias matches', () {
      final work = IndexedAnimeWork.fromAnitabiRow(createWorkRow(
        id: 115908,
        cn: '吹响吧！上低音号',
        jp: '響け！ユーフォニアム',
        city: '宇治市',
        spotCount: 40,
      ));

      // Exact match with traditional Chinese
      final tcExact = work.calculateRelevance('吹響吧！上低音號');
      expect(tcExact, greaterThanOrEqualTo(100));

      // Prefix match
      final prefixScore = work.calculateRelevance('吹響吧');
      expect(prefixScore, greaterThanOrEqualTo(80));

      // Nickname / alias match (京吹)
      final aliasScore = work.calculateRelevance('京吹');
      expect(aliasScore, greaterThanOrEqualTo(75));

      // City match
      final cityScore = work.calculateRelevance('宇治');
      expect(cityScore, greaterThanOrEqualTo(40));

      // Direct Bangumi ID match
      final idScore = work.calculateRelevance('115908');
      expect(idScore, greaterThanOrEqualTo(150));

      // Irrelevant query
      expect(work.calculateRelevance('進擊的巨人'), 0);
      expect(work.calculateRelevance(''), 0);
    });
  });

  group('MultilingualAnimeSearchService', () {
    test('loads index from disk cache and performs offline multilingual search',
        () async {
      final indexFile = File('${tempDir.path}/g.json');
      await indexFile.writeAsString(createMockIndexJson(mockWorks));

      final service = MultilingualAnimeSearchService(
        cacheDir: () async => tempDir,
      );

      final index = await service.loadIndex();
      expect(index.length, 7);
      expect(service.isIndexLoaded, isTrue);

      // Traditional Chinese query matching Simplified title
      final results1 = await service.search('吹響吧！上低音號');
      expect(results1, isNotEmpty);
      expect(results1.first.bangumiId, '115908');

      // Traditional Chinese query for Bocchi the Rock
      final results2 = await service.search('孤獨搖滾');
      expect(results2, isNotEmpty);
      expect(results2.first.bangumiId, '364450');

      // Japanese kana query for K-ON!
      final results3 = await service.search('けいおん!');
      expect(results3, isNotEmpty);
      expect(results3.first.bangumiId, '1424');

      // Anime alias search: "芙莉蓮" -> "葬送的芙莉莲"
      final results4 = await service.search('芙莉蓮');
      expect(results4, isNotEmpty);
      expect(results4.first.bangumiId, '398647');

      // Anime alias search: "間諜家家酒" -> "间谍过家家"
      final results5 = await service.search('間諜家家酒');
      expect(results5, isNotEmpty);
      expect(results5.first.bangumiId, '341852');

      // City search: "宇治"
      final results6 = await service.search('宇治');
      expect(results6, isNotEmpty);
      expect(results6.first.bangumiId, '115908');
    });

    test('searchAsSubjects returns BangumiSubject with formatted spot summary',
        () async {
      final indexFile = File('${tempDir.path}/g.json');
      await indexFile.writeAsString(createMockIndexJson(mockWorks));

      final service = MultilingualAnimeSearchService(
        cacheDir: () async => tempDir,
      );

      final subjects = await service.searchAsSubjects('輕音少女');
      expect(subjects, isNotEmpty);
      expect(subjects.first.id, '1424');
      expect(subjects.first.name, 'けいおん！');
      expect(subjects.first.nameCn, '輕音少女');
      expect(subjects.first.summary, contains('20 個巡禮點'));
    });

    test('handles empty and whitespace queries gracefully', () async {
      final service = MultilingualAnimeSearchService(
        cacheDir: () async => tempDir,
      );

      expect(await service.search(''), isEmpty);
      expect(await service.search('    '), isEmpty);
      expect(await service.searchAsSubjects(''), isEmpty);
    });

    test('falls back to Bangumi API when local index has no match', () async {
      final indexFile = File('${tempDir.path}/g.json');
      await indexFile.writeAsString(createMockIndexJson(mockWorks));

      var bangumiApiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('api.bgm.tv')) {
          bangumiApiCalled = true;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'data': [
                {
                  'id': 9999,
                  'name': 'Fallback Anime',
                  'name_cn': '後備動畫',
                  'images': {'medium': 'https://bgm.tv/cover.jpg'},
                  'platform': 'TV',
                }
              ]
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('not found', 404);
      });

      final service = MultilingualAnimeSearchService(
        client: mockClient,
        cacheDir: () async => tempDir,
      );

      // Query that does not exist in local index
      final results = await service.search('NonExistentTitle', fallbackToBangumi: true);
      expect(bangumiApiCalled, isTrue);
      expect(results, isNotEmpty);
      expect(results.first.bangumiId, '9999');
      expect(results.first.japaneseTitle, 'Fallback Anime');

      // When fallbackToBangumi is false, does not call Bangumi API
      bangumiApiCalled = false;
      final resultsWithoutFallback =
          await service.search('NonExistentTitle', fallbackToBangumi: false);
      expect(bangumiApiCalled, isFalse);
      expect(resultsWithoutFallback, isEmpty);
    });

    test('Riverpod provider family evaluates search queries', () async {
      final indexFile = File('${tempDir.path}/g.json');
      await indexFile.writeAsString(createMockIndexJson(mockWorks));

      final testService = MultilingualAnimeSearchService(
        cacheDir: () async => tempDir,
      );

      final container = ProviderContainer(
        overrides: [
          multilingualAnimeSearchServiceProvider.overrideWithValue(testService),
        ],
      );
      addTearDown(container.dispose);

      final results = await container.read(animeSearchQueryProvider('けいおん').future);
      expect(results, isNotEmpty);
      expect(results.first.bangumiId, '1424');

      final subjects = await container.read(animeSubjectSearchProvider('搖曳露營').future);
      expect(subjects, isNotEmpty);
      expect(subjects.first.id, '236465');
    });
  });
}
