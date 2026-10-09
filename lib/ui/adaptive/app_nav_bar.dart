import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'app_platform.dart';

const _titleColor = Color(0xFF0F172A);
final _titleStyle = TextStyle(
  fontFamily: AppTheme.fontFamily,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: _titleColor,
);

/// App bar for [Scaffold.appBar]: [CupertinoNavigationBar] on iOS (with the
/// native back chevron), [AppBar] elsewhere. Both are transparent to match
/// the app theme.
class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget> actions;

  const AppNavBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
  });

  @override
  Size get preferredSize => Size.fromHeight(
    isCupertinoPlatform ? kMinInteractiveDimensionCupertino : kToolbarHeight,
  );

  @override
  Widget build(BuildContext context) {
    final titleWidget = title == null ? null : Text(title!, style: _titleStyle);

    if (isCupertino(context)) {
      return CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        automaticBackgroundVisibility: false,
        leading: leading,
        automaticallyImplyLeading: leading == null,
        middle: titleWidget,
        trailing: actions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
    }

    return AppBar(
      title: titleWidget == null ? null : Text(title!),
      leading: leading,
      actions: actions,
    );
  }
}
