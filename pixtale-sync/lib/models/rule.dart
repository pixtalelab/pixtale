/// 模板规则支持的文件类型。
enum RuleFileType { photo, video, any }

/// 本地模板及按添加顺序排列的规则。
class Rule {
  const Rule({
    required this.id,
    required this.userId,
    required this.name,
    required this.sortTime,
    required this.items,
  });

  final String id;
  final String userId;
  final String name;

  /// 秒级 Unix 时间戳，值越小排列越靠前。
  final int sortTime;
  final List<RuleItem> items;
}

/// 文件大小以字节保存，界面按 MB 输入和展示。
class RuleItem {
  const RuleItem({
    required this.id,
    required this.pid,
    required this.fileType,
    required this.fileMinSize,
    required this.fileMaxSize,
    required this.storageId,
    required this.createdAt,
  });

  final String id;
  final String pid;
  final RuleFileType fileType;
  final int fileMinSize;
  final int fileMaxSize;
  final String storageId;
  final DateTime createdAt;
}
