// Simple outbound queue stub used by main during app startup.
// This is intentionally minimal; expand as needed.
class OutboundQueue {
  OutboundQueue();

  void enqueue(Function task) {
    try {
      task();
    } catch (_) {
      // swallow errors in stub
    }
  }
}
