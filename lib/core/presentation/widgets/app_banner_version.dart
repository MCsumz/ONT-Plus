import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/dynamic_ont_logo.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/core/utils/safe_url_launcher.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AppBannerVersion extends StatelessWidget {
  final String versionNumber;

  const AppBannerVersion({super.key, required this.versionNumber});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 70, child: DynamicOntLogo()),
        Text(
          S.of(context).appTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          S.of(context).appVersionName(versionNumber),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),        const SizedBox(height: 6),
        // ONT+ credit: the author of the additions, and where the app
        // comes from.
        Semantics(
          identifier: 'app-plus-credit',
          link: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => tryLaunchExternalUrl(AppConst.plusAuthorUrl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                '${S.of(context).plusCreditLine(AppConst.plusAuthorName)}'
                ' · ${AppConst.plusAuthorHandle}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
        Text(
          S.of(context).basedOnUpstreamLine,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }
}
