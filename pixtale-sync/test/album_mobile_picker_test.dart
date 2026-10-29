import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixtale_sync/components/album/album_mobile_picker.dart';
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/request/request.dart';
import 'package:pixtale_sync/services/photo_service.dart';
import 'package:pixtale_sync/theme/app_theme.dart';
import 'localized_app.dart';

// 验证相册数量加载前后的名称、封面及勾选框位置保持稳定。

/// 执行相册选择列表布局测试。
void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('文字缩放 $scale 时数量加载不改变相册布局', (tester) async {
      final photos = _PendingPhotos();
      await _pumpPicker(tester, photos, textScale: scale);

      final title = find.text('旅行');
      final tile = find.byType(ListTile);
      final checkbox = find.byType(Checkbox);
      final cover = find.byType(ClipRRect);
      final titleRect = tester.getRect(title);
      final tileRect = tester.getRect(tile);
      final checkboxRect = tester.getRect(checkbox);
      final coverRect = tester.getRect(cover);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('0'), findsNothing);

      final count = scale == 1 ? 123 : 0;
      photos.preview.complete(
        PhotoAlbumInfo(album: _PendingPhotos.album, count: count),
      );
      await tester.pumpAndSettle();

      expect(find.text('$count'), findsOneWidget);
      expect(tester.getRect(title), titleRect);
      expect(tester.getRect(tile), tileRect);
      expect(tester.getRect(checkbox), checkboxRect);
      expect(tester.getRect(cover), coverRect);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('名称排序忽略大小写，重排后保留勾选和已添加状态', (tester) async {
    final photos = _SortablePhotos();
    await _pumpPicker(tester, photos, selectedIds: const {'b'});
    await _selectSort(tester, '名称 A-Z');
    expect(_albumOrder(tester), ['a', 'b', 'c', 'z']);
    await tester.tap(find.text('Cherry'));
    await _selectSort(tester, '名称 Z-A');
    expect(_albumOrder(tester), ['z', 'c', 'b', 'a']);
    final selected = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(const ValueKey('c')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(selected.value, isTrue);
    final added = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(const ValueKey('b')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(added.value, isTrue);
    expect(added.onChanged, isNull);
    expect(photos.countRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('中文按完整拼音与英文混排，升降序保留原名称', (tester) async {
    final photos = _SortablePhotos(
      albums: const [
        PhotoAlbum(id: 'camera', name: '相机'),
        PhotoAlbum(id: 'travel', name: '旅行'),
        PhotoAlbum(id: 'z', name: 'Zebra'),
        PhotoAlbum(id: 'family', name: '家庭'),
        PhotoAlbum(id: 'work', name: '工作'),
        PhotoAlbum(id: 'a', name: 'apple'),
      ],
    );
    await _pumpPicker(tester, photos);
    const ascending = ['a', 'work', 'family', 'travel', 'camera', 'z'];
    await _selectSort(tester, '名称 A-Z');
    expect(_albumOrder(tester), ascending);
    for (final album in photos.albums) {
      expect(find.text(album.name), findsOneWidget);
    }
    await _selectSort(tester, '名称 Z-A');
    expect(_albumOrder(tester), ascending.reversed.toList());

    // 数量相同的相册也使用拼音作为第二排序条件。
    await _selectSort(tester, '数量从多到少');
    for (final completer in photos.counts.values) {
      completer.complete(3);
    }
    await tester.pumpAndSettle();
    expect(_albumOrder(tester), ascending);
    expect(tester.takeException(), isNull);
  });

  testWidgets('中英混合名和同音相册排序稳定', (tester) async {
    final photos = _SortablePhotos(
      albums: const [
        PhotoAlbum(id: 'c', name: '旅行B'),
        PhotoAlbum(id: 'b', name: '向机'),
        PhotoAlbum(id: 'd', name: '旅行a'),
        PhotoAlbum(id: 'a', name: '相机'),
      ],
    );
    await _pumpPicker(tester, photos);
    await _selectSort(tester, '名称 A-Z');
    expect(_albumOrder(tester), ['d', 'c', 'a', 'b']);
    await _selectSort(tester, '名称 Z-A');
    expect(_albumOrder(tester), ['a', 'b', 'c', 'd']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('名称和数量排序将空名称放末尾，默认排序恢复原始位置', (tester) async {
    final photos = _SortablePhotos(
      albums: const [
        PhotoAlbum(id: 'empty-b', name: ''),
        PhotoAlbum(id: 'z', name: 'Zebra'),
        PhotoAlbum(id: 'empty-a', name: ''),
        PhotoAlbum(id: 'a', name: 'apple'),
      ],
    );
    await _pumpPicker(tester, photos);
    const original = ['empty-b', 'z', 'empty-a', 'a'];
    expect(_albumOrder(tester), original);
    expect(photos.countRequests, isEmpty);
    await _selectSort(tester, '名称 A-Z');
    expect(_albumOrder(tester), ['a', 'z', 'empty-a', 'empty-b']);
    expect(find.text('未命名相册'), findsNWidgets(2));
    await _selectSort(tester, '名称 Z-A');
    expect(_albumOrder(tester), ['z', 'a', 'empty-a', 'empty-b']);
    await _selectSort(tester, '数量从多到少');
    for (final entry in {
      'empty-a': 100,
      'empty-b': 0,
      'a': 1,
      'z': 2,
    }.entries) {
      photos.counts[entry.key]!.complete(entry.value);
    }
    await tester.pumpAndSettle();
    expect(_albumOrder(tester), ['z', 'a', 'empty-a', 'empty-b']);
    await _selectSort(tester, '数量从少到多');
    expect(_albumOrder(tester), ['a', 'z', 'empty-b', 'empty-a']);
    await _selectSort(tester, '默认排序');
    expect(_albumOrder(tester), original);
    expect(find.text('100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('数量补齐后统一排序，支持升降序且零数量正常显示', (tester) async {
    final photos = _SortablePhotos();
    await _pumpPicker(tester, photos);
    await _selectSort(tester, '数量从多到少');
    expect(photos.countRequests.toSet(), {'a', 'b', 'c', 'z'});
    photos.counts['z']!.complete(0);
    await tester.pumpAndSettle();
    expect(_albumOrder(tester), ['z', 'b', 'a', 'c']);
    expect(find.text('0'), findsOneWidget);
    for (final entry in {'a': 9, 'b': 2, 'c': 9}.entries) {
      photos.counts[entry.key]!.complete(entry.value);
    }
    await tester.pumpAndSettle();
    expect(_albumOrder(tester), ['a', 'c', 'b', 'z']);
    await _selectSort(tester, '数量从少到多');
    expect(_albumOrder(tester), ['z', 'b', 'a', 'c']);
    expect(photos.countRequests, hasLength(4));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切回名称排序后，迟到的数量不改变顺序', (tester) async {
    final photos = _SortablePhotos();
    await _pumpPicker(tester, photos);
    await _selectSort(tester, '数量从多到少');
    await _selectSort(tester, '名称 Z-A');
    for (final completer in photos.counts.values) {
      completer.complete(1);
    }
    await tester.pumpAndSettle();
    expect(_albumOrder(tester), ['z', 'c', 'b', 'a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切回默认排序后，迟到的数量保留原始顺序', (tester) async {
    final photos = _SortablePhotos();
    await _pumpPicker(tester, photos);
    await _selectSort(tester, '名称 A-Z');
    await _selectSort(tester, '数量从多到少');
    await _selectSort(tester, '默认排序');
    for (final entry in {'a': 9, 'b': 2, 'c': 9, 'z': 0}.entries) {
      photos.counts[entry.key]!.complete(entry.value);
    }
    await tester.pumpAndSettle();
    expect(_albumOrder(tester), ['z', 'b', 'a', 'c']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('数量排序包含屏幕外相册，但不提前读取所有封面', (tester) async {
    final photos = _ManyPhotos();
    await _pumpPicker(tester, photos);
    expect(find.text('Album 59'), findsNothing);
    await _selectSort(tester, '数量从多到少');
    expect(_albumOrder(tester).first, '59');
    expect(find.text('Album 59'), findsOneWidget);
    expect(photos.countRequests, hasLength(60));
    expect(photos.coverRequests.length, lessThan(60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('重新打开恢复默认排序，数量升序菜单排在降序前面', (tester) async {
    await _pumpPicker(tester, _SortablePhotos());
    await _selectSort(tester, '名称 A-Z');
    expect(_albumOrder(tester), ['a', 'b', 'c', 'z']);
    await tester.pumpWidget(const SizedBox());
    await _pumpPicker(tester, _SortablePhotos());
    expect(_albumOrder(tester), ['z', 'b', 'a', 'c']);
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, '默认排序'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('数量从少到多')).dy,
      lessThan(tester.getTopLeft(find.text('数量从多到少')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有照片权限时在选择页中间显示提示', (tester) async {
    await _pumpPicker(tester, _DeniedPhotos());
    expect(find.text('需要照片访问权限'), findsOneWidget);
    expect(find.text('读取相册失败，请稍后重试'), findsNothing);
    expect(
      find.ancestor(of: find.text('需要照片访问权限'), matching: find.byType(Center)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPicker(
  WidgetTester tester,
  PhotoService photos, {
  Set<String> selectedIds = const {},
  double? textScale,
}) async {
  await tester.pumpWidget(
    localizedApp(
      theme: buildAppTheme(),
      builder: textScale == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
      home: AlbumMobilePicker(selectedIds: selectedIds, photoService: photos),
    ),
  );
  await tester.pumpAndSettle();
}

/// 从列表项的稳定 ID 读取当前顺序。
List<String> _albumOrder(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.key! as ValueKey<String>).value)
    .toList();

/// 打开排序菜单并选择指定规则。
Future<void> _selectSort(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.sort));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// 模拟系统拒绝照片访问。
class _DeniedPhotos extends PhotoService {
  /// 返回照片权限失败。
  @override
  Future<List<PhotoAlbum>> listAlbums() async {
    throw const ApiException('需要照片访问权限才能选择相册');
  }
}

/// 独立控制统计完成时间，封面保持待加载以验证数量不依赖封面。
class _SortablePhotos extends PhotoService {
  /// 可替换相册名，默认打乱英文顺序并保留大小写差异。
  _SortablePhotos({
    this.albums = const [
      PhotoAlbum(id: 'z', name: 'Zebra'),
      PhotoAlbum(id: 'b', name: 'Banana'),
      PhotoAlbum(id: 'a', name: 'apple'),
      PhotoAlbum(id: 'c', name: 'Cherry'),
    ],
  });

  /// 本次测试使用的相册。
  final List<PhotoAlbum> albums;

  /// 每个相册的独立数量请求。
  late final counts = {for (final album in albums) album.id: Completer<int>()};

  /// 验证切换规则时不会重复请求已缓存的统计。
  final List<String> countRequests = [];

  /// 尚未返回的封面预览。
  final _preview = Completer<PhotoAlbumInfo>();

  /// 返回未排序的系统相册。
  @override
  Future<List<PhotoAlbum>> listAlbums() async => albums;

  /// 保持封面读取挂起。
  @override
  Future<PhotoAlbumInfo> getInfo(PhotoAlbum album, {bool imagesOnly = true}) =>
      _preview.future;

  /// 记录统计请求并由测试提供媒体合计数量。
  @override
  Future<int> countMedia(PhotoAlbum album) {
    countRequests.add(album.id);
    return counts[album.id]!.future;
  }
}

/// 提供超出一屏的相册，用于验证全量统计和按需封面互不影响。
class _ManyPhotos extends PhotoService {
  /// 相册数量递增，让最后一个相册在排序后进入视口。
  final albums = List.generate(
    60,
    (index) => PhotoAlbum(
      id: '$index',
      name: 'Album ${index.toString().padLeft(2, '0')}',
    ),
  );

  /// 已统计和已请求预览的相册 ID。
  final Set<String> countRequests = {};
  final Set<String> coverRequests = {};

  /// 封面保持挂起，统计独立完成。
  final _preview = Completer<PhotoAlbumInfo>();

  /// 返回全部相册名称。
  @override
  Future<List<PhotoAlbum>> listAlbums() async => albums;

  /// 记录真正进入列表缓存区域的预览请求。
  @override
  Future<PhotoAlbumInfo> getInfo(PhotoAlbum album, {bool imagesOnly = true}) {
    coverRequests.add(album.id);
    return _preview.future;
  }

  /// 返回包含照片和视频的媒体合计数量。
  @override
  Future<int> countMedia(PhotoAlbum album) async {
    countRequests.add(album.id);
    return int.parse(album.id);
  }
}

/// 延迟相册预览，分别观察数量加载前后的布局。
class _PendingPhotos extends PhotoService {
  static const album = PhotoAlbum(id: 'album', name: '旅行');
  final preview = Completer<PhotoAlbumInfo>();

  /// 立即返回相册名称，不等待预览。
  @override
  Future<List<PhotoAlbum>> listAlbums() async => [album];

  /// 由测试控制封面和数量的完成时机。
  @override
  Future<PhotoAlbumInfo> getInfo(PhotoAlbum album, {bool imagesOnly = true}) =>
      preview.future;
}
