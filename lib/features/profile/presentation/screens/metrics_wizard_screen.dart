import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/calorie_target_calculator.dart';
import '../../../../core/services/metrics_prompt_store.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tap_card.dart';
import '../../domain/entities/user_metrics_entity.dart';
import '../providers/user_metrics_provider.dart';
import '../widgets/metrics_step_scaffold.dart';

/// 5-step measurement wizard: sex, body stats, target weight, activity,
/// result. Opened after the user has already seen value from the app (first
/// meal saved) — never from onboarding, where a 0→1 page already loses 32%
/// of visitors and a measurement form would only make that worse.
///
/// Saves a [UserMetricsEntity] on completion via
/// [userMetricsLocalDataSourceProvider]; every screen reading
/// `dailyCalorieTargetProvider` picks the new target up automatically once
/// [userMetricsProvider] is invalidated.
///
/// Dismissing (close button, or the hardware back button on the first page)
/// calls [MetricsPromptStore.markDismissed] — permanently. Nothing in this
/// screen re-opens it; the next entry point is the user's own profile,
/// wired in a later task.
class MetricsWizardScreen extends ConsumerStatefulWidget {
  const MetricsWizardScreen({super.key});

  @override
  ConsumerState<MetricsWizardScreen> createState() =>
      _MetricsWizardScreenState();
}

class _MetricsWizardScreenState extends ConsumerState<MetricsWizardScreen> {
  /// Step names in page order, used both for the progress dots (the result
  /// page renders none — it's the destination, not a step toward one) and
  /// for the `step` prop on every analytics event.
  static const _stepNames = ['sex', 'body', 'target', 'activity'];

  final _pageController = PageController();
  final _bodyFormKey = GlobalKey<FormState>();
  final _targetFormKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  int _page = 0;
  BiologicalSex? _sex;
  ActivityLevel? _activity;
  bool _maintainWeight = false;
  bool _saving = false;

  /// Guards against re-seeding the form every time [userMetricsProvider]
  /// rebuilds this widget (e.g. after the save below invalidates it) —
  /// without this, finishing the wizard would immediately overwrite the
  /// just-typed values with the freshly saved ones on the next frame.
  bool _seeded = false;

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _seedFrom(UserMetricsEntity m) {
    _sex = m.sex;
    _activity = m.activity;
    _ageController.text = m.ageAt(DateTime.now()).toString();
    _heightController.text = m.heightCm.toString();
    _weightController.text = _formatWeight(m.weightKg);
    final target = m.targetWeightKg;
    if (target == null) {
      _maintainWeight = true;
    } else {
      _targetWeightController.text = _formatWeight(target);
    }
  }

  String _formatWeight(double w) =>
      w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();

  void _goToPage(int page) {
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  void _trackStepCompleted(String step) {
    ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.metricsStepCompleted, props: {'step': step});
  }

  Future<void> _handleDismiss() async {
    final step = _page < _stepNames.length ? _stepNames[_page] : 'result';
    ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.metricsDismissed, props: {'step': step});
    await ref.read(metricsPromptStoreProvider).markDismissed();
    if (mounted) Navigator.of(context).pop();
  }

  void _handleBack() {
    if (_page == 0) {
      _handleDismiss();
      return;
    }
    _goToPage(_page - 1);
  }

  void _handleSexNext() {
    if (_sex == null) return;
    _trackStepCompleted('sex');
    _goToPage(1);
  }

  void _handleBodyNext() {
    if (!_bodyFormKey.currentState!.validate()) return;
    _trackStepCompleted('body');
    _goToPage(2);
  }

  void _handleTargetNext() {
    if (!_targetFormKey.currentState!.validate()) return;
    _trackStepCompleted('target');
    _goToPage(3);
  }

  void _handleActivityNext() {
    if (_activity == null) return;
    _trackStepCompleted('activity');
    _goToPage(4);
  }

  Future<void> _handleFinish() async {
    if (_saving) return;
    final userId = ref.read(effectiveUserIdProvider);
    final sex = _sex;
    final activity = _activity;
    if (userId == null || sex == null || activity == null) return;

    setState(() => _saving = true);

    final age = int.parse(_ageController.text.trim());
    final entity = UserMetricsEntity(
      userId: userId,
      sex: sex,
      birthYear: DateTime.now().year - age,
      heightCm: int.parse(_heightController.text.trim()),
      weightKg: double.parse(_weightController.text.trim()),
      targetWeightKg: _maintainWeight
          ? null
          : double.parse(_targetWeightController.text.trim()),
      activity: activity,
      updatedAt: DateTime.now(),
    );

    await ref.read(userMetricsLocalDataSourceProvider).save(entity);
    ref.invalidate(userMetricsProvider);

    final result = calculateCalorieTarget(
      entity.toCalculatorInput(DateTime.now()),
    );
    ref
        .read(analyticsServiceProvider)
        .track(
          FunnelEvents.metricsCompleted,
          props: {'target_kcal': result.target, 'activity': activity.name},
        );
    await ref.read(metricsPromptStoreProvider).markCompleted();

    if (!mounted) return;
    // Captured before popping: GoRouter itself outlives this screen's
    // BuildContext, so calling .go() on it after the pop below is safe,
    // unlike calling context.go() on an already-deactivated context.
    final router = GoRouter.of(context);
    final isGuest = ref.read(isGuestProvider);
    Navigator.of(context).pop();
    if (isGuest) router.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    // Existing metrics (edit-in-place case): seed the form once, the first
    // time a value is available. Mutating fields here — rather than in
    // initState — is what lets a not-yet-loaded FutureProvider fill the
    // form in as soon as it resolves.
    final existing = ref.watch(userMetricsProvider).value;
    if (!_seeded && existing != null) {
      _seeded = true;
      _seedFrom(existing);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: colors.backgroundGradient),
          child: SafeArea(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricsStepScaffold(
                  icon: Icons.person_outline_rounded,
                  title: l10n.metricsSexStepTitle,
                  subtitle: l10n.metricsSexStepSubtitle,
                  stepIndex: 0,
                  stepCount: _stepNames.length,
                  onClose: _handleDismiss,
                  closeTooltip: l10n.metricsCloseTooltip,
                  backTooltip: l10n.metricsBackTooltip,
                  primaryLabel: l10n.continueText,
                  primaryKey: const Key('metricsSexNext'),
                  onPrimaryPressed: _sex == null ? null : _handleSexNext,
                  child: _SexStep(
                    value: _sex,
                    onChanged: (v) => setState(() => _sex = v),
                  ),
                ),
                MetricsStepScaffold(
                  icon: Icons.straighten_rounded,
                  title: l10n.metricsBodyStepTitle,
                  subtitle: l10n.metricsBodyStepSubtitle,
                  stepIndex: 1,
                  stepCount: _stepNames.length,
                  onBack: _handleBack,
                  onClose: _handleDismiss,
                  closeTooltip: l10n.metricsCloseTooltip,
                  backTooltip: l10n.metricsBackTooltip,
                  primaryLabel: l10n.continueText,
                  primaryKey: const Key('metricsBodyNext'),
                  onPrimaryPressed: _handleBodyNext,
                  child: _BodyStep(
                    formKey: _bodyFormKey,
                    ageController: _ageController,
                    heightController: _heightController,
                    weightController: _weightController,
                  ),
                ),
                MetricsStepScaffold(
                  icon: Icons.flag_outlined,
                  title: l10n.metricsTargetStepTitle,
                  subtitle: l10n.metricsTargetStepSubtitle,
                  stepIndex: 2,
                  stepCount: _stepNames.length,
                  onBack: _handleBack,
                  onClose: _handleDismiss,
                  closeTooltip: l10n.metricsCloseTooltip,
                  backTooltip: l10n.metricsBackTooltip,
                  primaryLabel: l10n.continueText,
                  primaryKey: const Key('metricsTargetNext'),
                  onPrimaryPressed: _handleTargetNext,
                  child: _TargetStep(
                    formKey: _targetFormKey,
                    targetWeightController: _targetWeightController,
                    maintainWeight: _maintainWeight,
                    onMaintainWeightChanged: (v) =>
                        setState(() => _maintainWeight = v),
                  ),
                ),
                MetricsStepScaffold(
                  icon: Icons.directions_run_rounded,
                  title: l10n.metricsActivityStepTitle,
                  subtitle: l10n.metricsActivityStepSubtitle,
                  stepIndex: 3,
                  stepCount: _stepNames.length,
                  onBack: _handleBack,
                  onClose: _handleDismiss,
                  closeTooltip: l10n.metricsCloseTooltip,
                  backTooltip: l10n.metricsBackTooltip,
                  primaryLabel: l10n.continueText,
                  primaryKey: const Key('metricsActivityNext'),
                  onPrimaryPressed: _activity == null
                      ? null
                      : _handleActivityNext,
                  child: _ActivityStep(
                    value: _activity,
                    onChanged: (v) => setState(() => _activity = v),
                  ),
                ),
                _ResultStep(
                  scaffoldBuilder:
                      (
                        {required child, required onPrimaryPressed}) =>
                          MetricsStepScaffold(
                            icon: Icons.local_fire_department_rounded,
                            title: l10n.metricsResultStepTitle,
                            subtitle: l10n.metricsMedicalDisclaimer,
                            stepIndex: 4,
                            stepCount: 0,
                            onBack: _handleBack,
                            onClose: _handleDismiss,
                            closeTooltip: l10n.metricsCloseTooltip,
                            backTooltip: l10n.metricsBackTooltip,
                            primaryLabel: l10n.metricsSaveToAccountCta,
                            primaryKey: const Key('metricsFinish'),
                            onPrimaryPressed: onPrimaryPressed,
                            child: child,
                          ),
                  sex: _sex,
                  age: int.tryParse(_ageController.text.trim()),
                  heightCm: int.tryParse(_heightController.text.trim()),
                  weightKg: double.tryParse(_weightController.text.trim()),
                  targetWeightKg: _maintainWeight
                      ? null
                      : double.tryParse(_targetWeightController.text.trim()),
                  activity: _activity,
                  onFinish: _saving ? null : _handleFinish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SexStep extends StatelessWidget {
  final BiologicalSex? value;
  final ValueChanged<BiologicalSex> onChanged;

  const _SexStep({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(BiologicalSex, String, IconData)>[
      (BiologicalSex.female, l10n.metricsSexFemale, Icons.female_rounded),
      (BiologicalSex.male, l10n.metricsSexMale, Icons.male_rounded),
      (
        BiologicalSex.unspecified,
        l10n.metricsSexUnspecified,
        Icons.remove_circle_outline_rounded,
      ),
    ];
    return Column(
      children: [
        for (final option in options) ...[
          _ChoiceCard(
            label: option.$2,
            icon: option.$3,
            isSelected: value == option.$1,
            onTap: () => onChanged(option.$1),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BodyStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController weightController;

  const _BodyStep({
    required this.formKey,
    required this.ageController,
    required this.heightController,
    required this.weightController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: formKey,
      child: Column(
        children: [
          _NumberField(
            key: const Key('metricsAgeField'),
            controller: ageController,
            label: l10n.metricsAgeLabel,
            min: 16,
            max: 100,
            allowDecimal: false,
          ),
          const SizedBox(height: 16),
          _NumberField(
            key: const Key('metricsHeightField'),
            controller: heightController,
            label: l10n.metricsHeightLabel,
            min: 120,
            max: 230,
            allowDecimal: false,
          ),
          const SizedBox(height: 16),
          _NumberField(
            key: const Key('metricsWeightField'),
            controller: weightController,
            label: l10n.metricsWeightLabel,
            min: 30,
            max: 300,
            allowDecimal: true,
          ),
        ],
      ),
    );
  }
}

class _TargetStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController targetWeightController;
  final bool maintainWeight;
  final ValueChanged<bool> onMaintainWeightChanged;

  const _TargetStep({
    required this.formKey,
    required this.targetWeightController,
    required this.maintainWeight,
    required this.onMaintainWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!maintainWeight) ...[
            _NumberField(
              key: const Key('metricsTargetWeightField'),
              controller: targetWeightController,
              label: l10n.metricsTargetWeightLabel,
              min: 30,
              max: 300,
              allowDecimal: true,
            ),
            const SizedBox(height: 16),
          ],
          _ChoiceCard(
            label: l10n.metricsMaintainWeightOption,
            icon: Icons.balance_rounded,
            isSelected: maintainWeight,
            onTap: () => onMaintainWeightChanged(!maintainWeight),
          ),
        ],
      ),
    );
  }
}

class _ActivityStep extends StatelessWidget {
  final ActivityLevel? value;
  final ValueChanged<ActivityLevel> onChanged;

  const _ActivityStep({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(ActivityLevel, String, String, IconData)>[
      (
        ActivityLevel.sedentary,
        l10n.metricsActivitySedentary,
        l10n.metricsActivitySedentaryDesc,
        Icons.chair_outlined,
      ),
      (
        ActivityLevel.light,
        l10n.metricsActivityLight,
        l10n.metricsActivityLightDesc,
        Icons.directions_walk_rounded,
      ),
      (
        ActivityLevel.moderate,
        l10n.metricsActivityModerate,
        l10n.metricsActivityModerateDesc,
        Icons.directions_bike_rounded,
      ),
      (
        ActivityLevel.active,
        l10n.metricsActivityActive,
        l10n.metricsActivityActiveDesc,
        Icons.fitness_center_rounded,
      ),
    ];
    return Column(
      children: [
        for (final option in options) ...[
          _ChoiceCard(
            label: option.$2,
            description: option.$3,
            icon: option.$4,
            isSelected: value == option.$1,
            onTap: () => onChanged(option.$1),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

typedef _ResultScaffoldBuilder =
    Widget Function({
      required Widget child,
      required VoidCallback? onPrimaryPressed,
    });

class _ResultStep extends StatelessWidget {
  final _ResultScaffoldBuilder scaffoldBuilder;
  final BiologicalSex? sex;
  final int? age;
  final int? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final ActivityLevel? activity;
  final VoidCallback? onFinish;

  const _ResultStep({
    required this.scaffoldBuilder,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.targetWeightKg,
    required this.activity,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    final complete =
        sex != null &&
        age != null &&
        heightCm != null &&
        weightKg != null &&
        activity != null;

    final target = complete
        ? calculateCalorieTarget(
            CalorieTargetInput(
              sex: sex!,
              age: age!,
              heightCm: heightCm!,
              weightKg: weightKg!,
              targetWeightKg: targetWeightKg,
              activity: activity!,
            ),
          ).target
        : null;

    return scaffoldBuilder(
      onPrimaryPressed: complete ? onFinish : null,
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              target?.toString() ?? '—',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: colors.primary,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.metricsResultKcalPerDay,
              style: TextStyle(fontSize: 14, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable option card: icon badge, label, optional description, and a
/// trailing check when selected. Shared by the sex/activity/maintain-weight
/// choices — the same shape as the profile screen's tap cards.
class _ChoiceCard extends StatelessWidget {
  final String label;
  final String? description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
    this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppTapCard(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(20),
      decoration: BoxDecoration(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.1)
            : colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? colors.primary : colors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: colors.primaryDark, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: isSelected ? colors.primary : colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A bounded numeric [TextFormField]. [min]/[max] drive both the keyboard
/// input filter (decimal point only when [allowDecimal]) and the shared
/// `metricsRangeError` validation message.
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final num min;
  final num max;
  final bool allowDecimal;

  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.min,
    required this.max,
    required this.allowDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        if (allowDecimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsed = double.tryParse(value?.trim() ?? '');
        if (parsed == null || parsed < min || parsed > max) {
          return l10n.metricsRangeError(min.round(), max.round());
        }
        return null;
      },
    );
  }
}
