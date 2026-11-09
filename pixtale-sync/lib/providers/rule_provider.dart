import 'package:flutter/foundation.dart';
import 'package:pixtale_sync/models/rule.dart';
import 'package:pixtale_sync/services/rule_service.dart';

// 任务弹窗只读取本地同步规则，不请求远端存储。

/// 保存任务可选规则与当前选择。
class RuleProvider extends ChangeNotifier {
  /// 使用本地规则服务创建选择状态。
  RuleProvider(this._service);

  final RuleService _service;
  List<Rule> items = [];
  String? selectedId;
  String? error;
  bool _disposed = false;

  /// 返回当前选中的有效规则。
  Rule? get selected =>
      items.where((item) => item.id == selectedId).firstOrNull;

  /// 每次打开选择框时读取本地规则，保留有效选择。
  Future<void> load() async {
    error = null;
    try {
      items = await _service.list();
      if (!items.any((item) => item.id == selectedId)) {
        selectedId = items.firstOrNull?.id;
      }
    } catch (failure) {
      items = [];
      selectedId = null;
      error = '$failure';
    }
    if (!_disposed) notifyListeners();
  }

  /// 选择指定规则，空值默认选择第一项。
  void select(String? id) {
    selectedId = id ?? items.firstOrNull?.id;
    notifyListeners();
  }

  /// 释放监听，忽略尚未完成的读取通知。
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
