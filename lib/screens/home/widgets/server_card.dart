import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_source_providers.dart';
import '../../../providers/server_providers.dart';

/// Карточка текущего сервера с флагом страны.
class ServerCard extends ConsumerWidget {
  const ServerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSource = ref.watch(activeSourceProvider);
    final selectedServer = ref.watch(selectedServerProvider);
    
    final server = selectedServer;
    final sourceLabel = activeSource?.label ?? 'Неизвестный сервер';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A0F1E),
            const Color(0xFF151A28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Флаг страны
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                server?.flagEmoji ?? '🌍',
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Информация о сервере
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server?.displayName ?? sourceLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ping: ${server?.ping ?? '—'} мс',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Метка "Активно"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              'Активно',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
