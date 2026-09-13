import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vpn_status.dart';
import '../../providers/vpn_providers.dart';
import '../../theme/app_colors.dart';
import 'widgets/protected_card.dart';
import 'widgets/power_button_widget.dart';
import 'widgets/stats_row.dart';
import 'widgets/server_card.dart';
import 'widgets/partner_banner.dart';

/// Главный экран MOROK VPN в стиле референса.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, ref),
            
            const SizedBox(height: 24),
            
            // Карточка "ЗАЩИЩЕНО"
            const ProtectedCard(),
            
            const SizedBox(height: 24),
            
            // Кнопка питания
            const PowerButtonWidget(),
            
            const SizedBox(height: 24),
            
            // Статистика
            const StatsRow(),
            
            const SizedBox(height: 16),
            
            // Карточка сервера
            const ServerCard(),
            
            const SizedBox(height: 16),
            
            // Баннер партнёрки
            const PartnerBanner(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Логотип M
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'MOROK VPN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Аватар пользователя
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white54,
        currentIndex: 0,
        onTap: (index) {
          // Навигация
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.public),
            label: 'Серверы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
