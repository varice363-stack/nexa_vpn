import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vpn_status.dart';
import '../../providers/vpn_providers.dart';
import 'widgets/protected_card.dart';
import 'widgets/power_button_widget.dart';
import 'widgets/stats_row.dart';
import 'widgets/server_card.dart';
import 'widgets/partner_banner.dart';

/// Главный экран MOROK VPN с улучшенным визуалом.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    final isConnected = status == VpnStatus.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF05070F),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header с градиентом
              _buildHeader(context, ref),
              
              const SizedBox(height: 20),
              
              // Карточка "ЗАЩИЩЕНО"
              const ProtectedCard(),
              
              const SizedBox(height: 20),
              
              // Кнопка питания
              const PowerButtonWidget(),
              
              const SizedBox(height: 20),
              
              // Статистика
              const StatsRow(),
              
              const SizedBox(height: 16),
              
              // Карточка сервера (только при подключении)
              if (isConnected) ...[
                const ServerCard(),
                const SizedBox(height: 16),
              ],
              
              // Баннер партнёрки
              const PartnerBanner(),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStateProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF05070F),
            const Color(0xFF0A0F1E),
          ],
        ),
      ),
      child: Row(
        children: [
          // Логотип M с градиентом
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
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
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Статус подключения
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: status == VpnStatus.connected 
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: status == VpnStatus.connected 
                    ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == VpnStatus.connected 
                        ? const Color(0xFF22C55E)
                        : Colors.white.withValues(alpha: 0.5),
                    boxShadow: [
                      if (status == VpnStatus.connected)
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status == VpnStatus.connected ? 'ЗАЩИЩЕНО' : 'ОТКЛЮЧЕНО',
                  style: TextStyle(
                    color: status == VpnStatus.connected 
                        ? const Color(0xFF22C55E)
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF2DD4BF),
        unselectedItemColor: Colors.white.withValues(alpha: 0.4),
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          // Навигация
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.public_rounded),
            label: 'Серверы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
