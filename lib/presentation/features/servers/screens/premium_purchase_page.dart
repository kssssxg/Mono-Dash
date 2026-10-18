import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/frosted_scaffold.dart';

const _privacyPolicyUrl =
    'https://github.com/bin64/Mono-Dash/blob/main/PRIVACY.md';
const _termsOfUseUrl = 'https://github.com/bin64/Mono-Dash/blob/main/TERMS.md';

/// Former paywall page. In-app purchases have been removed, so this page now
/// simply shows that every feature is unlocked.
class PremiumPurchasePage extends StatelessWidget {
  const PremiumPurchasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FrostedScaffold(
      title: 'Mono Dash',
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: FrostedScaffold.contentTopPadding(context)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 32),
                _buildHeroSection(context, l10n),
                const SizedBox(height: 48),
                _buildUnlockedStatus(context, l10n),
                const SizedBox(height: 64),
                _buildLegalSection(context, l10n),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        const Icon(
          CupertinoIcons.infinite,
          size: 72,
          color: CupertinoColors.activeBlue,
        ),
        const SizedBox(height: 16),
        Text(
          'Mono Dash',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.label(context),
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.premium_heroSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockedStatus(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.checkmark_seal_fill,
            color: CupertinoColors.systemGreen,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.premium_unlockedTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                Text(
                  l10n.premium_unlockedDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalLink(
              label: l10n.premium_terms,
              onTap: () => _openLegalLink(context, _termsOfUseUrl),
            ),
            Container(
              width: 1,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.separator(context),
            ),
            _LegalLink(
              label: l10n.premium_privacy,
              onTap: () => _openLegalLink(context, _privacyPolicyUrl),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openLegalLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showAppErrorToast(context.l10n.settings_contact_openFailed);
    }
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryLabel(context),
        ),
      ),
    );
  }
}
