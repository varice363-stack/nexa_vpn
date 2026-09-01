import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/promo_banner.dart';
import '../../providers/app_providers.dart';
import '../../services/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Admin screen for creating a new promotional banner.
class AdminCreateBannerScreen extends ConsumerStatefulWidget {
  const AdminCreateBannerScreen({super.key});

  @override
  ConsumerState<AdminCreateBannerScreen> createState() =>
      _AdminCreateBannerScreenState();
}

class _AdminCreateBannerScreenState
    extends ConsumerState<AdminCreateBannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _buttonTextController = TextEditingController();
  final _targetUrlController = TextEditingController();
  final _displayDurationController = TextEditingController(text: '30');

  BannerPlacement _placement = BannerPlacement.home;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _buttonTextController.dispose();
    _targetUrlController.dispose();
    _displayDurationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final banner = await ref.read(bannerRepositoryProvider).createBanner(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            imageUrl: _imageUrlController.text.trim().isNotEmpty
                ? _imageUrlController.text.trim()
                : null,
            buttonText: _buttonTextController.text.trim().isNotEmpty
                ? _buttonTextController.text.trim()
                : null,
            targetUrl: _targetUrlController.text.trim().isNotEmpty
                ? _targetUrlController.text.trim()
                : null,
            placement: _placement,
            displayDuration: int.tryParse(_displayDurationController.text) ?? 30,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Banner "${banner.title}" created')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      final message = _buildErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Превращает исключение в понятное пользователю сообщение.
  String _buildErrorMessage(Object e) {
    if (e is ApiException) {
      if (e.isNetworkError) {
        return 'Нет связи с сервером. '
            'Убедитесь что:\n'
            '• VPN на телефоне ВЫКЛЮЧЕН\n'
            '• Backend запущен на ПК\n'
            '• Телефон и ПК в одной Wi-Fi сети';
      }
      switch (e.statusCode) {
        case 401:
          return 'Сессия истекла. Выйдите и войдите снова.';
        case 403:
          return 'Недостаточно прав. Нужна роль ADMIN.';
        case 400:
          return 'Неверные данные. Проверьте заполнение полей.';
        case 409:
          return 'Такой баннер уже существует.';
        default:
          return 'Ошибка сервера (${e.statusCode}): ${e.message}';
      }
    }
    return 'Неизвестная ошибка: $e';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppPage(
      title: l10n.adminCreateBanner,
      subtitle: l10n.adminCreateBannerSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _titleController,
              label: l10n.adminBannerTitle,
              hint: 'Summer Sale 2026',
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: l10n.adminBannerDescription,
              hint: 'Get 50% off on all premium plans!',
              maxLines: 3,
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _imageUrlController,
              label: l10n.adminBannerImageUrl,
              hint: 'https://example.com/banner.jpg',
              required: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _buttonTextController,
              label: l10n.adminBannerButtonText,
              hint: 'Learn More',
              required: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _targetUrlController,
              label: l10n.adminBannerTargetUrl,
              hint: 'https://example.com/offer',
              required: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _displayDurationController,
              label: l10n.adminBannerDisplayDuration,
              hint: '30',
              keyboardType: TextInputType.number,
              required: false,
            ),
            const SizedBox(height: 20),
            _buildPlacementSelector(l10n),
            const SizedBox(height: 24),
            GlassButton(
              label: _isSubmitting ? l10n.commonLoading : l10n.adminCreateBanner,
              onTap: _isSubmitting ? () {} : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool required,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textTertiary),
        ),
        style: const TextStyle(color: AppColors.textPrimary),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildPlacementSelector(AppLocalizations l10n) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminBannerPlacement,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlacementOption(
                  label: 'Home',
                  selected: _placement == BannerPlacement.home,
                  onTap: () => setState(() => _placement = BannerPlacement.home),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlacementOption(
                  label: 'Premium',
                  selected: _placement == BannerPlacement.premium,
                  onTap: () =>
                      setState(() => _placement = BannerPlacement.premium),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlacementOption extends StatelessWidget {
  const _PlacementOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.textTertiary.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
