import 'package:flutter/material.dart';

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError});
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.originalError});
}

class DatabaseException extends AppException {
  DatabaseException(super.message, {super.code, super.originalError});
}

class ErrorHandler {
  static String handle(dynamic error) {
    if (error is AppException) {
      return error.message;
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network')) {
      return 'Please check your internet connection';
    }
    if (errorString.contains('firebase')) {
      return 'Server error. Please try again later';
    }
    if (errorString.contains('permission')) {
      return 'You do not have permission for this action';
    }
    if (errorString.contains('not found')) {
      return 'The requested item was not found';
    }
    if (errorString.contains('email') && errorString.contains('already')) {
      return 'This email is already registered';
    }
    if (errorString.contains('password') && errorString.contains('wrong')) {
      return 'Incorrect password';
    }
    if (errorString.contains('user') && errorString.contains('not found')) {
      return 'No account found with this email';
    }
    if (errorString.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment';
    }
    if (errorString.contains('weak')) {
      return 'Password is too weak. Use at least 6 characters';
    }

    return 'Something went wrong. Please try again';
  }

  static void showSnackBar(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(handle(error)),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
}

class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result.success(this.data)
      : error = null,
        isSuccess = true;

  Result.failure(this.error)
      : data = null,
        isSuccess = false;

  bool get isFailure => !isSuccess;
}

class AsyncResult<T> {
  final T? data;
  final String? error;
  final bool isLoading;

  AsyncResult.loading()
      : data = null,
        error = null,
        isLoading = true;

  AsyncResult.success(this.data)
      : error = null,
        isLoading = false;

  AsyncResult.failure(this.error)
      : data = null,
        isLoading = false;

  bool get isSuccess => data != null && error == null;
  bool get isFailure => error != null;
}
