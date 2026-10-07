import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/promo_banner.dart';
import '../../../providers/banner_providers.dart';
import '../../../services/api/api_config.dart';

/// Живой баннер на главном экране.
///
/// Раньше этот виджет рисовал зашитый текст «Партнёрская программа» и
/// ничего не читал с сервера: `bannerProvider`, `bannersForPlacementProvider`
/// и `bannerTrackerProvider` были написаны, но не потреблялись НИ ОДНИМ
/// экраном. То есть панель «Баннеры» (создание, активация, счётчики
/// показов/кликов, загрузка картинки) работала вхолостую — пользователь не
/// видел ни одного баннера, а статистика не собиралась.
///
/// Теперь: карусель по `/banners?placement=home`, impression на показ,
/// click на тап, CTA ведёт на `targetUrl` (только http/https — см.
/// PromoBanner.hasExternalTarget), при пустом ответе — прежняя партнёрка.
class HomeBannerStrip extends ConsumerStatefulWidget {
  const HomeBannerStrip({super.key});

  @override
  ConsumerState<HomeBannerStrip> createState() => _HomeBannerStripState();
}

class _HomeBannerStripState extends ConsumerState<HomeBannerStrip> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _trackImpression(String id) {
    // impression идемпотентен на сессию внутри BannerTracker; зовём из
    // post-frame, чтобы не дёргать провайдер во время build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(bannerTrackerProvider).impression(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersForPlacementProvider(BannerPlacement.home));
    if (banners.isEmpty) {
      return const PartnerBanner();
    }
    if (_index >= banners.length) {
      _index = banners.length - 1;
    }
    _trackImpression(banners[_index].id);
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: _BannerCard(banner: banners[i]),
            ),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard({required this.banner});

  final PromoBanner banner;

  Future<void> _tap(BuildContext context, WidgetRef ref) async {
    ref.read(bannerTrackerProvider).click(banner.id);
    if (banner.hasExternalTarget) {
      final uri = Uri.tryParse(banner.targetUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    // Без внешнего адреса — как раньше: показываем Premium.
    context.go('/premium');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = banner.imageUrl;
    final hasImage = image != null && image.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(context, ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    banner.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (banner.buttonText == null ||
                                    banner.buttonText!.isEmpty)
                                ? 'Открыть'
                                : banner.buttonText!,
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF6C63FF),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  ApiConfig.resolveAssetUrl(image),
                  width: 92,
                  height: 128,
                  fit: BoxFit.cover,
                  // Статика отдаётся с того же http-origin, что и API: при
                  // любой ошибке показываем градиент, а не красный квадрат.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const SizedBox(width: 92, height: 128),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Партнёрская программа — статичная подложка, которую показываем, когда на
/// сервере нет ни одного активного баннера.
class PartnerBanner extends StatelessWidget {
  const PartnerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6C63FF),
            Color(0xFF4834D4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: Colors.yellow,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Партнёрская программа',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Приглашай друзей и получай 15% от каждой оплаты',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Пригласить',
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF6C63FF),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
