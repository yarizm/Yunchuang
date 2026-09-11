import 'dart:async';

abstract class AIProvider {
  /// Provider display name
  String get name;

  /// Provider type identifier
  String get type;

  /// 普通对话（阻塞式）
  Future<String> chat(String message, {List<ChatMessage>? history});

  /// 流式对话（SSE）
  Stream<String> chatStream(String message, {List<ChatMessage>? history});

  /// 单次补全（笔记润色/摘要/测验）
  Future<String> complete(String prompt);

  /// Test connection
  Future<bool> testConnection();
}

/// Implemented by providers that own an HTTP client, so callers can release
/// its connection pool once the provider is replaced or discarded. Providers
/// built around an injected client do not own it and must not implement this.
abstract interface class DisposableAIProvider {
  /// Releases owned network resources. In-flight requests are allowed to
  /// finish. Safe to call more than once.
  void dispose();
}

abstract interface class CancellableAIProvider {
  Future<String> chatCancellable(
    String message, {
    List<ChatMessage>? history,
    required AIRequestCancellation cancellation,
  });

  Stream<String> chatStreamCancellable(
    String message, {
    List<ChatMessage>? history,
    required AIRequestCancellation cancellation,
  });

  Future<String> completeCancellable(
    String prompt, {
    required AIRequestCancellation cancellation,
  });
}

class AIRequestCancellation {
  final _cancelled = Completer<void>();
  final _listeners = <void Function()>{};
  String _reason = '用户已停止生成。';

  bool get isCancelled => _cancelled.isCompleted;
  String get reason => _reason;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel([String reason = '用户已停止生成。']) {
    if (isCancelled) return;
    _reason = reason;
    _cancelled.complete();
    final listeners = List<void Function()>.from(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  void throwIfCancelled() {
    if (isCancelled) throw AIRequestCancelledException(_reason);
  }

  void Function() addCancelListener(void Function() listener) {
    if (isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  Future<T> bindFuture<T>(Future<T> source) {
    throwIfCancelled();
    return Future.any<T>([
      source,
      whenCancelled.then<T>(
        (_) => throw AIRequestCancelledException(_reason),
      ),
    ]);
  }

  Stream<T> bindStream<T>(Stream<T> source) {
    throwIfCancelled();
    late final StreamController<T> controller;
    StreamSubscription<T>? sourceSubscription;
    void Function()? removeCancelListener;
    var finished = false;

    Future<void> cancelSource() async {
      final subscription = sourceSubscription;
      sourceSubscription = null;
      await subscription?.cancel();
    }

    void closeWithError(Object error, StackTrace stackTrace) {
      if (finished) return;
      finished = true;
      removeCancelListener?.call();
      controller.addError(error, stackTrace);
      unawaited(cancelSource());
      unawaited(controller.close());
    }

    controller = StreamController<T>(
      onListen: () {
        sourceSubscription = source.listen(
          (value) {
            if (!finished) controller.add(value);
          },
          onError: closeWithError,
          onDone: () {
            if (finished) return;
            finished = true;
            removeCancelListener?.call();
            unawaited(controller.close());
          },
        );
        removeCancelListener = addCancelListener(() {
          closeWithError(
            AIRequestCancelledException(_reason),
            StackTrace.current,
          );
        });
      },
      onCancel: () async {
        finished = true;
        removeCancelListener?.call();
        await cancelSource();
      },
    );
    return controller.stream;
  }
}

class AIRequestCancelledException implements Exception {
  final String message;

  const AIRequestCancelledException([this.message = '用户已停止生成。']);

  @override
  String toString() => message;
}

extension AIProviderCancellationCalls on AIProvider {
  Future<String> chatWithCancellation(
    String message, {
    List<ChatMessage>? history,
    AIRequestCancellation? cancellation,
  }) {
    if (cancellation == null) return chat(message, history: history);
    cancellation.throwIfCancelled();
    final request = this is CancellableAIProvider
        ? (this as CancellableAIProvider).chatCancellable(
            message,
            history: history,
            cancellation: cancellation,
          )
        : chat(message, history: history);
    return cancellation.bindFuture(request);
  }

  Stream<String> chatStreamWithCancellation(
    String message, {
    List<ChatMessage>? history,
    AIRequestCancellation? cancellation,
  }) {
    if (cancellation == null) return chatStream(message, history: history);
    cancellation.throwIfCancelled();
    final request = this is CancellableAIProvider
        ? (this as CancellableAIProvider).chatStreamCancellable(
            message,
            history: history,
            cancellation: cancellation,
          )
        : chatStream(message, history: history);
    return cancellation.bindStream(request);
  }

  Future<String> completeWithCancellation(
    String prompt, {
    AIRequestCancellation? cancellation,
  }) {
    if (cancellation == null) return complete(prompt);
    cancellation.throwIfCancelled();
    final request = this is CancellableAIProvider
        ? (this as CancellableAIProvider).completeCancellable(
            prompt,
            cancellation: cancellation,
          )
        : complete(prompt);
    return cancellation.bindFuture(request);
  }
}

class ChatMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, String> toMap() => {'role': role, 'content': content};
}
