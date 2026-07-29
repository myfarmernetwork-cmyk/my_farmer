import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/screen_guide_step.dart';
import '../utils/farmer_guide_access.dart';
import 'farmer_help_widgets.dart';
import 'farmer_screen_guide.dart';

class FarmerHelperIconButton extends ConsumerWidget {
  const FarmerHelperIconButton({
    super.key,
    required this.guideSteps,
    this.enabled = true,
  });

  final List<ScreenGuideStep> guideSteps;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globallyEnabled = FarmerGuideAccess.isGuideEnabledForRef(ref);
    final showButton =
        enabled && globallyEnabled && guideSteps.isNotEmpty;

    if (!showButton) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: IconButton(
        tooltip: 'farmer_helper_tooltip'.tr(),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          if (!enabled || !globallyEnabled || guideSteps.isEmpty) return;
          FarmerScreenGuide.show(context, guideSteps);
        },
        icon: const FarmerHelperIcon(),
      ),
    );
  }
}
