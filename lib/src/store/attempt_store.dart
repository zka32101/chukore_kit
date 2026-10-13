import '../models/models.dart';

/// 回答履歴の保存先。SQLite（drift）実装は各アプリ側／後続PRでこの契約に合わせる。
abstract class AttemptStore {
  Future<void> add(Attempt attempt);

  /// [from] 以上 [to] 未満（日付単位）。省略時は無制限。
  Future<List<Attempt>> query({DateTime? from, DateTime? to, String? unitId});
}

class InMemoryAttemptStore implements AttemptStore {
  final List<Attempt> _items = [];

  @override
  Future<void> add(Attempt attempt) async => _items.add(attempt);

  @override
  Future<List<Attempt>> query({DateTime? from, DateTime? to, String? unitId}) async {
    final f = from == null ? null : dateOnly(from);
    final t = to == null ? null : dateOnly(to);
    return [
      for (final a in _items)
        if ((unitId == null || a.unitId == unitId) &&
            (f == null || !dateOnly(a.answeredAt).isBefore(f)) &&
            (t == null || dateOnly(a.answeredAt).isBefore(t)))
          a,
    ]..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
  }
}
