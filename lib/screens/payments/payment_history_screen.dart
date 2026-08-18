import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../models/payment_status.dart';
import '../../models/payment_transaction.dart';
import '../../providers/billing_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glass_container.dart';

/// Payment history — date, plan, amount, status.
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final transactions =
        transactionsAsync.value ?? const <PaymentTransaction>[];

    return AppPage(
      title: 'Payment History',
      subtitle: transactions.isEmpty
          ? 'No payments yet'
          : '${transactions.length} '
              '${transactions.length == 1 ? 'payment' : 'payments'}',
      actions: [
        GlassContainer(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(11),
          child: GestureDetector(
            onTap: () =>
                ref.read(transactionsProvider.notifier).refresh(),
            child: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
      child: transactionsAsync.isLoading && transactions.isEmpty
          ? const _LoadingState()
          : transactions.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No payments yet',
                  message:
                      'Your payment history will appear here after the '
                      'first checkout.',
                )
              : Column(
                  children: [
                    for (final transaction in transactions)
                      _TransactionRow(transaction: transaction),
                  ],
                ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (transaction.uiStatus) {
      PaymentStatus.paid => (AppColors.success, 'PAID'),
      PaymentStatus.failed => (AppColors.danger, 'FAILED'),
      PaymentStatus.pending || PaymentStatus.processing => (
          AppColors.warning,
          'PENDING',
        ),
    };

    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.uiStatus == PaymentStatus.paid
                  ? Icons.check_circle_rounded
                  : transaction.uiStatus == PaymentStatus.failed
                      ? Icons.cancel_rounded
                      : Icons.hourglass_top_rounded,
              size: 19,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.planName ?? 'Subscription',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.createdAt == null
                      ? '—'
                      : Formatters.shortDateTime(transaction.createdAt!),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.currency} ${transaction.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 14),
          Text(
            'Loading payments…',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
