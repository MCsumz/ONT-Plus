import 'package:flutter/material.dart';

class MainAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData iconData;

  /// Shown in place of [iconData], e.g. the profile's own picture.
  final Widget? leading;

  const MainAppbar({
    super.key,
    required this.title,
    required this.iconData,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading == null
          ? Icon(iconData)
          : Padding(
              padding: const EdgeInsets.all(10),
              child: leading,
            ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
