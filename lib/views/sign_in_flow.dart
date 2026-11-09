import 'package:flutter/material.dart';

import '../models/app_access.dart';

/// The goal a sign-in screen was opened with, if any.
SignInGoal? signInGoalOf(BuildContext context) {
  final arguments = ModalRoute.of(context)?.settings.arguments;
  return arguments is SignInGoal ? arguments : null;
}

/// After signing in or up: carries on with what the visitor was trying to do.
void continueAfterSignIn(BuildContext context, SignInGoal? goal) {
  Navigator.of(
    context,
  ).pushNamedAndRemoveUntil('/dashboard', (_) => false, arguments: goal);
}
