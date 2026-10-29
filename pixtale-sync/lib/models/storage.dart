// 远端存储选项及其本地缓存记录。

/// 可作为任务目标的存储。
class Storage {
  /// 创建存储记录。
  const Storage({required this.id, required this.name, required this.type});

  /// 解析服务端存储选项。
  factory Storage.fromJson(Map<String, dynamic> json) => Storage(
    id: json['storageId'] as String,
    name: json['name'] as String,
    type: json['type'] as int,
  );

  final String id;
  final String name;
  final int type;
}
