import 'dart:async';

/// Object providing the implicit lock.
/// if [timeout] is not null, it will timeout after the specified duration.
abstract class Lock {
  /// Creates a [Lock] object.
  factory Lock() {
    return BasicLock();
  }

  /// Executes [computation] when lock is available.
  ///
  /// Only one asynchronous block can run while the lock is retained.
  Future<T> synchronized<T>(
    FutureOr<T> Function() computation, {
    Duration? timeout,
  });

  /// returns true if the lock is currently locked.
  bool get locked;

  /// it returns the [locked] status.
  bool get inLock;
}

class BasicLock implements Lock {
  /// The last running block
  Future<dynamic>? last;

  @override
  bool get locked => last != null;

  @override
  Future<T> synchronized<T>(
    FutureOr<T> Function() func, {
    Duration? timeout,
  }) async {
    final prev = last;
    final completer = Completer.sync();
    last = completer.future;
    try {
      // If there is a previous running block, wait for it
      if (prev != null) {
        if (timeout != null) {
          // This could throw a timeout error
          await prev.timeout(timeout);
        } else {
          await prev;
        }
      }

      // Run the function and return the result
      final result = func();
      if (result is Future) {
        return await result;
      } else {
        return result;
      }
    } finally {
      // Cleanup
      // waiting for the previous task to be done in case of timeout
      void complete() {
        // Only mark it unlocked when the last one complete
        if (identical(last, completer.future)) {
          last = null;
        }
        completer.complete();
      }

      // In case of timeout, wait for the previous one to complete too
      // before marking this task as complete

      if (prev != null && timeout != null) {
        // But we still returns immediately
        // ignore: unawaited_futures
        prev.then((_) {
          complete();
        });
      } else {
        complete();
      }
    }
  }

  @override
  String toString() {
    return 'Lock[${identityHashCode(this)}]';
  }

  @override
  bool get inLock => locked;
}
