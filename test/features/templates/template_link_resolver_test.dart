// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/templates/interfaces/template_web_renderer.dart';
import 'package:trip_planner/features/templates/models/template_preview_info.dart';
import 'package:trip_planner/features/templates/providers/template_link_providers.dart';
import 'package:trip_planner/features/templates/services/template_link_resolver_service.dart';

void main() {
  late FakeTemplateFirestore fakeFirestore;
  late TemplateLinkResolverService service;

  setUp(() {
    fakeFirestore = FakeTemplateFirestore();
    service = TemplateLinkResolverService(firestore: fakeFirestore);
  });

  group('TemplateLinkResolverService.extractShortCode', () {
    test('extracts code from standard web URLs', () {
      expect(
        service.extractShortCode('https://trip-planner-2775c.web.app/t/K7MN2P'),
        'K7MN2P',
      );
      expect(
        service.extractShortCode('https://trip-planner-2775c.firebaseapp.com/t/9XYZ3A'),
        '9XYZ3A',
      );
      expect(
        service.extractShortCode('https://trip-planner-2775c.web.app/t/k7mn2p'),
        'K7MN2P',
      );
    });

    test('extracts code from URLs with query params, trailing slashes, or fragments', () {
      expect(
        service.extractShortCode('https://trip-planner-2775c.web.app/t/K7MN2P/?ref=line#preview'),
        'K7MN2P',
      );
      expect(
        service.extractShortCode('/t/K7MN2P'),
        'K7MN2P',
      );
    });

    test('extracts code from custom app deep links', () {
      expect(
        service.extractShortCode('tripplanner://template/K7MN2P'),
        'K7MN2P',
      );
      expect(
        service.extractShortCode('animepilgrim://template/9XYZ3A/'),
        '9XYZ3A',
      );
      expect(
        service.extractShortCode('tripplanner://K7MN2P'),
        'K7MN2P',
      );
    });

    test('extracts raw short code with whitespace and lowercase normalization', () {
      expect(service.extractShortCode('  K7MN2P  '), 'K7MN2P');
      expect(service.extractShortCode('k7mn2p'), 'K7MN2P');
      expect(service.extractShortCode('4A8F2K'), '4A8F2K');
    });

    test('rejects ambiguous characters (0, O, 1, I, L) and invalid lengths', () {
      // 0 and O
      expect(service.extractShortCode('K0MN2P'), isNull);
      expect(service.extractShortCode('KOMN2P'), isNull);

      // 1, I, and L
      expect(service.extractShortCode('K1MN2P'), isNull);
      expect(service.extractShortCode('KIMN2P'), isNull);
      expect(service.extractShortCode('KLMN2P'), isNull);

      // Invalid lengths
      expect(service.extractShortCode('K7MN2'), isNull); // 5 chars
      expect(service.extractShortCode('K7MN2P9'), isNull); // 7 chars

      // Special characters
      expect(service.extractShortCode('K7-N2P'), isNull);
      expect(service.extractShortCode('K7_N2P'), isNull);
      expect(service.extractShortCode(''), isNull);
      expect(service.extractShortCode('   '), isNull);
    });
  });

  group('TemplateLinkResolverService.resolveTemplate', () {
    test('resolves short code from Firestore and caches in memory', () async {
      // Seed code document
      fakeFirestore.setDoc('template_codes', 'K7MN2P', {
        'templateId': 'tmpl_uji_123',
        'code': 'K7MN2P',
        'createdAt': DateTime(2026, 11, 1),
      });

      // Seed template document
      fakeFirestore.setDoc('templates', 'tmpl_uji_123', {
        'id': 'tmpl_uji_123',
        'code': 'K7MN2P',
        'title': '響け！ユーフォニアム 宇治聖地巡禮',
        'description': '京阪宇治站 -> 宇治橋 -> 大吉山',
        'authorName': 'KumikoFan',
        'dayCount': 2,
        'stopCount': 10,
        'coverImageUrl': 'https://image.anitabi.cn/cover.jpg',
        'animeNames': ['響け！ユーフォニアム'],
        'areas': ['宇治地區'],
        'createdAt': DateTime(2026, 11, 1),
        'updatedAt': DateTime(2026, 11, 2),
      });

      final result1 = await service.resolveTemplate('https://trip-planner-2775c.web.app/t/K7MN2P');
      expect(result1, isNotNull);
      expect(result1!.code, 'K7MN2P');
      expect(result1.templateId, 'tmpl_uji_123');
      expect(result1.title, '響け！ユーフォニアム 宇治聖地巡禮');
      expect(result1.authorName, 'KumikoFan');
      expect(result1.dayCount, 2);
      expect(result1.stopCount, 10);
      expect(result1.coverImageUrl, 'https://image.anitabi.cn/cover.jpg');
      expect(result1.animeNames, contains('響け！ユーフォニアム'));
      expect(result1.areas, contains('宇治地區'));

      // Mutate fake Firestore doc to verify in-memory cache hit
      fakeFirestore.setDoc('templates', 'tmpl_uji_123', {
        'title': 'Mutated Title',
      });

      final result2 = await service.resolveTemplate('K7MN2P');
      expect(result2!.title, '響け！ユーフォニアム 宇治聖地巡禮', reason: 'served from cache');

      // Clear cache and verify fresh resolution
      service.clearCache();
      final result3 = await service.resolveTemplate('K7MN2P');
      expect(result3!.title, 'Mutated Title', reason: 're-fetched after cache clear');
    });

    test('returns null when short code does not exist in Firestore', () async {
      final result = await service.resolveTemplate('9XYZ3A');
      expect(result, isNull);
    });

    test('returns null for invalid inputs without calling Firestore', () async {
      expect(await service.resolveTemplate(''), isNull);
      expect(await service.resolveTemplate('INVALID_CODE'), isNull);
    });
  });

  group('TemplateMetaGenerator and Static HTML', () {
    final preview = TemplatePreviewInfo(
      code: 'K7MN2P',
      templateId: 'tmpl_uji_123',
      title: '宇治巡禮 2日遊',
      description: '跟著久美子一起漫步宇治川',
      authorName: 'Austin',
      dayCount: 2,
      stopCount: 8,
      coverImageUrl: 'https://image.anitabi.cn/points/1.jpg',
      animeNames: ['響け！ユーフォニアム'],
      areas: ['宇治地區'],
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
    );

    test('generateOpenGraphMetaTags produces compliant social scraper tags', () {
      final tags = service.generateOpenGraphMetaTags(preview);

      expect(tags['og:title'], contains('宇治巡禮 2日遊'));
      expect(tags['og:description'], contains('跟著久美子一起漫步宇治川'));
      expect(tags['og:url'], 'https://trip-planner-2775c.web.app/t/K7MN2P');
      expect(tags['og:image'], 'https://image.anitabi.cn/points/1.jpg');
      expect(tags['twitter:card'], 'summary_large_image');
      expect(tags['al:android:url'], 'tripplanner://template/K7MN2P');
      expect(tags['al:android:package'], 'com.example.trip_planner');
    });

    test('generateStaticPreviewHtml generates valid HTML shell with embedded meta tags', () {
      final html = service.generateStaticPreviewHtml(preview);

      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<html lang="zh-Hant">'));
      expect(html, contains('<meta property="og:title" content="宇治巡禮 2日遊 | 聖地巡禮行程規劃">'));
      expect(html, contains('<meta property="og:url" content="https://trip-planner-2775c.web.app/t/K7MN2P">'));
      expect(html, contains('<a class="btn" href="tripplanner://template/K7MN2P">'));
      expect(html, contains('響け！ユーフォニアム'));
    });

    test('DefaultTemplateWebRenderer produces clean text summary', () {
      final rendered = service.render(preview) as String;
      expect(rendered, contains('宇治巡禮 2日遊 (by Austin)'));
      expect(rendered, contains('2 Days · 8 Spots'));
      expect(rendered, contains('Featured Anime: 響け！ユーフォニアム'));
      expect(rendered, contains('Pilgrimage Areas: 宇治地區'));
      expect(rendered, contains('Link: https://trip-planner-2775c.web.app/t/K7MN2P'));
    });
  });

  group('Riverpod Providers', () {
    test('templatePreviewQueryProvider resolves template reactively', () async {
      fakeFirestore.setDoc('template_codes', '4A8F2K', {
        'templateId': 'tmpl_bocchi_99',
      });
      fakeFirestore.setDoc('templates', 'tmpl_bocchi_99', {
        'id': 'tmpl_bocchi_99',
        'code': '4A8F2K',
        'title': '孤獨搖滾！下北澤巡禮',
        'authorName': 'BocchiFan',
        'dayCount': 1,
        'stopCount': 5,
        'createdAt': DateTime(2026, 11, 1),
        'updatedAt': DateTime(2026, 11, 2),
      });

      final container = ProviderContainer(
        overrides: [
          templateLinkResolverServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(templatePreviewQueryProvider('4a8f2k').future);
      expect(result, isNotNull);
      expect(result!.title, '孤獨搖滾！下北澤巡禮');
      expect(result.stopCount, 5);

      final empty = await container.read(templatePreviewQueryProvider('').future);
      expect(empty, isNull);
    });
  });
}

/// In-memory Fake Firestore for TemplateLinkResolver testing.
class FakeTemplateFirestore implements FirebaseFirestore {
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};

  void setDoc(String collection, String docId, Map<String, dynamic> data) {
    _data.putIfAbsent(collection, () => {})[docId] = Map<String, dynamic>.from(data);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollection(this, collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  final FakeTemplateFirestore _db;
  final String _collection;

  _FakeCollection(this._db, this._collection);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeDocRef(_db, _collection, path ?? 'auto_id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  final FakeTemplateFirestore _db;
  final String _collection;
  final String _docId;

  _FakeDocRef(this._db, this._collection, this._docId);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final col = _db._data[_collection];
    final docData = col?[_docId];
    return _FakeDocSnapshot(_docId, docData);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;

  _FakeDocSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
