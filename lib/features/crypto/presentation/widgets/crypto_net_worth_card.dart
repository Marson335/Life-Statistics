import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crypto_models.dart';
import '../providers/crypto_portfolio_provider.dart';

class CryptoNetWorthCard extends StatelessWidget {
  final PortfolioOverview overview;
  final TimePeriod selectedPeriod;
  final Function(TimePeriod) onPeriodChanged;
  final VoidCallback onRefresh;
  final bool isLoading;
  final bool isLive;

  const CryptoNetWorthCard({
    super.key,
    required this.overview,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onRefresh,
    required this.isLoading,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPnlPositive = overview.totalPnlUsd >= 0;
    final cashRatio = overview.cashRatio;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.surfaceVariant,
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ЗАГАЛЬНИЙ КАПІТАЛ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.greenTask.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.greenTask.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.greenTask,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.greenTask,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
                onPressed: isLoading ? null : onRefresh,
                tooltip: 'Оновити ціни та гаманці',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_formatNumber(overview.totalNetWorthUsd)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPnlPositive ? AppColors.greenTask : AppColors.redTask).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPnlPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isPnlPositive ? AppColors.greenTask : AppColors.redTask,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${isPnlPositive ? '+' : ''}\$${_formatNumber(overview.totalPnlUsd)} (${isPnlPositive ? '+' : ''}${overview.totalPnlPct.toStringAsFixed(2)}%)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isPnlPositive ? AppColors.greenTask : AppColors.redTask,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Загальний PnL',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Періодний селектор
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip(TimePeriod.h24, '24 год'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.d7, '7 днів'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.d30, '30 днів'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.d90, '90 днів'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.y1, '1 рік'),
                const SizedBox(width: 6),
                _buildPeriodChip(TimePeriod.all, 'Всі'),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 28),
          // Cash Ratio Bar
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.blueTask),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ліквідність: ${cashRatio.cashPercentage}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRiskBadgeColor(cashRatio.riskLabel).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cashRatio.riskLabel,
                  style: TextStyle(
                    color: _getRiskBadgeColor(cashRatio.riskLabel),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (cashRatio.cashPercentage * 10).round().clamp(1, 1000),
                    child: Container(color: AppColors.greenTask),
                  ),
                  Expanded(
                    flex: (cashRatio.cryptoPercentage * 10).round().clamp(1, 1000),
                    child: Container(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Кеш: \$${_formatNumber(cashRatio.cashUsd)}',
                style: const TextStyle(color: AppColors.greenTask, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              Text(
                'Крипта: \$${_formatNumber(cashRatio.cryptoUsd)}',
                style: const TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (cashRatio.aiAdvice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              cashRatio.aiAdvice,
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.9), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRiskBadgeColor(String riskLabel) {
    if (riskLabel.contains('НИЗЬКИЙ')) return AppColors.greenTask;
    if (riskLabel.contains('ОПТИМАЛЬНИЙ')) return AppColors.blueTask;
    if (riskLabel.contains('ПІДВИЩЕНИЙ')) return AppColors.warning;
    return AppColors.redTask;
  }

  Widget _buildPeriodChip(TimePeriod period, String label) {
    final isSelected = selectedPeriod == period;
    return InkWell(
      onTap: () => onPeriodChanged(period),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatNumber(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(2)}M';
    }
    return val.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
