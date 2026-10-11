import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/app_form_error.dart';
import '../components/app_primary_button.dart';
import '../components/app_text_field.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_theme.dart';
import '../ui/form_validators.dart';
import '../viewmodels/auth_viewmodel.dart';

Future<void> showEditNameSheet(BuildContext context) => showAppSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _EditNameForm(),
);

Future<void> showChangePasswordSheet(BuildContext context) => showAppSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _ChangePasswordForm(),
);

/// Asks for the password before deleting the account for good. Resolves to
/// true once the account is gone.
Future<bool> showDeleteAccountSheet(BuildContext context) async {
  final deleted = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Swiping ignores PopScope; the form blocks other dismissals while the
    // deletion runs so its result always comes back.
    enableDrag: false,
    builder: (_) => const _DeleteAccountForm(),
  );
  return deleted ?? false;
}

/// Title, fields and save button laid out for a keyboard-aware sheet.
class _SheetForm extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SheetForm({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    // showModalBottomSheet doesn't follow the keyboard; the iOS sheet does.
    final keyboard = isCupertino(context)
        ? 0.0
        : MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _EditNameForm extends StatefulWidget {
  const _EditNameForm();

  @override
  State<_EditNameForm> createState() => _EditNameFormState();
}

class _EditNameFormState extends State<_EditNameForm> {
  late final _controller = TextEditingController(
    text: context.read<AuthViewModel>().currentUser?.name ?? '',
  );
  String? _error;
  String? _formError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = validateName(_controller.text);
    setState(() {
      _error = error;
      _formError = null;
    });
    if (error != null) return;
    final failure = await context.read<AuthViewModel>().updateName(
      _controller.text,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _formError = failure);
      return;
    }
    Navigator.pop(context);
    showAppToast(context, 'Name updated');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthViewModel, bool>((a) => a.isLoading);
    return _SheetForm(
      title: 'Edit name',
      children: [
        AppTextField(
          controller: _controller,
          label: 'Name',
          hint: 'Juan Dela Cruz',
          icon: Icons.person_outline,
          errorText: _error,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 24),
        AppFormError(message: _formError),
        AppPrimaryButton(
          label: 'Save',
          isLoading: isLoading,
          onPressed: isLoading ? null : _save,
        ),
      ],
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  String? _formError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _currentError = validateRequired(_current.text, 'your current password');
      _nextError = validateNewPassword(_next.text);
      if (_nextError == null && _next.text == _current.text) {
        _nextError = 'Choose a password different from your current one';
      }
      _confirmError = _confirm.text == _next.text
          ? null
          : "Passwords don't match";
      _formError = null;
    });
    return _currentError == null && _nextError == null && _confirmError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final failure = await context.read<AuthViewModel>().changePassword(
      _current.text,
      _next.text,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _formError = failure);
      return;
    }
    Navigator.pop(context);
    showAppToast(context, 'Password changed');
  }

  void _toggle() => setState(() => _obscure = !_obscure);

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthViewModel, bool>((a) => a.isLoading);
    return _SheetForm(
      title: 'Change password',
      children: [
        AppTextField(
          controller: _current,
          label: 'Current password',
          hint: 'Your current password',
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: _obscure,
          onToggleObscure: _toggle,
          errorText: _currentError,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _next,
          label: 'New password',
          hint: 'At least $minPasswordLength characters',
          icon: Icons.lock_reset_outlined,
          isPassword: true,
          obscureText: _obscure,
          onToggleObscure: _toggle,
          errorText: _nextError,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _confirm,
          label: 'Confirm new password',
          hint: 'Type it again',
          icon: Icons.lock_reset_outlined,
          isPassword: true,
          obscureText: _obscure,
          onToggleObscure: _toggle,
          errorText: _confirmError,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        const Text(
          "You'll stay signed in on this phone.",
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        AppFormError(message: _formError),
        AppPrimaryButton(
          label: 'Change password',
          isLoading: isLoading,
          onPressed: isLoading ? null : _save,
        ),
      ],
    );
  }
}

class _DeleteAccountForm extends StatefulWidget {
  const _DeleteAccountForm();

  @override
  State<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<_DeleteAccountForm> {
  final _password = TextEditingController();
  bool _obscure = true;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final error = validateRequired(_password.text, 'your password');
    setState(() {
      _passwordError = error;
      _formError = null;
    });
    if (error != null) return;
    final failure = await context.read<AuthViewModel>().deleteAccount(
      _password.text,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _formError = failure);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthViewModel, bool>((a) => a.isLoading);
    return PopScope(
      canPop: !isLoading,
      child: _SheetForm(
        title: 'Delete account',
        children: [
          const Text(
            'This permanently deletes your account, fill-up log, points, '
            'price reports and profile photo, plus the trips and photos saved '
            "on this phone. It can't be undone.",
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prices you reported stay on the map without your name.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _password,
            label: 'Password',
            hint: 'Enter your password to confirm',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            errorText: _passwordError,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _delete(),
          ),
          const SizedBox(height: 24),
          AppFormError(message: _formError),
          AppPrimaryButton(
            label: 'Delete my account',
            backgroundColor: AppColors.error,
            isLoading: isLoading,
            onPressed: isLoading ? null : _delete,
          ),
        ],
      ),
    );
  }
}
