import 'dart:async';

import 'package:pixtale_sync/l10n/locale.dart';
import 'package:pixtale_sync/providers/sync_provider.dart';

/// 把共享同步状态写入托盘提示，窗口隐藏后继续更新。
class TraySyncService {
  TraySyncService({required this.sync, required this.setToolTip}) {
    sync.addListener(_update);
    AppLocale.instance.addListener(_update);
    _update();
  }

  final SyncProvider sync;
  final Future<void> Function(String) setToolTip;
  Timer? _timer;
  String _desired = '';
  String? _shown;
  bool _updating = false;
  bool _disposed = false;

  void _update() {
    final text = AppLocale.strings(
      saved: AppLocale.instance.locale?.languageCode,
    );
    String tooltip;
    if (!sync.active) {
      tooltip = 'Pixtale Sync';
    } else if (sync.stopping) {
      tooltip = text.syncNoticeStopping;
    } else if (sync.currentAlbumId != null) {
      final progress = sync.progress[sync.currentAlbumId];
      if (sync.checking || progress == null) {
        tooltip = text.syncNoticeChecking;
      } else {
        tooltip =
            '${text.syncNoticeSyncing} '
            '${progress.completed} / ${progress.total}';
      }
    } else if (sync.nextSyncAt != null) {
      final next = sync.nextSyncAt!.toLocal();
      final time =
          '${next.hour.toString().padLeft(2, '0')}:'
          '${next.minute.toString().padLeft(2, '0')}';
      tooltip = text.syncNoticeNext(time);
    } else {
      tooltip = text.syncNoticePreparing;
    }
    if (sync.active && sync.currentAlbumId != null) {
      final name =
          (sync.currentAlbumName ??
                  sync.progress[sync.currentAlbumId]?.albumName ??
                  '')
              .replaceAll(RegExp(r'[\r\n]+'), ' ')
              .trim();
      if (name.isNotEmpty) tooltip += ' - $name';
    }
    // Windows 提示最多 127 个 UTF-16 单元，截断时保留完整 Unicode 字符。
    if (tooltip.length > 127) {
      final shortened = StringBuffer();
      for (final rune in tooltip.runes) {
        final character = String.fromCharCode(rune);
        if (shortened.length + character.length > 126) break;
        shortened.write(character);
      }
      tooltip = '$shortened…';
    }
    _desired = tooltip;
    _timer ??= Timer(const Duration(milliseconds: 200), () {
      _timer = null;
      unawaited(_flush());
    });
  }

  /// 合并密集进度并顺序写入，避免较旧的异步调用覆盖新状态。
  Future<void> _flush() async {
    if (_updating || _disposed) return;
    _updating = true;
    try {
      while (!_disposed && _shown != _desired) {
        final tooltip = _desired;
        await setToolTip(tooltip);
        _shown = tooltip;
      }
    } catch (_) {
      // 托盘更新失败不影响同步，下次状态变化时再尝试。
    } finally {
      _updating = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    sync.removeListener(_update);
    AppLocale.instance.removeListener(_update);
  }
}
