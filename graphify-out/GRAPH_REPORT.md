# Graph Report - NutriLens  (2026-09-14)

## Corpus Check
- 405 files · ~396,830 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2898 nodes · 4153 edges · 55 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 4 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 72|Community 72]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 130 edges
2. `package:flutter_riverpod/flutter_riverpod.dart` - 109 edges
3. `package:flutter_test/flutter_test.dart` - 106 edges
4. `../../../../core/theme/app_colors.dart` - 60 edges
5. `../../../../core/extensions/l10n_extension.dart` - 57 edges
6. `package:shared_preferences/shared_preferences.dart` - 40 edges
7. `package:supabase_flutter/supabase_flutter.dart` - 35 edges
8. `package:go_router/go_router.dart` - 31 edges
9. `_` - 31 edges
10. `package:nutrilens/l10n/generated/app_localizations.dart` - 30 edges

## Surprising Connections (you probably didn't know these)
- `min` --calls--> `paste_shadow()`  [INFERRED]
  lib\core\services\hp_score_calculator.dart → tools\generate_store_assets.py
- `rejects()` --calls--> `action`  [INFERRED]
  supabase\functions\gemini-proxy\request_guard_test.ts → lib\features\auth\data\repositories\auth_repository_impl.dart
- `body()` --calls--> `validateBody()`  [INFERRED]
  supabase\functions\gemini-proxy\request_guard_test.ts → supabase\functions\gemini-proxy\request_guard.ts

## Communities

### Community 0 - "Community 0"
Cohesion: 0.01
Nodes (297): categoryLabel, additives, allergens, blacklist, counterfeit_products, favorites, food_products, KEY (+289 more)

### Community 1 - "Community 1"
Cohesion: 0.01
Nodes (275): ../../../additive/domain/entities/allergen_entity.dart, subscriptionsFor, build, _buildLabel, CozyGlowBackdrop, dispose, initState, LoginScreen (+267 more)

### Community 2 - "Community 2"
Cohesion: 0.01
Nodes (134): analytics_event.dart, analytics_service.dart, bootstrap.dart, AnalyticsService, _persist, _restore, track, upload (+126 more)

### Community 3 - "Community 3"
Cohesion: 0.01
Nodes (140): account_deletion_service.dart, AdditiveEntity, AdditiveLocalDataSourceImpl, AdditivesCompanion, AllergenEntity, _allergenRowToEntity, _entityToCompanion, _rowToEntity (+132 more)

### Community 4 - "Community 4"
Cohesion: 0.02
Nodes (126): app_session.dart, StateError, GuestDataSummary, GuestMigrationService, _AlreadyRegisteredFailure, main, main, main (+118 more)

### Community 5 - "Community 5"
Cohesion: 0.02
Nodes (131): build, _Chip, Column, Container, FiltersPreview, HealthScoreBar, MealPreview, ScorePreview (+123 more)

### Community 6 - "Community 6"
Cohesion: 0.02
Nodes (131): app_localizations.dart, build, Scaffold, SizedBox, WaterScreen, _WeekChart, AppLocalizationsEn, calorieTargetCardSubtitleSet (+123 more)

### Community 7 - "Community 7"
Cohesion: 0.02
Nodes (105): anthropic_ai_service.dart, AdditiveDetailScreen, ComparisonScreen, createRouter, EditProductScreen, FoodResultScreen, GoRouter, MealDetailScreen (+97 more)

### Community 8 - "Community 8"
Cohesion: 0.02
Nodes (101): ../analytics/failure_reason.dart, ../../../auth/presentation/providers/auth_provider.dart, _blocked, BonusScanResult, _callCheck, _isAuthError, ScanCheckResult, ScanLimitService (+93 more)

### Community 9 - "Community 9"
Cohesion: 0.02
Nodes (97): app_typography.dart, body, _guard, _milestone, _mapCustomerInfo, revenueCatLogLevelFor, SubscriptionStatus, _buildTheme (+89 more)

### Community 10 - "Community 10"
Cohesion: 0.02
Nodes (91): Additives, Allergens, Blacklist, CounterfeitProducts, Favorites, FoodProducts, MealEntries, ScanHistory (+83 more)

### Community 11 - "Community 11"
Cohesion: 0.03
Nodes (75): app_colors.dart, main, AppDatabase, LazyDatabase, MigrationStrategy, _openConnection, _containsAny, extractNutritionFromFile (+67 more)

### Community 12 - "Community 12"
Cohesion: 0.03
Nodes (71): compute, _ImagePrepJob, ImagePrepOptions, PreparedOcrImage, _prepareImage, _prepareOcrImageSync, ProductEntity, CommunityProductSource (+63 more)

### Community 13 - "Community 13"
Cohesion: 0.03
Nodes (71): ../analytics/analytics_event.dart, ../analytics/analytics_provider.dart, app_button.dart, app_tap_card.dart, AppButton, _AppButtonState, build, MergeSemantics (+63 more)

### Community 14 - "Community 14"
Cohesion: 0.03
Nodes (69): ../../../auth/presentation/widgets/guest_register_sheet.dart, authFailureReason, _sanitize, _snakeCase, IngredientsOcrService, AlertDialog, build, _buildAiCameraError (+61 more)

### Community 15 - "Community 15"
Cohesion: 0.04
Nodes (49): additive_chip.dart, _applyInitialProductInfo, build, _buildForm, _buildInfoBanner, _buildNumberField, _buildOcrButton, _buildPhotoPlaceholder (+41 more)

### Community 16 - "Community 16"
Cohesion: 0.04
Nodes (46): _calculateConfidence, _CleanResult, _cleanText, IngredientsOcrService, IngredientsParseResult, _normalizeForMatch, cancelWaterReminders, _ensureTimezone (+38 more)

### Community 17 - "Community 17"
Cohesion: 0.04
Nodes (49): app_localizations_ar.dart, app_localizations_en.dart, app_localizations_es.dart, app_localizations_pt.dart, app_localizations_tr.dart, app_localizations_zh.dart, AppLocalizations, AppLocalizationsAr (+41 more)

### Community 18 - "Community 18"
Cohesion: 0.04
Nodes (39): AlreadyRegisteredFailure, AuthFailure, CacheFailure, Failure, NetworkFailure, NotFoundFailure, RateLimitFailure, ServerFailure (+31 more)

### Community 19 - "Community 19"
Cohesion: 0.09
Nodes (39): _checkPersonalFilters, _containsAny, ContentWarning, DietarySuitability, hasAny, _calculateIngredientQualityPenalty, _calculateNutriFactor, _calculateRiskFactor (+31 more)

### Community 20 - "Community 20"
Cohesion: 0.05
Nodes (34): build, CaloriePeriodSelector, Column, DateFormat, labelFor, _rangeLabel, SizedBox, _bar (+26 more)

### Community 21 - "Community 21"
Cohesion: 0.06
Nodes (32): Additives, AdditivesCompanion, AdditivesData, Allergens, AllergensCompanion, AllergensData, Blacklist, BlacklistCompanion (+24 more)

### Community 22 - "Community 22"
Cohesion: 0.06
Nodes (29): build, Column, ComparisonShareCard, Container, Icon, _imgPlaceholder, Padding, _side (+21 more)

### Community 23 - "Community 23"
Cohesion: 0.06
Nodes (31): AppLocalizationsAr, calorieTargetCardSubtitleSet, containsFilteredItem, contributionCreditsEarned, dailyCalorieOver, dailyCalorieSummary, dailyValueNotePersonal, deleteAccountFailed (+23 more)

### Community 24 - "Community 24"
Cohesion: 0.06
Nodes (31): AppLocalizationsZh, calorieTargetCardSubtitleSet, containsFilteredItem, contributionCreditsEarned, dailyCalorieOver, dailyCalorieSummary, dailyValueNotePersonal, deleteAccountFailed (+23 more)

### Community 25 - "Community 25"
Cohesion: 0.06
Nodes (28): _better, ComparisonRow, _fmtG, _fmtGrade, _fmtInt, Function, _numRow, _nutriOrdinal (+20 more)

### Community 26 - "Community 26"
Cohesion: 0.07
Nodes (30): Additive, AdditivesCompanion, Allergen, AllergensCompanion, BlacklistCompanion, BlacklistEntry, copyWith, copyWithCompanion (+22 more)

### Community 27 - "Community 27"
Cohesion: 0.07
Nodes (27): ../../../additive/presentation/providers/additive_provider.dart, _AdditiveCard, _AdditiveCardData, _Badge, build, Column, Container, ContentAnalysisSection (+19 more)

### Community 28 - "Community 28"
Cohesion: 0.12
Nodes (15): action, alertProviderAuthFailure(), buildPrompt(), callGeminiFallback(), callOpenRouter(), handleOpenRouterAction(), languageName(), mealAnalysisPrompt() (+7 more)

### Community 29 - "Community 29"
Cohesion: 0.09
Nodes (18): AppColorsExtension, gaugeColor, novaColor, riskColor, AppTapCard, _AppTapCardState, build, Semantics (+10 more)

### Community 30 - "Community 30"
Cohesion: 0.17
Nodes (10): Locale, MacroRow, NutriLensEntry, NutriLensHomeWidget, NutriLensHomeWidgetView, Provider, TimelineEntry, TimelineProvider (+2 more)

### Community 32 - "Community 32"
Cohesion: 0.29
Nodes (9): calculateChemicalLoad(), calculateIngredientQualityPenalty(), calculateNutriFactor(), calculateRiskFactor(), clamp(), extractECodesFromText(), getAdditiveRiskLevels(), normalizeECode() (+1 more)

### Community 33 - "Community 33"
Cohesion: 0.35
Nodes (10): call_anthropic(), call_openrouter(), extract_json(), language_name(), load_env(), main(), meal_prompt(), post() (+2 more)

### Community 34 - "Community 34"
Cohesion: 0.31
Nodes (7): Capture-CurrentScreen(), Count-FileMatches(), Get-LaunchMetric(), Invoke-Adb(), Save-AdbBinary(), Save-UiTree(), Write-QaSummary()

### Community 35 - "Community 35"
Cohesion: 0.25
Nodes (7): CacheException, EmailAlreadyRegisteredException, NetworkException, NotFoundException, RateLimitException, ServerException, toString

### Community 36 - "Community 36"
Cohesion: 0.4
Nodes (4): calculateCalorieTarget, CalorieTargetInput, CalorieTargetResult, _round10

### Community 37 - "Community 37"
Cohesion: 0.4
Nodes (4): BarcodeValidator, hasValidGtinCheckDigit, isLikelyBarcode, isValidBarcode

### Community 38 - "Community 38"
Cohesion: 0.4
Nodes (4): StateError, StorageCleanupEntry, StorageFolderCleaner, visit

### Community 39 - "Community 39"
Cohesion: 0.5
Nodes (1): NutriLensHomeWidgetProvider

### Community 40 - "Community 40"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 41 - "Community 41"
Cohesion: 0.5
Nodes (2): FlutterAppDelegate, AppDelegate

### Community 42 - "Community 42"
Cohesion: 0.5
Nodes (2): RunnerTests, XCTestCase

### Community 43 - "Community 43"
Cohesion: 0.5
Nodes (3): displayHp, hpToGauge, normalizeTurkish

### Community 44 - "Community 44"
Cohesion: 0.5
Nodes (3): forComparison, forMeal, forProduct

### Community 45 - "Community 45"
Cohesion: 0.67
Nodes (1): GeneratedPluginRegistrant

### Community 46 - "Community 46"
Cohesion: 0.67
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 47 - "Community 47"
Cohesion: 0.67
Nodes (2): FilterOption, HealthFilterOptions

### Community 48 - "Community 48"
Cohesion: 0.67
Nodes (2): WaterDay, waterDayKey

### Community 49 - "Community 49"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 50 - "Community 50"
Cohesion: 1.0
Nodes (1): levelFor

### Community 51 - "Community 51"
Cohesion: 1.0
Nodes (1): isValid

### Community 52 - "Community 52"
Cohesion: 1.0
Nodes (1): decideGuestScan

### Community 53 - "Community 53"
Cohesion: 1.0
Nodes (1): BarcodeCameraLifecycle

### Community 54 - "Community 54"
Cohesion: 1.0
Nodes (1): suggestedWaterGoal

### Community 72 - "Community 72"
Cohesion: 1.0
Nodes (1): Kept in sync with AnthropicAiService._mealAnalysisPrompt.

## Knowledge Gaps
- **2197 isolated node(s):** `main`, `main`, `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry` (+2192 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 39`** (4 nodes): `NutriLensHomeWidgetProvider.kt`, `NutriLensHomeWidgetProvider`, `.formatKcal()`, `.onUpdate()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (4 nodes): `FlutterAppDelegate`, `AppDelegate.swift`, `AppDelegate`, `.application()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (4 nodes): `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (3 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (3 nodes): `GeneratedPluginRegistrant.m`, `GeneratedPluginRegistrant`, `-registerWithRegistry`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (3 nodes): `FilterOption`, `HealthFilterOptions`, `health_filter_options.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (3 nodes): `WaterDay`, `waterDayKey`, `water_day.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (2 nodes): `levelFor`, `macro_reference_constants.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 51`** (2 nodes): `isValid`, `product_categories.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 52`** (2 nodes): `decideGuestScan`, `guest_scan_gate.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 53`** (2 nodes): `BarcodeCameraLifecycle`, `barcode_camera_lifecycle.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 54`** (2 nodes): `suggestedWaterGoal`, `water_goal.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 72`** (1 nodes): `Kept in sync with AnthropicAiService._mealAnalysisPrompt.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 1` to `Community 0`, `Community 2`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 18`, `Community 19`, `Community 20`, `Community 22`, `Community 25`, `Community 27`, `Community 29`?**
  _High betweenness centrality (0.277) - this node is a cross-community bridge._
- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 2` to `Community 0`, `Community 1`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 11`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 20`, `Community 25`, `Community 27`?**
  _High betweenness centrality (0.202) - this node is a cross-community bridge._
- **Why does `package:flutter_test/flutter_test.dart` connect `Community 0` to `Community 2`, `Community 4`, `Community 9`, `Community 11`, `Community 12`, `Community 14`, `Community 16`?**
  _High betweenness centrality (0.125) - this node is a cross-community bridge._
- **What connects `main`, `main`, `MainActivity` to the rest of the system?**
  _2197 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._