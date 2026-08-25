import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/promo_banner.dart';
import '../../providers/banner_providers.dart';
import '../../theme/app_colors.dart';
import '../common/glass_container.dart';

/// Renders one promotional banner and reports its ad metrics.
///
/// An impression is recorded once per session when the card is first built;
/// a click is recorded on every CTA tap. Both are fire-and-forget — the ad
/// pipeline never blocks or breaks the UI.
class PromoBannerCard extends ConsumerStatefulWidget {
  const PromoBannerCard({super.key, required this.banner});

  final PromoBanner banner;

  @override
  ConsumerState<PromoBannerCard> createState() => _PromoBannerCardState();
}

class _PromoBannerCardState extends ConsumerState<PromoBannerCard> {
  @override
  void initState() {
    super.initState();
    // Post-frame: the widget is on screen and tracking must not run during
    // build (it touches providers).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(bannerTrackerProvider).impression(widget.banner.id);
    });
  }

  Future<void> _onTap() async {
    final banner = widget.banner;
    ref.read(bannerTrackerProvider).click(banner.id);

    if (banner.hasExternalTarget) {
      try {
        final uri = Uri.parse(banner.targetUrl!);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {
        // No browser, blocked intent, platform error — fall through in-app.
      }
      if (!mounted) return;
    }
    if (!mounted) return;
    context.push('/premium');
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;

    return GlassContainer(
      borderRadius: BorderRadius.circular(24),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: AspectRatio(
                // 16:9 — a real ad creative, not a 46 px thumbnail.
                aspectRatio: 16 / 9,
                child: Image.network(
                  banner.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ImageFallback(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _ImageFallback();
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (banner.imageUrl == null) ...[
                      const _PremiumIcon(),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            banner.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (banner.buttonText != null) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.premiumGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.premium.withValues(alpha: 0.25),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            banner.buttonText!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          if (banner.hasExternalTarget) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 15,
                              color: Colors.black87,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.04),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 30,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _PremiumIcon extends StatelessWidget {
  const _PremiumIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.premiumGradient,
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        size: 22,
        color: Colors.black87,
      ),
    );
  }
}
