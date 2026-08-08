import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

/// Feedback form: rating, category and message.
///
/// BACKEND INTEGRATION (TODO — external infrastructure):
/// POST the payload to the feedback API (or attach to a support ticket
/// system). Until then feedback is stored in the diagnostic log.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int _rating = 5;
  String _category = 'General';
  final TextEditingController _message = TextEditingController();
  bool _submitting = false;

  static const List<String> _categories = [
    'General',
    'Bug report',
    'Feature request',
    'Performance',
  ];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    ref.read(loggerProvider).info(
          'Feedback: rating=$_rating, category=$_category, '
          'message="${_message.text.trim()}"',
          source: 'feedback',
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _message.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you! Your feedback helps us improve.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Feedback',
      subtitle: 'Your opinion shapes Nexa VPN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How do you like Nexa VPN?',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: () => setState(() => _rating = i),
                        child: AnimatedScale(
                          scale: i == _rating ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              i <= _rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 34,
                              color: i <= _rating
                                  ? AppColors.premium
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in _categories)
                      GestureDetector(
                        onTap: () => setState(() => _category = category),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: _category == category
                                ? AppColors.primaryGradient
                                : null,
                            color: _category == category
                                ? null
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _category == category
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _category == category
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _message,
                  maxLines: 5,
                  maxLength: 1000,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Tell us more…',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: Color(0x0AFFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: Color(0x1FFFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: Color(0x1FFFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: 'Submit feedback',
            icon: Icons.send_rounded,
            loading: _submitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
