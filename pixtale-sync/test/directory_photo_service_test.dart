import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pixtale_sync/models/photo.dart';
import 'package:pixtale_sync/services/directory_photo_service.dart';

// 验证桌面封面缩略图尺寸、最新图片选择和原文件保留。

/// 执行不依赖目录选择器的桌面封面测试。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DirectoryPhotoService();
  late Directory directory;
  late PhotoAlbum album;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('desktop_cover_');
    album = PhotoAlbum(id: directory.path, name: '测试相册', directory: directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  for (final (width, height, expectedWidth, expectedHeight) in [
    (1024, 512, 256, 128),
    (512, 1024, 128, 256),
    (512, 512, 256, 256),
    (80, 40, 80, 40),
  ]) {
    test('$width × $height 封面等比缩放且不改动原图', () async {
      final original = await createImage(width, height);
      final file = File(p.join(directory.path, 'cover.png'));
      await file.writeAsBytes(original);

      final info = await service.getInfo(album);
      expect(info.count, 1);
      final codec = await ui.instantiateImageCodec(info.cover!);
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          expect(image.width, expectedWidth);
          expect(image.height, expectedHeight);
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
      expect(await file.readAsBytes(), orderedEquals(original));
      final photos = await service
          .scanAlbum(album, isStopped: () => false)
          .expand((page) => page)
          .toList();
      expect(photos.single.path, file.path);
      expect(photos.single.size, original.length);
    });
  }

  test('仅生成最新图片封面，空目录不生成封面', () async {
    final empty = await service.getInfo(album);
    expect(empty.count, 0);
    expect(empty.cover, isNull);

    final old = File(p.join(directory.path, 'old.png'));
    await old.writeAsBytes(await createImage(40, 80));
    await old.setLastModified(DateTime(2020));
    final latest = File(p.join(directory.path, 'latest.png'));
    await latest.writeAsBytes(await createImage(80, 40));
    await latest.setLastModified(DateTime(2021));

    final info = await service.getInfo(album);
    expect(info.count, 2);
    final codec = await ui.instantiateImageCodec(info.cover!);
    try {
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.width, 80);
        expect(image.height, 40);
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });

  test('最新文件是视频时，封面仍使用最新图片', () async {
    final video = File(p.join(directory.path, 'new.mp4'));
    await video.writeAsBytes(const [
      0x00, 0x00, 0x00, 0x18, //
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x71, 0x74, 0x20, 0x20, // qt
    ]);
    await video.setLastModified(DateTime(2024));
    final image = File(p.join(directory.path, 'old.png'));
    await image.writeAsBytes(await createImage(80, 40));
    await image.setLastModified(DateTime(2020));

    final info = await service.getInfo(album);
    expect(info.count, 2);
    final codec = await ui.instantiateImageCodec(info.cover!);
    try {
      final frame = (await codec.getNextFrame()).image;
      try {
        expect(frame.width, 80);
        expect(frame.height, 40);
      } finally {
        frame.dispose();
      }
    } finally {
      codec.dispose();
    }
  });

  test('只有视频时保留数量，不生成封面', () async {
    final video = File(p.join(directory.path, 'only.mov'));
    await video.writeAsBytes(const [
      0x00, 0x00, 0x00, 0x14, //
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x71, 0x74, 0x20, 0x20, // qt
    ]);

    final info = await service.getInfo(album);
    expect(info.count, 1);
    expect(info.cover, isNull);
  });

  test('扩展名和文件头都在白名单才保留', () async {
    const jpeg = [0xFF, 0xD8, 0xFF];
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    const gif = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61];
    const webp = [
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, // RIFF
      0x57, 0x45, 0x42, 0x50, // WEBP
    ];
    final mp4 = [
      0x00, 0x00, 0x00, 0x18, //
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x69, 0x73, 0x6F, 0x6D, // isom
    ];
    final mov = [
      0x00, 0x00, 0x00, 0x14, //
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x71, 0x74, 0x20, 0x20, // qt
    ];
    final ebml = [0x1A, 0x45, 0xDF, 0xA3];
    final avi = [
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, // RIFF
      0x41, 0x56, 0x49, 0x20, // AVI
    ];
    final gp = [
      0x00, 0x00, 0x00, 0x18, //
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x33, 0x67, 0x70, 0x35, // 3gp5
    ];
    final accepted = {
      'a.jpg': jpeg,
      'b.jpeg': jpeg,
      'c.png': png,
      'd.JFIF': jpeg,
      'e.webp': webp,
      'f.gif': gif,
      'mismatch.jpg': png,
      'movie.mp4': mp4,
      'clip.mov': mov,
      'browser.webm': ebml,
      'film.mkv': ebml,
      'old.avi': avi,
    };
    for (final entry in accepted.entries) {
      await File(p.join(directory.path, entry.key)).writeAsBytes(entry.value);
    }
    const avif = [
      0x00,
      0x00,
      0x00,
      0x18,
      0x66,
      0x74,
      0x79,
      0x70,
      0x61,
      0x76,
      0x69,
      0x66,
      0,
      0,
      0,
      0,
    ];
    const heic = [
      0x00, 0x00, 0x00, 0x18, //
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x68, 0x65, 0x69, 0x63, // heic
    ];
    for (final name in [
      'broken.jpg',
      'bad.mp4',
      'photo.mp4',
      'renamed.mp4',
      'phone.m4v',
      'disc.mpg',
      'disc.mpeg',
      'mobile.3gp',
      'camera.mts',
      'camera.m2ts',
      'g.avif',
      'h.heic',
      'i.heif',
      'j.bmp',
      'k.tif',
      'l.tiff',
      'm.txt',
    ]) {
      final bytes = switch (name) {
        'h.heic' => jpeg,
        'g.avif' => avif,
        'photo.mp4' => heic,
        'renamed.mp4' => gp,
        _ => const [1, 2, 3],
      };
      await File(p.join(directory.path, name)).writeAsBytes(bytes);
    }

    expect(await service.count(album), accepted.length);
    final photos = await service
        .scanAlbum(album, isStopped: () => false)
        .expand((page) => page)
        .toList();
    expect(
      photos.map((photo) => photo.name.toLowerCase()),
      unorderedEquals(accepted.keys.map((name) => name.toLowerCase())),
    );
    expect(
      photos.singleWhere((photo) => photo.name == 'movie.mp4').mimeType,
      'video/mp4',
    );
    expect(
      photos.singleWhere((photo) => photo.name == 'clip.mov').mimeType,
      'video/quicktime',
    );
    expect(
      photos.singleWhere((photo) => photo.name == 'browser.webm').mimeType,
      'video/webm',
    );
    expect(
      photos.singleWhere((photo) => photo.name == 'film.mkv').mimeType,
      'video/x-matroska',
    );
    expect(
      photos.singleWhere((photo) => photo.name == 'old.avi').mimeType,
      'video/x-msvideo',
    );
  });
}

/// 使用 Flutter 绘制并编码测试图片，无需额外依赖。
Future<Uint8List> createImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xFF2378AB), ui.BlendMode.src);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    try {
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
