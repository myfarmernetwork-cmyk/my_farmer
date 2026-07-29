import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/screen_guide_step.dart';
import '../features/seller/company_catalog_screen.dart';
import '../screens/company_catalog_pdf_screen.dart';
import '../services/company_catalog_csv_parser.dart';
import '../services/company_catalog_prefs.dart';
import '../services/company_catalog_template_service.dart';
import 'farmer_screen_guide.dart';

/// Koraci koje firma treba proći nakon instalacije (bez ERP integracije).
class CompanyCatalogHowItWorks extends StatelessWidget {
  const CompanyCatalogHowItWorks({super.key, this.guideKey});

  final GlobalKey? guideKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: guideKey,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade300, width: 1.5),
        ),
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'company_catalog_how_title'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'company_catalog_how_body'.tr(),
                style: TextStyle(
                  color: Colors.green.shade900,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _NotNeededRow(text: 'company_catalog_how_not_code'.tr()),
              _NotNeededRow(text: 'company_catalog_how_not_api'.tr()),
              _NotNeededRow(text: 'company_catalog_how_not_erp_login'.tr()),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'company_catalog_how_need_title'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'company_catalog_how_need_body'.tr(),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FlowRow(
                steps: [
                  'company_catalog_how_flow_erp'.tr(),
                  'company_catalog_how_flow_csv'.tr(),
                  'company_catalog_how_flow_app'.tr(),
                  'company_catalog_how_flow_shop'.tr(),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => CompanyCatalogPdfScreen.open(context),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('company_catalog_pdf_btn'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple.shade800,
                    side: BorderSide(color: Colors.deepPurple.shade200),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotNeededRow extends StatelessWidget {
  const _NotNeededRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close, size: 18, color: Colors.red.shade400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade800, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Text(
              steps[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple.shade900,
              ),
            ),
          ),
          if (i < steps.length - 1)
            Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade500),
        ],
      ],
    );
  }
}

class CompanySetupChecklist extends StatelessWidget {
  const CompanySetupChecklist({
    super.key,
    required this.hasCatalogItems,
    required this.hasPublishedItems,
    this.onOpenGuide,
  });

  final bool hasCatalogItems;
  final bool hasPublishedItems;
  final VoidCallback? onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rtl, color: Colors.deepPurple.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'company_catalog_setup_title'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                ),
                if (onOpenGuide != null)
                  TextButton(
                    onPressed: onOpenGuide,
                    child: Text('company_catalog_open_guide'.tr()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'company_catalog_setup_subtitle'.tr(),
              style: TextStyle(color: Colors.deepPurple.shade800, height: 1.35),
            ),
            const SizedBox(height: 12),
            _StepRow(
              done: true,
              title: 'company_catalog_setup_step1'.tr(),
              subtitle: 'company_catalog_setup_step1_hint'.tr(),
            ),
            _StepRow(
              done: hasCatalogItems,
              title: 'company_catalog_setup_step2'.tr(),
              subtitle: 'company_catalog_setup_step2_hint'.tr(),
            ),
            _StepRow(
              done: hasCatalogItems,
              title: 'company_catalog_setup_step3'.tr(),
              subtitle: 'company_catalog_setup_step3_hint'.tr(),
            ),
            _StepRow(
              done: hasPublishedItems,
              title: 'company_catalog_setup_step4'.tr(),
              subtitle: 'company_catalog_setup_step4_hint'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.title,
    required this.subtitle,
  });

  final bool done;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: done ? Colors.green.shade700 : Colors.grey.shade500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: done ? Colors.green.shade900 : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyCatalogSampleCsv extends StatelessWidget {
  const CompanyCatalogSampleCsv({super.key, required this.guideKey});

  final GlobalKey guideKey;

  static const sample = CompanyCatalogCsvParser.templateCsvSemicolon;

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      await CompanyCatalogTemplateService.downloadTemplate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('company_catalog_template_downloaded'.tr()),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('company_catalog_template_download_failed'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: guideKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'company_catalog_sample_csv_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'company_catalog_sample_csv_body'.tr(),
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  sample,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _downloadTemplate(context),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text('company_catalog_template_download'.tr()),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: sample));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('company_catalog_sample_copied'.tr()),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text('company_catalog_sample_copy'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompanyCatalogWelcomeDialog extends StatelessWidget {
  const CompanyCatalogWelcomeDialog({super.key});

  static Future<bool?> showIfNeeded(BuildContext context) async {
    if (await CompanyCatalogPrefs.hasSeenWelcome()) return null;
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CompanyCatalogWelcomeDialog(),
    );
  }

  Future<void> _start(BuildContext context) async {
    await CompanyCatalogPrefs.markWelcomeSeen();
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.storefront, color: Colors.deepPurple.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text('company_catalog_welcome_title'.tr())),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'company_catalog_welcome_no_code'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'company_catalog_welcome_body'.tr(),
              style: const TextStyle(height: 1.45),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await CompanyCatalogPrefs.markWelcomeSeen();
            if (context.mounted) Navigator.of(context).pop(false);
          },
          child: Text('company_catalog_welcome_skip'.tr()),
        ),
        TextButton.icon(
          onPressed: () {
            CompanyCatalogPdfScreen.open(context);
          },
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
          label: Text('company_catalog_pdf_btn'.tr()),
        ),
        FilledButton(
          onPressed: () => _start(context),
          child: Text('company_catalog_welcome_start'.tr()),
        ),
      ],
    );
  }
}

class CompanyCatalogPdfProfileTile extends StatelessWidget {
  const CompanyCatalogPdfProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade50,
          child: Icon(Icons.picture_as_pdf_outlined, color: Colors.red.shade700),
        ),
        title: Text(
          'company_catalog_pdf_always_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('company_catalog_pdf_profile_subtitle'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => CompanyCatalogPdfScreen.open(context),
      ),
    );
  }
}

class CompanyCatalogQuickHelpBanner extends StatelessWidget {
  const CompanyCatalogQuickHelpBanner({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final localeTag = context.locale.toLanguageTag();

    return Padding(
      key: ValueKey('company_catalog_pdf_banner_$localeTag'),
      padding: padding ?? const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => CompanyCatalogPdfScreen.open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.deepPurple.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'company_catalog_pdf_always_title'.tr(context: context),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                      Text(
                        'company_catalog_pdf_always_hint'.tr(context: context),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple.shade800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => CompanyCatalogPdfScreen.open(context),
                  child: Text('company_catalog_pdf_open'.tr(context: context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompanyCatalogProfileTile extends StatefulWidget {
  const CompanyCatalogProfileTile({super.key});

  @override
  State<CompanyCatalogProfileTile> createState() =>
      _CompanyCatalogProfileTileState();
}

class _CompanyCatalogProfileTileState extends State<CompanyCatalogProfileTile> {
  bool _showStartBadge = false;

  @override
  void initState() {
    super.initState();
    _loadBadge();
  }

  Future<void> _loadBadge() async {
    final seen = await CompanyCatalogPrefs.hasSeenWelcome();
    if (mounted) setState(() => _showStartBadge = !seen);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _showStartBadge ? Colors.teal.shade400 : Colors.teal.shade200,
          width: _showStartBadge ? 2 : 1,
        ),
      ),
      color: _showStartBadge ? Colors.teal.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: Icon(
            Icons.inventory_2_outlined,
            color: Colors.teal.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'company_catalog_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (_showStartBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'company_catalog_start_here'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text('company_catalog_profile_subtitle'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CompanyCatalogScreen(),
            ),
          );
          _loadBadge();
        },
      ),
    );
  }
}

class CompanyCatalogPdfGuideButton extends StatelessWidget {
  const CompanyCatalogPdfGuideButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white.withValues(alpha: 0.95);
    return IconButton(
      tooltip: 'company_catalog_pdf_btn'.tr(),
      onPressed: () => CompanyCatalogPdfScreen.open(context),
      icon: Icon(Icons.picture_as_pdf_outlined, color: color),
    );
  }
}

class CompanyCatalogGuideButton extends StatelessWidget {
  const CompanyCatalogGuideButton({
    super.key,
    required this.guideSteps,
  });

  final List<ScreenGuideStep> guideSteps;

  @override
  Widget build(BuildContext context) {
    if (guideSteps.isEmpty) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'company_catalog_open_guide'.tr(),
      onPressed: () {
        FarmerScreenGuide.show(
          context,
          guideSteps,
          ignoreRoleGate: true,
        );
      },
      icon: Icon(Icons.help_outline, color: Colors.white.withValues(alpha: 0.95)),
    );
  }
}

Future<void> showCompanyCatalogSpotlightIfNeeded(
  BuildContext context,
  List<ScreenGuideStep> steps,
) async {
  if (steps.isEmpty) return;
  if (await CompanyCatalogPrefs.hasSeenSpotlight()) return;
  await CompanyCatalogPrefs.markSpotlightSeen();
  if (!context.mounted) return;
  await FarmerScreenGuide.show(context, steps, ignoreRoleGate: true);
}

List<ScreenGuideStep> companyCatalogGuideSteps({
  required GlobalKey howItWorksKey,
  required GlobalKey setupKey,
  required GlobalKey sampleKey,
  required GlobalKey importKey,
  required GlobalKey listKey,
}) {
  return [
    ScreenGuideStep(
      targetKey: howItWorksKey,
      titleKey: 'guide_company_catalog_how_title',
      bodyKey: 'guide_company_catalog_how_body',
    ),
    ScreenGuideStep(
      targetKey: setupKey,
      titleKey: 'guide_company_catalog_setup_title',
      bodyKey: 'guide_company_catalog_setup_body',
    ),
    ScreenGuideStep(
      targetKey: sampleKey,
      titleKey: 'guide_company_catalog_sample_title',
      bodyKey: 'guide_company_catalog_sample_body',
    ),
    ScreenGuideStep(
      targetKey: importKey,
      titleKey: 'guide_company_catalog_import_title',
      bodyKey: 'guide_company_catalog_import_body',
    ),
    ScreenGuideStep(
      targetKey: listKey,
      titleKey: 'guide_company_catalog_list_title',
      bodyKey: 'guide_company_catalog_list_body',
    ),
    ScreenGuideStep(
      targetKey: null,
      titleKey: 'guide_company_catalog_orders_title',
      bodyKey: 'guide_company_catalog_orders_body',
    ),
  ];
}
