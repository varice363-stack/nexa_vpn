import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../models/promo_banner.dart';
import '../../providers/app_providers.dart';
import '../../providers/banner_providers.dart';
import '../../services/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Экран создания баннера.
///
/// Работает в двух режимах:
/// 1. **Онлайн** — если сервер доступен, создаёт через API
/// 2. **Оффлайн/Демо** — если сервер недоступен, сохраняет баннер локально
///    и сразу показывает его на главном экране для превью
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
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

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

  /// Генерирует уникальный ID для локального баннера.
  String _generateLocalId() {
    final rnd = Random.secure();
    final hex = List.generate(8, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return 'local-$hex';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final displayDuration = int.tryParse(_displayDurationController.text.trim()) ?? 30;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final imageUrl = _imageUrlController.text.trim().isNotEmpty
        ? _imageUrlController.text.trim()
        : null;
    final buttonText = _buttonTextController.text.trim().isNotEmpty
        ? _buttonTextController.text.trim()
        : null;
    final targetUrl = _targetUrlController.text.trim().isNotEmpty
        ? _targetUrlController.text.trim()
        : null;

    // Пробуем создать через API
    try {
      final banner = await ref.read(bannerRepositoryProvider).createBanner(
            title: title,
            description: description,
            imageUrl: imageUrl,
            buttonText: buttonText,
            targetUrl: targetUrl,
            placement: _placement,
            displayDuration: displayDuration,
          );

      // Если выбрана картинка — загружаем её
      if (_selectedImage != null) {
        try {
          await ref.read(bannerRepositoryProvider).uploadBannerImage(
                bannerId: banner.id,
                imageFile: File(_selectedImage!.path),
              );
        } catch (e) {
          // Картинка не загрузилась — не критично
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Баннер «${banner.title}» создан!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      // Сервер недоступен — сохраняем локально (демо-режим)
      if (e.isNetworkError || e.statusCode == null) {
        await _saveLocally(title, description, imageUrl, buttonText, targetUrl, displayDuration);
      } else {
        _showError(_buildErrorMessage(e));
      }
    } catch (e) {
      // Любая другая ошибка — тоже сохраняем локально
      await _saveLocally(title, description, imageUrl, buttonText, targetUrl, displayDuration);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Сохраняет баннер локально для демо-просмотра.
  Future<void> _saveLocally(
    String title,
    String description,
    String? imageUrl,
    String? buttonText,
    String? targetUrl,
    int displayDuration,
  ) async {
    final banner = PromoBanner(
      id: _generateLocalId(),
      title: title,
      description: description,
      imageUrl: imageUrl,
      buttonText: buttonText,
      targetUrl: targetUrl,
      placement: _placement,
      active: true,
      displayDuration: displayDuration,
    );

    // Сохраняем в локальное хранилище
    await ref.read(bannerProvider.notifier).saveLocalBanner(banner);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💾 Баннер «$title» сохранён (демо-режим). Он появится на главном экране.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  String _buildErrorMessage(Object e) {
    if (e is ApiException) {
      if (e.isNetworkError) {
        return 'Нет связи с сервером. Баннер сохранён локально для превью.';
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
      title: 'Создать баннер',
      subtitle: 'Рекламный баннер для партнёрской программы',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Подсказка о демо-режиме
            GlassContainer(
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.all(12),
              color: AppColors.primary.withValues(alpha: 0.05),
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Если сервер недоступен, баннер сохранится локально и покажется на главном экране.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _titleController,
              label: 'Название баннера',
              hint: 'Летняя акция 2026',
              required: true,
              minLength: 2,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Описание',
              hint: 'Скидка 50% на все премиум тарифы!',
              maxLines: 3,
              required: true,
              minLength: 2,
            ),
            const SizedBox(height: 16),
            _buildImagePicker(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _imageUrlController,
              label: 'URL картинки (опционально)',
              hint: 'https://example.com/banner.jpg',
              required: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _buttonTextController,
              label: 'Текст кнопки',
              hint: 'Подробнее',
              required: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _targetUrlController,
              label: 'Ссылка партнёра',
              hint: 'https://partner.example.com/offer',
              required: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _displayDurationController,
              label: 'Время показа (секунды)',
              hint: '30',
              keyboardType: TextInputType.number,
              required: false,
            ),
            const SizedBox(height: 20),
            _buildPlacementSelector(l10n),
            const SizedBox(height: 24),
            GlassButton(
              label: _isSubmitting ? 'Создание...' : 'Создать баннер',
              onTap: _isSubmitting ? () {} : _submit,
            ),
            const SizedBox(height: 16),
            // Кнопка превью
            OutlinedButton.icon(
              onPressed: () => _showPreview(context),
              icon: const Icon(Icons.preview_rounded),
              label: const Text('Предпросмотр'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    final previewBanner = PromoBanner(
      id: 'preview',
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
      displayDuration: int.tryParse(_displayDurationController.text.trim()) ?? 30,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Предпросмотр баннера',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _PreviewBannerCard(banner: previewBanner),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GlassContainer(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Картинка баннера',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedImage != null)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedImage!.path),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedImage = null),
                  child: const Text(
                    'Удалить',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textTertiary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate, size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: 8),
                    Text(
                      'Нажмите чтобы выбрать картинку',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
    int? minLength,
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
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Обязательное поле';
          }
          if (minLength != null && value != null && value.trim().length < minLength) {
            return 'Минимум $minLength символа';
          }
          return null;
        },
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
          const Text(
            'Расположение',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlacementOption(
                  label: '🏠 Главная',
                  selected: _placement == BannerPlacement.home,
                  onTap: () => setState(() => _placement = BannerPlacement.home),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlacementOption(
                  label: '⭐ Премиум',
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

/// Превью баннера в модалке.
class _PreviewBannerCard extends StatelessWidget {
  const _PreviewBannerCard({required this.banner});
  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banner.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.premiumGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  banner.buttonText!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
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
