class Validators {
  static String? validateAmount(String? value, {double max = double.infinity}) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final number = double.tryParse(value.replaceAll(',', ''));
    if (number == null) {
      return 'Invalid amount';
    }
    if (number <= 0) {
      return 'Amount must be greater than zero';
    }
    if (number > max) {
      return 'Amount cannot exceed max limit';
    }
    return null;
  }

  static String? validateRate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Rate is required';
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Invalid rate';
    }
    if (number < 0 || number > 100) {
      return 'Rate must be between 0 and 100';
    }
    return null;
  }

  static String? validateTenure(String? value) {
    if (value == null || value.isEmpty) {
      return 'Tenure is required';
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Invalid tenure';
    }
    if (number <= 0) {
      return 'Tenure must be greater than zero';
    }
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
