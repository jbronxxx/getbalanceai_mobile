import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';

/// Данные одного сегмента кольцевой диаграммы расходов.
class ExpenseSegmentData {
  final Category category;
  final double amount;
  final Color color;

  const ExpenseSegmentData({
    required this.category,
    required this.amount,
    required this.color,
  });
}

/// Большая бирюзовая карточка соотношения расходов за месяц к доходу (балансу)
/// в стиле полированного жидкого стекла (Polished Turquoise Liquid Glass) с Donut-диаграммой.
class BudgetExpenseRatioCard extends StatefulWidget {
  final double totalIncome;
  final double totalExpense;
  final Map<Category, double> categoryExpenses;

  const BudgetExpenseRatioCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.categoryExpenses,
  });

  /// Цветовая палитра категорий Material 3 с высокой контрастностью
  /// на бирюзовом стеклянном фоне карточки.
  static Color getCategorySegmentColor(Category category) {
    switch (category) {
      case Category.food:
        return const Color(0xFFFB923C); // Coral Orange
      case Category.transport:
        return const Color(0xFF60A5FA); // Sky Blue
      case Category.entertainment:
        return const Color(0xFFC084FC); // Soft Purple
      case Category.health:
        return const Color(0xFFF87171); // Light Red
      case Category.shopping:
        return const Color(0xFFF472B6); // Rose Pink
      case Category.subscriptions:
        return const Color(0xFF818CF8); // Indigo
      case Category.freelance:
        return const Color(0xFFFBBF24); // Amber
      case Category.investments:
        return const Color(0xFF34D399); // Emerald
      case Category.transfers:
        return const Color(0xFF38BDF8); // Light Cyan
      case Category.cashback:
        return const Color(0xFF2DD4BF); // Mint Teal
      case Category.sales:
        return const Color(0xFFFB7185); // Light Coral
      case Category.salary:
        return const Color(0xFF4ADE80); // Bright Green
      case Category.other:
        return const Color(0xFFCBD5E1); // Slate Gray
    }
  }

  @override
  State<BudgetExpenseRatioCard> createState() => _BudgetExpenseRatioCardState();
}

class _BudgetExpenseRatioCardState extends State<BudgetExpenseRatioCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progressAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant BudgetExpenseRatioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalExpense != widget.totalExpense ||
        oldWidget.totalIncome != widget.totalIncome ||
        !_mapsEqual(oldWidget.categoryExpenses, widget.categoryExpenses)) {
      _animController.forward(from: 0.0);
    }
  }

  bool _mapsEqual(Map<Category, double> a, Map<Category, double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (b[key] != a[key]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<ExpenseSegmentData> _buildSegments() {
    final entries = widget.categoryExpenses.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((e) {
      return ExpenseSegmentData(
        category: e.key,
        amount: e.value,
        color: BudgetExpenseRatioCard.getCategorySegmentColor(e.key),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final segments = _buildSegments();
    final hasExpenses = widget.totalExpense > 0;
    final hasIncome = widget.totalIncome > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E),
            Color(0xFF115E59),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.32),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка карточки: Заголовок и статус-бейдж
          _buildHeaderRow(context, textTheme, hasIncome, hasExpenses),
          const SizedBox(height: 18),
          // Центральная часть: Donut Chart слева и список категорий справа
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDonutSection(
                  context, textTheme, segments, hasIncome, hasExpenses),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBreakdownSection(
                    context, textTheme, segments, hasExpenses),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Нижняя часть: Итоги дохода и расхода (единый стиль с BalanceCard)
          Row(
            children: [
              Expanded(
                child: _SummaryInfoChip(
                  label: context.l10n.income_title,
                  amount: widget.totalIncome,
                  icon: Icons.arrow_downward_rounded,
                  isZeroIncome: !hasIncome,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryInfoChip(
                  label: context.l10n.expense_title,
                  amount: widget.totalExpense,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    TextTheme textTheme,
    bool hasIncome,
    bool hasExpenses,
  ) {
    String badgeText;
    Color badgeBg = Colors.white.withValues(alpha: 0.14);
    Color badgeTextColor = Colors.white;

    if (!hasExpenses) {
      badgeText = '0%';
    } else if (hasIncome) {
      final ratio = ((widget.totalExpense / widget.totalIncome) * 100).round();
      if (ratio > 100) {
        badgeText = '! $ratio%';
        badgeBg = const Color(0xFFF43F5E).withValues(alpha: 0.28);
        badgeTextColor = const Color(0xFFFFE4E6);
      } else {
        badgeText = '$ratio%';
      }
    } else {
      badgeText = _getOnlyExpensesBadge(context);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _getCardTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Text(
            badgeText,
            style: textTheme.labelSmall?.copyWith(
              color: badgeTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  static String _getCardTitle(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'uz':
        return 'Xarajatlar tarkibi';
      case 'en':
        return 'Expense structure';
      default:
        return 'Структура расходов';
    }
  }

  static String _getIncomeSuffix(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'uz':
        return 'daromaddan';
      case 'en':
        return 'of income';
      default:
        return 'от дохода';
    }
  }

  static String _getOnlyExpensesBadge(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'uz':
        return 'Faqat xarajat';
      case 'en':
        return 'Expenses only';
      default:
        return 'Только расходы';
    }
  }

  static String _getTotalExpensesCenterText(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'uz':
        return 'xarajat';
      case 'en':
        return 'expenses';
      default:
        return 'всего трат';
    }
  }

  static String _getNoExpensesCenterText(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    switch (lang) {
      case 'uz':
        return "xarajat yo'q";
      case 'en':
        return 'no expenses';
      default:
        return 'нет трат';
    }
  }

  Widget _buildDonutSection(
    BuildContext context,
    TextTheme textTheme,
    List<ExpenseSegmentData> segments,
    bool hasIncome,
    bool hasExpenses,
  ) {
    String centerPrimaryText;
    String centerSubText;

    if (!hasExpenses) {
      centerPrimaryText = '0%';
      centerSubText = _getNoExpensesCenterText(context);
    } else if (hasIncome) {
      final ratio = ((widget.totalExpense / widget.totalIncome) * 100).round();
      centerPrimaryText = '$ratio%';
      centerSubText = _getIncomeSuffix(context);
    } else {
      centerPrimaryText = '100%';
      centerSubText = _getTotalExpensesCenterText(context);
    }

    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _progressAnim,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(100, 100),
                  painter: _DonutChartPainter(
                    segments: segments,
                    totalExpense: widget.totalExpense,
                    animationProgress: _progressAnim.value,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerPrimaryText,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerSubText,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(
    BuildContext context,
    TextTheme textTheme,
    List<ExpenseSegmentData> segments,
    bool hasExpenses,
  ) {
    if (!hasExpenses || segments.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.no_transactions,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Показываем максимум 3 элемента:
    // если категорий <= 3, показываем все;
    // если категорий > 3, показываем топ-2 и строку "+N другие" с остатком.
    const maxItems = 3;
    final List<ExpenseSegmentData> topSegments;
    final double remainingSum;
    final int remainingCount;

    if (segments.length <= maxItems) {
      topSegments = segments;
      remainingSum = 0;
      remainingCount = 0;
    } else {
      topSegments = segments.take(2).toList();
      final remaining = segments.skip(2).toList();
      remainingCount = remaining.length;
      remainingSum = remaining.fold(0.0, (acc, s) => acc + s.amount);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in topSegments)
          _CategoryLegendRow(
            color: item.color,
            name: item.category.getLocalizedName(context),
            amount: item.amount,
            percentage: ((item.amount / widget.totalExpense) * 100).round(),
          ),
        if (remainingCount > 0)
          _CategoryLegendRow(
            color: const Color(0xFFCBD5E1),
            name:
                '+$remainingCount ${context.l10n.category_other.toLowerCase()}',
            amount: remainingSum,
            percentage: ((remainingSum / widget.totalExpense) * 100).round(),
          ),
      ],
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  final Color color;
  final String name;
  final double amount;
  final int percentage;

  const _CategoryLegendRow({
    required this.color,
    required this.name,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$percentage%',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1.5),
          Padding(
            padding: const EdgeInsets.only(left: 13.0),
            child: Text(
              CurrencyFormatter.format(amount, showSymbol: true),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryInfoChip extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final bool isZeroIncome;

  const _SummaryInfoChip({
    required this.label,
    required this.amount,
    required this.icon,
    this.isZeroIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          CurrencyFormatter.formatText(
            amount,
            showSign: false,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
            useFittedBox: true,
          ),
        ],
      ),
    );
  }
}

/// Кастомный отрисовщик Donut Chart с зазорами между сегментами и плавной анимацией.
class _DonutChartPainter extends CustomPainter {
  final List<ExpenseSegmentData> segments;
  final double totalExpense;
  final double animationProgress;

  const _DonutChartPainter({
    required this.segments,
    required this.totalExpense,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 10.0;
    final radius = (size.width - strokeWidth) / 2;

    // Фоновое кольцо
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withValues(alpha: 0.12);

    canvas.drawCircle(center, radius, bgPaint);

    if (totalExpense <= 0 || segments.isEmpty) {
      return;
    }

    // Если сегментов больше одного — делаем микро-зазор между сегментами
    final hasMultiple = segments.length > 1;
    final double gapAngle = hasMultiple ? 0.045 : 0.0;
    final double totalAvailableAngle = (2 * math.pi) * animationProgress;

    double currentAngle = -math.pi / 2; // Начало с 12 часов

    for (final segment in segments) {
      final double fraction = segment.amount / totalExpense;
      final double sweep = fraction * totalAvailableAngle;

      if (sweep <= 0.001) continue;

      final double effectiveSweep = math.max(0.005, sweep - gapAngle);
      final double effectiveStart = currentAngle + (gapAngle / 2);

      final segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = segment.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        effectiveStart,
        effectiveSweep,
        false,
        segmentPaint,
      );

      currentAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.totalExpense != totalExpense ||
        oldDelegate.segments != segments;
  }
}
