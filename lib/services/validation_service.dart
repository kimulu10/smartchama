class ValidationService {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.length > 50) {
      return 'Name must be less than 50 characters';
    }
    return null;
  }

  static String? validateChamaName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Chama name is required';
    }
    if (value.length < 3) {
      return 'Chama name must be at least 3 characters';
    }
    if (value.length > 50) {
      return 'Chama name must be less than 50 characters';
    }
    return null;
  }

  static String? validateInviteCode(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length != 6) {
      return 'Invite code must be 6 characters';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Enter a valid number';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^254\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter valid phone (254xxxxxxxxx)';
    }
    return null;
  }

  static bool isValidEmail(String value) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(value);
  }

  static bool isValidPhone(String value) {
    final phoneRegex = RegExp(r'^254\d{9}$');
    return phoneRegex.hasMatch(value);
  }

  static bool isValidAmount(String value) {
    final amount = double.tryParse(value);
    return amount != null && amount > 0;
  }
}
