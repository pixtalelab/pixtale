import 'package:flutter/foundation.dart';
import 'package:pixtale_sync/models/storage.dart';
import 'package:pixtale_sync/services/storage_service.dart';

// 添加任务时先展示本地存储列表，再刷新远端数据。

/// 保存存储选项、单选值和刷新状态。
class StorageProvider extends ChangeNotifier {
  /// 创建存储列表状态。
  StorageProvider(this._service);

  final StorageService _service;
  List<Storage> items = [];
  String? selectedId;
  bool loading = false;
  String? error;
  Future<void>? _operation;
  bool _disposed = false;

  /// 返回当前选中的有效存储。
  Storage? get selected =>
      items.where((item) => item.id == selectedId).firstOrNull;

  /// 合并并行刷新，页面进入和每次打开弹窗都可调用。
  Future<void> load() =>
      _operation ??= _load().whenComplete(() => _operation = null);

  /// 切换单选存储，未指定时默认选择第一项。
  void select(String? id) {
    selectedId = id ?? items.firstOrNull?.id;
    _notify();
  }

  /// 先发布缓存，再用远端结果替换；网络失败保留缓存。
  Future<void> _load() async {
    loading = true;
    error = null;
    _notify();
    try {
      _replace(await _service.list());
      _replace(await _service.refresh());
    } catch (failure) {
      error = '$failure';
    } finally {
      loading = false;
      _notify();
    }
  }

  /// 更新列表，保留有效选择，否则默认选择第一项。
  void _replace(List<Storage> values) {
    items = values;
    if (!items.any((item) => item.id == selectedId)) {
      selectedId = items.firstOrNull?.id;
    }
    _notify();
  }

  /// 避免异步结果通知已关闭的页面。
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 释放存储列表监听。
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
