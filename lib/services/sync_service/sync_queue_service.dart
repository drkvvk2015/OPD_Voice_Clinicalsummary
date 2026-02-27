import '../../data/models/encounter.dart';

class SyncQueueService {
  final List<Encounter> _queue = [];

  List<Encounter> get pending => List<Encounter>.unmodifiable(_queue);

  Future<void> enqueue(Encounter encounter) async {
    _queue.add(encounter);
  }

  Future<int> flush() async {
    final count = _queue.length;
    _queue.clear();
    return count;
  }
}
