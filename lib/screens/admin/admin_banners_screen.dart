import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/promo_banner.dart';
import '../../providers/app_providers.dart';
import '../../providers/banner_providers.dart';
import '../../services/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/admin_back_guard.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Управление баннерами: список всех, включение/выключение и УДАЛЕНИЕ.
///
/// Экрана не было, а вместе с ним не было и возможности убрать «начальный»
/// баннер: на бэкенде не существовало маршрута DELETE, поэтому оставалось
/// только «деактивировать» - строка вечно висела в списке.
class AdminBannersScreen extends ConsumerStatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  ConsumerState<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends ConsumerState<AdminBannersScreen> {
  List<PromoBanner> _banners = const [];
  bool _loading = true;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(bannerRepositoryProvider).getAllBanners();
      if (!mounted) return;
      setState(() => _banners = list);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(PromoBanner b) async {
    setState(() => _busyId = b.id);
    try {
      final repo = ref.read(bannerRepositoryProvider);
      if (b.active) {
        await repo.deactivateBanner(b.id);
      } else {
        await repo.activateBanner(b.id);
      }
      await _load();
      // Главный экран показывает баннеры из кэша — без обновления «Скрыть»
      // не убирало баннер с главной до перезапуска приложения.
      await ref.read(bannerProvider.notifier).refresh();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(PromoBanner b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить баннер?'),
        content: Text(
          '«${b.title}» будет удалён вместе с картинкой, если она загружена '
          'на сервер. Отменить это нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyId = b.id);
    try {
      await ref.read(bannerRepositoryProvider).deleteBanner(b.id);
      await _load();
      await ref.read(bannerProvider.notifier).refresh();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminBackGuard(
      onEscape: () => context.go('/admin/dashboard'),
      child: AppPage(
        title: 'Баннеры',
        subtitle: 'Все баннеры: показать, скрыть, удалить',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Создать баннер',
                    icon: Icons.add_rounded,
                    onTap: () => context.push('/admin/create-banner'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              GlassContainer(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Не удалось загрузить список: $_error',
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              )
            else if (_banners.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Баннеров нет.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              for (final b in _banners) ...[
                _BannerCard(
                  banner: b,
                  busy: _busyId == b.id,
                  // id едет и в ссылке: если extra потеряется (перезапуск
                  // процесса), экран всё равно откроет правку, а не создание.
                  onEdit: () => context.push(
                    '/admin/create-banner?id=${b.id}',
                    extra: b,
                  ),
                  onToggle: () => _toggle(b),
                  onDelete: () => _delete(b),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final PromoBanner banner;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  banner.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: banner.active
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.glassFill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  banner.active ? 'на показе' : 'скрыт',
                  style: TextStyle(
                    fontSize: 11,
                    color: banner.active
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            banner.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${banner.placement == BannerPlacement.premium ? 'Премиум' : 'Главная'}'
            ' · ${banner.displayDuration} с',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 10),
          // Правка — первая кнопка: чаще всего баннер надо поправить, а не
          // снести. Раньше правки не было вовсе, приходилось удалять и
          // создавать заново (и терять статистику показов).
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Изменить'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onToggle,
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: Text(banner.active ? 'Скрыть' : 'Показать'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Удалить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
