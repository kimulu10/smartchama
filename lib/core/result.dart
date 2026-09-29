sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get value {
    if (this is Success<T>) return (this as Success<T>).value;
    throw StateError('Cannot get value from Failure');
  }

  String get error {
    if (this is Failure<T>) return (this as Failure<T>).error;
    throw StateError('Cannot get error from Success');
  }

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(String error) onFailure,
  }) {
    if (this is Success<T>) return onSuccess((this as Success<T>).value);
    return onFailure((this as Failure<T>).error);
  }
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final String error;
  const Failure(this.error);
}