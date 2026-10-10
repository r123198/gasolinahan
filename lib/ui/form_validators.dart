/// Field validators shared by the auth and account forms. Each returns the
/// message to show under the field, or null when the value is valid.
library;

const minPasswordLength = 8;
const maxNameLength = 50;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Enter your email';
  if (!_emailPattern.hasMatch(email)) {
    return 'Enter a valid email, like juan@mail.com';
  }
  return null;
}

String? validateNewPassword(String value) {
  if (value.length < minPasswordLength) {
    return 'Use at least $minPasswordLength characters';
  }
  return null;
}

String? validateRequired(String value, String what) =>
    value.trim().isEmpty ? 'Enter $what' : null;

String? validateName(String value) {
  final name = value.trim();
  if (name.isEmpty) return 'Enter your name';
  if (name.length > maxNameLength) {
    return 'Keep it under $maxNameLength characters';
  }
  return null;
}
