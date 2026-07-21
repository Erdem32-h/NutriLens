import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'NutriLens'**
  String get appTitle;

  /// No description provided for @scanner.
  ///
  /// In tr, this message translates to:
  /// **'Tarayıcı'**
  String get scanner;

  /// No description provided for @history.
  ///
  /// In tr, this message translates to:
  /// **'Ürün Geçmişi'**
  String get history;

  /// No description provided for @favorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get favorites;

  /// No description provided for @profile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @login.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get login;

  /// No description provided for @register.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt Ol'**
  String get register;

  /// No description provided for @email.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get email;

  /// No description provided for @password.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt Ol'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get signOut;

  /// No description provided for @signInWithGoogle.
  ///
  /// In tr, this message translates to:
  /// **'Google ile giriş yap'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile giriş yap'**
  String get signInWithApple;

  /// No description provided for @noAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız yok mu?'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabınız var mı?'**
  String get haveAccount;

  /// No description provided for @scanBarcode.
  ///
  /// In tr, this message translates to:
  /// **'Barkod tarayın'**
  String get scanBarcode;

  /// No description provided for @productNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Ürün bulunamadı'**
  String get productNotFound;

  /// No description provided for @healthScore.
  ///
  /// In tr, this message translates to:
  /// **'Sağlık Puanı'**
  String get healthScore;

  /// No description provided for @chemicalLoad.
  ///
  /// In tr, this message translates to:
  /// **'Kimyasal Yük'**
  String get chemicalLoad;

  /// No description provided for @riskFactor.
  ///
  /// In tr, this message translates to:
  /// **'Risk Faktörü'**
  String get riskFactor;

  /// No description provided for @nutriFactor.
  ///
  /// In tr, this message translates to:
  /// **'Beslenme Faktörü'**
  String get nutriFactor;

  /// No description provided for @additives.
  ///
  /// In tr, this message translates to:
  /// **'Katkı Maddeleri'**
  String get additives;

  /// No description provided for @allergens.
  ///
  /// In tr, this message translates to:
  /// **'Alerjenler'**
  String get allergens;

  /// No description provided for @ingredients.
  ///
  /// In tr, this message translates to:
  /// **'İçerik'**
  String get ingredients;

  /// No description provided for @nutritionFacts.
  ///
  /// In tr, this message translates to:
  /// **'Besin Değerleri'**
  String get nutritionFacts;

  /// No description provided for @alternatives.
  ///
  /// In tr, this message translates to:
  /// **'Daha Sağlıklı Alternatifler'**
  String get alternatives;

  /// No description provided for @novaGroup.
  ///
  /// In tr, this message translates to:
  /// **'NOVA Grubu'**
  String get novaGroup;

  /// No description provided for @addToFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere Ekle'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden Çıkar'**
  String get removeFromFavorites;

  /// No description provided for @addToBlacklist.
  ///
  /// In tr, this message translates to:
  /// **'Kara Listeye Ekle'**
  String get addToBlacklist;

  /// No description provided for @removeFromBlacklist.
  ///
  /// In tr, this message translates to:
  /// **'Kara Listeden Çıkar'**
  String get removeFromBlacklist;

  /// No description provided for @blacklist.
  ///
  /// In tr, this message translates to:
  /// **'Kara Liste'**
  String get blacklist;

  /// No description provided for @noBlacklist.
  ///
  /// In tr, this message translates to:
  /// **'Kara listede ürün yok'**
  String get noBlacklist;

  /// No description provided for @blacklistedWarning.
  ///
  /// In tr, this message translates to:
  /// **'Bu ürünü daha önce engellediniz'**
  String get blacklistedWarning;

  /// No description provided for @scanHistory.
  ///
  /// In tr, this message translates to:
  /// **'Tarama Geçmişi'**
  String get scanHistory;

  /// No description provided for @noHistory.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tarama geçmişi yok'**
  String get noHistory;

  /// No description provided for @noFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori yok'**
  String get noFavorites;

  /// No description provided for @allergenWarning.
  ///
  /// In tr, this message translates to:
  /// **'Alerjen Uyarısı'**
  String get allergenWarning;

  /// No description provided for @dietFilters.
  ///
  /// In tr, this message translates to:
  /// **'Diyet Filtreleri'**
  String get dietFilters;

  /// No description provided for @oilFilters.
  ///
  /// In tr, this message translates to:
  /// **'Yağ Filtreleri'**
  String get oilFilters;

  /// No description provided for @chemicalFilters.
  ///
  /// In tr, this message translates to:
  /// **'Kimyasal Filtreleri'**
  String get chemicalFilters;

  /// No description provided for @compatible.
  ///
  /// In tr, this message translates to:
  /// **'Profilinizle uyumlu'**
  String get compatible;

  /// No description provided for @notCompatible.
  ///
  /// In tr, this message translates to:
  /// **'Profilinizle uyumlu değil'**
  String get notCompatible;

  /// No description provided for @counterfeitWarning.
  ///
  /// In tr, this message translates to:
  /// **'Bu ürün Tarım Bakanlığı Taklit-Tağşiş listesinde!'**
  String get counterfeitWarning;

  /// No description provided for @offline.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışı'**
  String get offline;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get loading;

  /// No description provided for @appSlogan.
  ///
  /// In tr, this message translates to:
  /// **'Gıdanızı tanıyın, sağlığınızı koruyun'**
  String get appSlogan;

  /// No description provided for @enterEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresinizi girin'**
  String get enterEmail;

  /// No description provided for @validEmail.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi girin'**
  String get validEmail;

  /// No description provided for @enterPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifrenizi girin'**
  String get enterPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 6 karakter olmalı'**
  String get passwordMinLength;

  /// No description provided for @createAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Oluştur'**
  String get createAccount;

  /// No description provided for @startHealthyJourney.
  ///
  /// In tr, this message translates to:
  /// **'Sağlıklı beslenme yolculuğunuza başlayın'**
  String get startHealthyJourney;

  /// No description provided for @fullName.
  ///
  /// In tr, this message translates to:
  /// **'Ad Soyad'**
  String get fullName;

  /// No description provided for @enterName.
  ///
  /// In tr, this message translates to:
  /// **'Adınızı girin'**
  String get enterName;

  /// No description provided for @confirmPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre tekrar'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In tr, this message translates to:
  /// **'Şifreler uyuşmuyor'**
  String get passwordsDoNotMatch;

  /// No description provided for @or.
  ///
  /// In tr, this message translates to:
  /// **'veya'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In tr, this message translates to:
  /// **'Google ile devam et'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In tr, this message translates to:
  /// **'Apple ile devam et'**
  String get continueWithApple;

  /// No description provided for @skip.
  ///
  /// In tr, this message translates to:
  /// **'Atla'**
  String get skip;

  /// No description provided for @scanBarcodeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Barkod Tara'**
  String get scanBarcodeTitle;

  /// No description provided for @scanBarcodeDescription.
  ///
  /// In tr, this message translates to:
  /// **'Ürünün barkodunu tarayın ve saniyeler içinde sağlık analizini görün.'**
  String get scanBarcodeDescription;

  /// No description provided for @healthScoreTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sağlık Puanı'**
  String get healthScoreTitle;

  /// No description provided for @healthScoreDescription.
  ///
  /// In tr, this message translates to:
  /// **'NutriLens HP skoru ile ürünün kimyasal yükü, risk faktörü ve beslenme değerini öğren.'**
  String get healthScoreDescription;

  /// No description provided for @personalFilters.
  ///
  /// In tr, this message translates to:
  /// **'Kişisel Filtreler'**
  String get personalFilters;

  /// No description provided for @personalFiltersDescription.
  ///
  /// In tr, this message translates to:
  /// **'Alerjenlerinizi, diyet tercihlerinizi ve kaçındığınız maddeleri belirleyin. Size özel analiz alın.'**
  String get personalFiltersDescription;

  /// No description provided for @start.
  ///
  /// In tr, this message translates to:
  /// **'Başla'**
  String get start;

  /// No description provided for @continueText.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get continueText;

  /// No description provided for @alignBarcodeInFrame.
  ///
  /// In tr, this message translates to:
  /// **'Barkodu çerçeve içine hizalayın'**
  String get alignBarcodeInFrame;

  /// No description provided for @cameraAccessDenied.
  ///
  /// In tr, this message translates to:
  /// **'Kamera erişimi reddedildi'**
  String get cameraAccessDenied;

  /// No description provided for @enableCameraPermission.
  ///
  /// In tr, this message translates to:
  /// **'Barkod taramak için kamera iznini ayarlardan açın.'**
  String get enableCameraPermission;

  /// No description provided for @productDetail.
  ///
  /// In tr, this message translates to:
  /// **'Ürün Detayı'**
  String get productDetail;

  /// No description provided for @productLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Ürün yüklenemedi'**
  String get productLoadFailed;

  /// No description provided for @productNotFoundDetail.
  ///
  /// In tr, this message translates to:
  /// **'Bu barkoda ait ürün bilgisi bulunamadı.'**
  String get productNotFoundDetail;

  /// No description provided for @barcode.
  ///
  /// In tr, this message translates to:
  /// **'Barkod'**
  String get barcode;

  /// No description provided for @noHistoryYet.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tarama geçmişi yok'**
  String get noHistoryYet;

  /// No description provided for @productsWillAppearHere.
  ///
  /// In tr, this message translates to:
  /// **'Ürünleri taradığınızda burada görünecek'**
  String get productsWillAppearHere;

  /// No description provided for @noFavoritesYet.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori ürün yok'**
  String get noFavoritesYet;

  /// No description provided for @addFavoritesHint.
  ///
  /// In tr, this message translates to:
  /// **'Beğendiğiniz ürünleri favorilere ekleyin'**
  String get addFavoritesHint;

  /// No description provided for @user.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get user;

  /// No description provided for @healthFilters.
  ///
  /// In tr, this message translates to:
  /// **'Sağlık Filtreleri'**
  String get healthFilters;

  /// No description provided for @allergenTypes.
  ///
  /// In tr, this message translates to:
  /// **'63 alerjen türü'**
  String get allergenTypes;

  /// No description provided for @dietOptions.
  ///
  /// In tr, this message translates to:
  /// **'Vegan, Vejetaryen, Glutensiz, Helal'**
  String get dietOptions;

  /// No description provided for @oilOptions.
  ///
  /// In tr, this message translates to:
  /// **'Palm, Kanola, Pamuk, Soya yağı'**
  String get oilOptions;

  /// No description provided for @chemicalOptions.
  ///
  /// In tr, this message translates to:
  /// **'Aspartam, MSG, Nişasta Bazlı Şeker'**
  String get chemicalOptions;

  /// No description provided for @offlineCache.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışı - Önbellek verisi gösteriliyor'**
  String get offlineCache;

  /// No description provided for @allergenSelectionPhase.
  ///
  /// In tr, this message translates to:
  /// **'Alerjen seçimi Phase 4\'te eklenecek'**
  String get allergenSelectionPhase;

  /// No description provided for @dietFilterPhase.
  ///
  /// In tr, this message translates to:
  /// **'Diyet filtreleri Phase 4\'te eklenecek'**
  String get dietFilterPhase;

  /// No description provided for @oilFilterPhase.
  ///
  /// In tr, this message translates to:
  /// **'Yağ filtreleri Phase 4\'te eklenecek'**
  String get oilFilterPhase;

  /// No description provided for @chemicalFilterPhase.
  ///
  /// In tr, this message translates to:
  /// **'Kimyasal filtreleri Phase 4\'te eklenecek'**
  String get chemicalFilterPhase;

  /// No description provided for @settings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// No description provided for @theme.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @darkMode.
  ///
  /// In tr, this message translates to:
  /// **'Karanlık Mod'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In tr, this message translates to:
  /// **'Aydınlık Mod'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get systemMode;

  /// No description provided for @turkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get turkish;

  /// No description provided for @english.
  ///
  /// In tr, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @tabHealth.
  ///
  /// In tr, this message translates to:
  /// **'SAĞLIK'**
  String get tabHealth;

  /// No description provided for @tabNutrient.
  ///
  /// In tr, this message translates to:
  /// **'BESİN'**
  String get tabNutrient;

  /// No description provided for @tabAlternative.
  ///
  /// In tr, this message translates to:
  /// **'ALTERNATİF'**
  String get tabAlternative;

  /// No description provided for @healthScoreLabel.
  ///
  /// In tr, this message translates to:
  /// **'SAĞLIK PUANI'**
  String get healthScoreLabel;

  /// No description provided for @scoreBreakdownWhy.
  ///
  /// In tr, this message translates to:
  /// **'Neden'**
  String get scoreBreakdownWhy;

  /// No description provided for @scoreBreakdownSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Puanın nasıl oluştuğunu gör'**
  String get scoreBreakdownSubtitle;

  /// No description provided for @scoreBreakdownBase.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç puanı'**
  String get scoreBreakdownBase;

  /// No description provided for @scoreBreakdownChemical.
  ///
  /// In tr, this message translates to:
  /// **'Kimyasal yük'**
  String get scoreBreakdownChemical;

  /// No description provided for @scoreBreakdownAdditives.
  ///
  /// In tr, this message translates to:
  /// **'katkı maddesi'**
  String get scoreBreakdownAdditives;

  /// No description provided for @scoreBreakdownRisk.
  ///
  /// In tr, this message translates to:
  /// **'Besinsel risk'**
  String get scoreBreakdownRisk;

  /// No description provided for @scoreBreakdownRiskSub.
  ///
  /// In tr, this message translates to:
  /// **'Şeker · tuz · doymuş yağ'**
  String get scoreBreakdownRiskSub;

  /// No description provided for @scoreBreakdownNutri.
  ///
  /// In tr, this message translates to:
  /// **'Besin kalitesi'**
  String get scoreBreakdownNutri;

  /// No description provided for @scoreBreakdownPenalty.
  ///
  /// In tr, this message translates to:
  /// **'İçerik cezası'**
  String get scoreBreakdownPenalty;

  /// No description provided for @scoreBreakdownPenaltySub.
  ///
  /// In tr, this message translates to:
  /// **'Rafine karbonhidrat / tatlı-yağlı atıştırmalık'**
  String get scoreBreakdownPenaltySub;

  /// No description provided for @scoreBreakdownResult.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç'**
  String get scoreBreakdownResult;

  /// No description provided for @scoreBreakdownCritical.
  ///
  /// In tr, this message translates to:
  /// **'Kritik içerik (ör. palm yağı, glikoz şurubu) tespit edildi — puan otomatik en düşük seviyeye sabitlendi.'**
  String get scoreBreakdownCritical;

  /// No description provided for @nova1Label.
  ///
  /// In tr, this message translates to:
  /// **'İşlenmemiş / minimal işlenmiş'**
  String get nova1Label;

  /// No description provided for @nova2Label.
  ///
  /// In tr, this message translates to:
  /// **'İşlenmiş mutfak malzemesi'**
  String get nova2Label;

  /// No description provided for @nova3Label.
  ///
  /// In tr, this message translates to:
  /// **'İşlenmiş gıda'**
  String get nova3Label;

  /// No description provided for @nova4Label.
  ///
  /// In tr, this message translates to:
  /// **'Ultra işlenmiş'**
  String get nova4Label;

  /// No description provided for @novaUnknownLabel.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmiyor'**
  String get novaUnknownLabel;

  /// No description provided for @worstIsBad.
  ///
  /// In tr, this message translates to:
  /// **'(5 EN KÖTÜ)'**
  String get worstIsBad;

  /// No description provided for @bestScore.
  ///
  /// In tr, this message translates to:
  /// **'EN İYİ'**
  String get bestScore;

  /// No description provided for @worstScore.
  ///
  /// In tr, this message translates to:
  /// **'EN KÖTÜ'**
  String get worstScore;

  /// No description provided for @contentAnalysis.
  ///
  /// In tr, this message translates to:
  /// **'İçerik Analizi'**
  String get contentAnalysis;

  /// No description provided for @eCodeAnalysis.
  ///
  /// In tr, this message translates to:
  /// **'E-Kod Analizi'**
  String get eCodeAnalysis;

  /// No description provided for @risky.
  ///
  /// In tr, this message translates to:
  /// **'RİSKLİ'**
  String get risky;

  /// No description provided for @caution.
  ///
  /// In tr, this message translates to:
  /// **'DİKKAT'**
  String get caution;

  /// No description provided for @safeLabel.
  ///
  /// In tr, this message translates to:
  /// **'GÜVENLİ'**
  String get safeLabel;

  /// No description provided for @naturalLabel.
  ///
  /// In tr, this message translates to:
  /// **'DOĞAL'**
  String get naturalLabel;

  /// No description provided for @ultraProcessed.
  ///
  /// In tr, this message translates to:
  /// **'Ultra işlenmiş ve ultra katkılı ürün'**
  String get ultraProcessed;

  /// No description provided for @highSugar.
  ///
  /// In tr, this message translates to:
  /// **'Aşırı şekerli !'**
  String get highSugar;

  /// No description provided for @moderateSugar.
  ///
  /// In tr, this message translates to:
  /// **'Orta düzey şeker içeriği'**
  String get moderateSugar;

  /// No description provided for @highSaturatedFat.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla doymuş yağ !'**
  String get highSaturatedFat;

  /// No description provided for @containsPalmOil.
  ///
  /// In tr, this message translates to:
  /// **'Palm yağı (Hurma yağı) içerir'**
  String get containsPalmOil;

  /// No description provided for @mayContainTransFat.
  ///
  /// In tr, this message translates to:
  /// **'Trans yağ içerebilir'**
  String get mayContainTransFat;

  /// No description provided for @containsFlavoring.
  ///
  /// In tr, this message translates to:
  /// **'Aroma vericiler içerir'**
  String get containsFlavoring;

  /// No description provided for @highSalt.
  ///
  /// In tr, this message translates to:
  /// **'Yüksek tuz içeriği'**
  String get highSalt;

  /// No description provided for @energyValue.
  ///
  /// In tr, this message translates to:
  /// **'Enerji Değeri'**
  String get energyValue;

  /// No description provided for @fatLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yağ'**
  String get fatLabel;

  /// No description provided for @sugarLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şeker'**
  String get sugarLabel;

  /// No description provided for @saturatedFatLabel.
  ///
  /// In tr, this message translates to:
  /// **'Doymuş yağ'**
  String get saturatedFatLabel;

  /// No description provided for @transFatLabel.
  ///
  /// In tr, this message translates to:
  /// **'Trans yağ'**
  String get transFatLabel;

  /// No description provided for @saltLabel.
  ///
  /// In tr, this message translates to:
  /// **'Tuz'**
  String get saltLabel;

  /// No description provided for @lowLevel.
  ///
  /// In tr, this message translates to:
  /// **'DÜŞÜK'**
  String get lowLevel;

  /// No description provided for @moderateLevel.
  ///
  /// In tr, this message translates to:
  /// **'ORTA DERECE'**
  String get moderateLevel;

  /// No description provided for @highLevel.
  ///
  /// In tr, this message translates to:
  /// **'YÜKSEK'**
  String get highLevel;

  /// No description provided for @criticalLevel.
  ///
  /// In tr, this message translates to:
  /// **'KRİTİK'**
  String get criticalLevel;

  /// No description provided for @veryHighLevel.
  ///
  /// In tr, this message translates to:
  /// **'ÇOK YÜKSEK'**
  String get veryHighLevel;

  /// No description provided for @dailyValue.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Değer'**
  String get dailyValue;

  /// No description provided for @detailedContent.
  ///
  /// In tr, this message translates to:
  /// **'Detaylı İçerik (100g)'**
  String get detailedContent;

  /// No description provided for @fiberLabel.
  ///
  /// In tr, this message translates to:
  /// **'Lif'**
  String get fiberLabel;

  /// No description provided for @proteinLabel.
  ///
  /// In tr, this message translates to:
  /// **'Protein'**
  String get proteinLabel;

  /// No description provided for @carbohydrateLabel.
  ///
  /// In tr, this message translates to:
  /// **'Karbonhidrat'**
  String get carbohydrateLabel;

  /// No description provided for @dailyValueNote.
  ///
  /// In tr, this message translates to:
  /// **'* Yüzdelik değerler 2000 kalorilik bir yetişkin diyeti baz alınarak hesaplanmıştır.'**
  String get dailyValueNote;

  /// No description provided for @didYouKnow.
  ///
  /// In tr, this message translates to:
  /// **'Biliyor muydunuz?'**
  String get didYouKnow;

  /// No description provided for @alternativesTip.
  ///
  /// In tr, this message translates to:
  /// **'Sağlık skoru 1 veya 2 olan ürünler, minimum işlenmiş ve en temiz içerikli seçeneklerdir. Daha düşük puanlı alternatiflere geçmek genel sağlığınızı belirgin şekilde iyileştirir.'**
  String get alternativesTip;

  /// No description provided for @alternativesComingSoon.
  ///
  /// In tr, this message translates to:
  /// **'Daha sağlıklı alternatifler yakında eklenecek'**
  String get alternativesComingSoon;

  /// No description provided for @noAdditives.
  ///
  /// In tr, this message translates to:
  /// **'Bu üründe katkı maddesi bulunmuyor'**
  String get noAdditives;

  /// No description provided for @noNutrientData.
  ///
  /// In tr, this message translates to:
  /// **'Besin değeri bilgisi mevcut değil'**
  String get noNutrientData;

  /// No description provided for @portion100g.
  ///
  /// In tr, this message translates to:
  /// **'100g'**
  String get portion100g;

  /// No description provided for @foodCategory.
  ///
  /// In tr, this message translates to:
  /// **'GIDA'**
  String get foodCategory;

  /// No description provided for @delete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get edit;

  /// No description provided for @addedToFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere eklendi'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden çıkarıldı'**
  String get removedFromFavorites;

  /// No description provided for @deletedFromHistory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmişten silindi'**
  String get deletedFromHistory;

  /// No description provided for @alreadyInFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Zaten favorilerde'**
  String get alreadyInFavorites;

  /// No description provided for @editProduct.
  ///
  /// In tr, this message translates to:
  /// **'Ürün Bilgilerini Düzenle'**
  String get editProduct;

  /// No description provided for @productName.
  ///
  /// In tr, this message translates to:
  /// **'Ürün Adı'**
  String get productName;

  /// No description provided for @brandName.
  ///
  /// In tr, this message translates to:
  /// **'Marka'**
  String get brandName;

  /// No description provided for @ingredientsTextLabel.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler'**
  String get ingredientsTextLabel;

  /// No description provided for @takePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf Çek'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden Seç'**
  String get chooseFromGallery;

  /// No description provided for @productPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Ürün Fotoğrafı'**
  String get productPhoto;

  /// No description provided for @saveChanges.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklikleri Kaydet'**
  String get saveChanges;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get cancel;

  /// No description provided for @saving.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor...'**
  String get saving;

  /// No description provided for @savedSuccessfully.
  ///
  /// In tr, this message translates to:
  /// **'Başarıyla kaydedildi'**
  String get savedSuccessfully;

  /// No description provided for @saveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kaydetme başarısız'**
  String get saveFailed;

  /// No description provided for @privacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik'**
  String get privacy;

  /// No description provided for @analyticsSharing.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım verilerini paylaş'**
  String get analyticsSharing;

  /// No description provided for @analyticsSharingDescription.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamanın nerede zorlaştığını görmemize yardım eder. Kişisel bilgilerin ve taradığın ürünler gönderilmez.'**
  String get analyticsSharingDescription;

  /// No description provided for @dataManagement.
  ///
  /// In tr, this message translates to:
  /// **'Veri Yönetimi'**
  String get dataManagement;

  /// No description provided for @deleteAllData.
  ///
  /// In tr, this message translates to:
  /// **'Tüm verileri sil'**
  String get deleteAllData;

  /// No description provided for @userData.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı verileri'**
  String get userData;

  /// No description provided for @deleteAllDataTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm veriler silinsin mi?'**
  String get deleteAllDataTitle;

  /// No description provided for @deleteAllDataMessage.
  ///
  /// In tr, this message translates to:
  /// **'Tarama geçmişi, favoriler, kara liste, öğünler ve profil filtrelerin silinir. Kullanıcı tarafından eklenen ürünler uygulama veritabanında kalır.'**
  String get deleteAllDataMessage;

  /// No description provided for @keepData.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get keepData;

  /// No description provided for @userDataDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı verilerin silindi.'**
  String get userDataDeleted;

  /// No description provided for @deleteDataFailed.
  ///
  /// In tr, this message translates to:
  /// **'Veriler silinemedi: {error}'**
  String deleteDataFailed(Object error);

  /// No description provided for @deleteAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı sil'**
  String get deleteAccount;

  /// No description provided for @permanent.
  ///
  /// In tr, this message translates to:
  /// **'Kalıcı'**
  String get permanent;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap kalıcı silinsin mi?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In tr, this message translates to:
  /// **'Önce kişisel verilerin temizlenir, ardından hesabın kalıcı olarak silinir. Kullanıcı tarafından eklenen ürünler uygulama veritabanında kalır.'**
  String get deleteAccountMessage;

  /// No description provided for @deleteAccountButton.
  ///
  /// In tr, this message translates to:
  /// **'Hesabı sil'**
  String get deleteAccountButton;

  /// No description provided for @accountDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın silindi.'**
  String get accountDeleted;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In tr, this message translates to:
  /// **'Hesap silinemedi: {error}'**
  String deleteAccountFailed(Object error);

  /// No description provided for @missingInfo.
  ///
  /// In tr, this message translates to:
  /// **'Eksik bilgiler tamamlanabilir'**
  String get missingInfo;

  /// No description provided for @noProductName.
  ///
  /// In tr, this message translates to:
  /// **'İsimsiz Ürün'**
  String get noProductName;

  /// No description provided for @fieldRequired.
  ///
  /// In tr, this message translates to:
  /// **'Bu alan zorunludur'**
  String get fieldRequired;

  /// No description provided for @newProductHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu ürün veritabanımızda yok. Bilgileri doldurarak ekleyebilirsiniz!'**
  String get newProductHint;

  /// No description provided for @completeProductInfo.
  ///
  /// In tr, this message translates to:
  /// **'Bazı bilgiler eksik. Lütfen zorunlu alanları tamamlayın.'**
  String get completeProductInfo;

  /// No description provided for @noHealthierAlternative.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategoride daha sağlıklı bir alternatif bulunamadı.'**
  String get noHealthierAlternative;

  /// No description provided for @share.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get share;

  /// No description provided for @shareScannedWith.
  ///
  /// In tr, this message translates to:
  /// **'NutriLens ile tarandı'**
  String get shareScannedWith;

  /// No description provided for @shareCalculatedWith.
  ///
  /// In tr, this message translates to:
  /// **'NutriLens ile hesaplandı'**
  String get shareCalculatedWith;

  /// No description provided for @shareFailed.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşım başarısız'**
  String get shareFailed;

  /// No description provided for @shareCompared.
  ///
  /// In tr, this message translates to:
  /// **'NutriLens ile karşılaştırıldı'**
  String get shareCompared;

  /// No description provided for @shareHealthier.
  ///
  /// In tr, this message translates to:
  /// **'Daha sağlıklı'**
  String get shareHealthier;

  /// No description provided for @compare.
  ///
  /// In tr, this message translates to:
  /// **'Kıyasla'**
  String get compare;

  /// No description provided for @comparePickSecond.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştırılacak ikinci ürünü seç'**
  String get comparePickSecond;

  /// No description provided for @compareMaxTwo.
  ///
  /// In tr, this message translates to:
  /// **'En fazla 2 ürün seçebilirsin'**
  String get compareMaxTwo;

  /// No description provided for @comparePickerEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Kıyaslanacak ürün bulunamadı'**
  String get comparePickerEmpty;

  /// No description provided for @nutriScoreLabel.
  ///
  /// In tr, this message translates to:
  /// **'Nutri-Score'**
  String get nutriScoreLabel;

  /// No description provided for @compareLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Ürünler yüklenemedi'**
  String get compareLoadError;

  /// No description provided for @category.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get category;

  /// No description provided for @saveAndView.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet ve Görüntüle'**
  String get saveAndView;

  /// No description provided for @invalidBarcode.
  ///
  /// In tr, this message translates to:
  /// **'Bu bir ürün barkodu değil. Lütfen bir ürün barkodu tarayın.'**
  String get invalidBarcode;

  /// No description provided for @ingredientsPhoto.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler Fotoğrafı'**
  String get ingredientsPhoto;

  /// No description provided for @ingredientsPhotoHint.
  ///
  /// In tr, this message translates to:
  /// **'Ambalajdaki içindekiler listesinin fotoğrafını çekin'**
  String get ingredientsPhotoHint;

  /// No description provided for @nutritionPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Besin Değerleri Fotoğrafı'**
  String get nutritionPhoto;

  /// No description provided for @nutritionPhotoHint.
  ///
  /// In tr, this message translates to:
  /// **'Ambalajdaki besin değerleri tablosunun fotoğrafını çekin'**
  String get nutritionPhotoHint;

  /// No description provided for @photoAdded.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf eklendi'**
  String get photoAdded;

  /// No description provided for @tapToAddPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf eklemek için dokunun'**
  String get tapToAddPhoto;

  /// No description provided for @scanIngredients.
  ///
  /// In tr, this message translates to:
  /// **'İçindekileri Fotoğraftan Tara'**
  String get scanIngredients;

  /// No description provided for @scanNutrition.
  ///
  /// In tr, this message translates to:
  /// **'Besin Değerlerini Fotoğraftan Tara'**
  String get scanNutrition;

  /// No description provided for @ocrProcessing.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraftan metin okunuyor...'**
  String get ocrProcessing;

  /// No description provided for @ocrSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Metin başarıyla çıkarıldı'**
  String get ocrSuccess;

  /// No description provided for @ocrFailed.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraftan metin okunamadı. Lütfen elle girin.'**
  String get ocrFailed;

  /// No description provided for @ocrNoText.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafta metin bulunamadı. Daha net bir fotoğraf deneyin.'**
  String get ocrNoText;

  /// No description provided for @saveFailedAuth.
  ///
  /// In tr, this message translates to:
  /// **'Kaydetmek için giriş yapmalısınız.'**
  String get saveFailedAuth;

  /// No description provided for @saveFailedUpload.
  ///
  /// In tr, this message translates to:
  /// **'Ürün fotoğrafı yüklenemedi.'**
  String get saveFailedUpload;

  /// No description provided for @saveFailedDatabase.
  ///
  /// In tr, this message translates to:
  /// **'Veritabanına kaydedilemedi. Lütfen tekrar deneyin.'**
  String get saveFailedDatabase;

  /// No description provided for @saveFailedNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Ağ hatası. Bağlantınızı kontrol edip tekrar deneyin.'**
  String get saveFailedNetwork;

  /// No description provided for @filterGluten.
  ///
  /// In tr, this message translates to:
  /// **'Gluten'**
  String get filterGluten;

  /// No description provided for @filterGlutenDesc.
  ///
  /// In tr, this message translates to:
  /// **'Buğday, arpa, yulaf, çavdar içeriklerini filtreler.'**
  String get filterGlutenDesc;

  /// No description provided for @filterLactose.
  ///
  /// In tr, this message translates to:
  /// **'Laktoz'**
  String get filterLactose;

  /// No description provided for @filterLactoseDesc.
  ///
  /// In tr, this message translates to:
  /// **'Süt ürünleri içerdiğinde uyarır.'**
  String get filterLactoseDesc;

  /// No description provided for @filterPeanut.
  ///
  /// In tr, this message translates to:
  /// **'Yer Fıstığı'**
  String get filterPeanut;

  /// No description provided for @filterPeanutDesc.
  ///
  /// In tr, this message translates to:
  /// **'Yer fıstığı içerdiğinde uyarır.'**
  String get filterPeanutDesc;

  /// No description provided for @filterSoy.
  ///
  /// In tr, this message translates to:
  /// **'Soya'**
  String get filterSoy;

  /// No description provided for @filterSoyDesc.
  ///
  /// In tr, this message translates to:
  /// **'Soya ve soya lesitini içeriklerini filtreler.'**
  String get filterSoyDesc;

  /// No description provided for @filterEgg.
  ///
  /// In tr, this message translates to:
  /// **'Yumurta'**
  String get filterEgg;

  /// No description provided for @filterEggDesc.
  ///
  /// In tr, this message translates to:
  /// **'Yumurta içerdiğinde uyarır.'**
  String get filterEggDesc;

  /// No description provided for @filterFish.
  ///
  /// In tr, this message translates to:
  /// **'Balık ve Deniz Ürünleri'**
  String get filterFish;

  /// No description provided for @filterFishDesc.
  ///
  /// In tr, this message translates to:
  /// **'Balık, karides ve diğer su ürünlerini belirtir.'**
  String get filterFishDesc;

  /// No description provided for @filterVegan.
  ///
  /// In tr, this message translates to:
  /// **'Vegan'**
  String get filterVegan;

  /// No description provided for @filterVeganDesc.
  ///
  /// In tr, this message translates to:
  /// **'Hayvansal içerikleri (süt, et, bal, yumurta) engeller.'**
  String get filterVeganDesc;

  /// No description provided for @filterVegetarian.
  ///
  /// In tr, this message translates to:
  /// **'Vejetaryen'**
  String get filterVegetarian;

  /// No description provided for @filterVegetarianDesc.
  ///
  /// In tr, this message translates to:
  /// **'Tüm et ürünlerini filtreler.'**
  String get filterVegetarianDesc;

  /// No description provided for @filterHalal.
  ///
  /// In tr, this message translates to:
  /// **'Helal Hassasiyeti'**
  String get filterHalal;

  /// No description provided for @filterHalalDesc.
  ///
  /// In tr, this message translates to:
  /// **'Domuz ürünleri ve alkol içeriklerini filtreler.'**
  String get filterHalalDesc;

  /// No description provided for @filterPalmOil.
  ///
  /// In tr, this message translates to:
  /// **'Palm Yağı'**
  String get filterPalmOil;

  /// No description provided for @filterPalmOilDesc.
  ///
  /// In tr, this message translates to:
  /// **'Palm / Hurma yağı içeriklerini filtreler.'**
  String get filterPalmOilDesc;

  /// No description provided for @filterTransFat.
  ///
  /// In tr, this message translates to:
  /// **'Trans Yağ / Margarin'**
  String get filterTransFat;

  /// No description provided for @filterTransFatDesc.
  ///
  /// In tr, this message translates to:
  /// **'Trans ve hidrojene yağları filtreler.'**
  String get filterTransFatDesc;

  /// No description provided for @filterCanola.
  ///
  /// In tr, this message translates to:
  /// **'Kanola Yağı'**
  String get filterCanola;

  /// No description provided for @filterCanolaDesc.
  ///
  /// In tr, this message translates to:
  /// **'Kanola / Kolza yağını filtreler.'**
  String get filterCanolaDesc;

  /// No description provided for @filterMsg.
  ///
  /// In tr, this message translates to:
  /// **'Çin Tuzu (MSG)'**
  String get filterMsg;

  /// No description provided for @filterMsgDesc.
  ///
  /// In tr, this message translates to:
  /// **'Monosodyum glutamat vb. aroma artırıcılar.'**
  String get filterMsgDesc;

  /// No description provided for @filterAspartame.
  ///
  /// In tr, this message translates to:
  /// **'Yapay Tatlandırıcı (Aspartam vb.)'**
  String get filterAspartame;

  /// No description provided for @filterAspartameDesc.
  ///
  /// In tr, this message translates to:
  /// **'Aspartam, sukraloz, asesülfam vb. tatlandırıcılar.'**
  String get filterAspartameDesc;

  /// No description provided for @filterHfcs.
  ///
  /// In tr, this message translates to:
  /// **'Nişasta Bazlı Şeker (NBŞ)'**
  String get filterHfcs;

  /// No description provided for @filterHfcsDesc.
  ///
  /// In tr, this message translates to:
  /// **'Mısır şurubu, glikoz-fruktoz şurubu.'**
  String get filterHfcsDesc;

  /// No description provided for @filterNitrite.
  ///
  /// In tr, this message translates to:
  /// **'Nitrit / Nitrat (Koruyucular)'**
  String get filterNitrite;

  /// No description provided for @filterNitriteDesc.
  ///
  /// In tr, this message translates to:
  /// **'E250 vb. işlenmiş et koruyucuları.'**
  String get filterNitriteDesc;

  /// No description provided for @filterColorant.
  ///
  /// In tr, this message translates to:
  /// **'Yapay Renklendiriciler'**
  String get filterColorant;

  /// No description provided for @filterColorantDesc.
  ///
  /// In tr, this message translates to:
  /// **'E1 serisi renklendiriciler ve boyalar.'**
  String get filterColorantDesc;

  /// No description provided for @personalFilterWarning.
  ///
  /// In tr, this message translates to:
  /// **'Kişisel Filtre Uyarısı'**
  String get personalFilterWarning;

  /// No description provided for @containsFilteredItem.
  ///
  /// In tr, this message translates to:
  /// **'\"{filterName}\" içerir.'**
  String containsFilteredItem(Object filterName);

  /// No description provided for @tabBarcode.
  ///
  /// In tr, this message translates to:
  /// **'Barkod'**
  String get tabBarcode;

  /// No description provided for @tabAiAnalysis.
  ///
  /// In tr, this message translates to:
  /// **'AI Analiz'**
  String get tabAiAnalysis;

  /// No description provided for @aiAnalysisHint.
  ///
  /// In tr, this message translates to:
  /// **'Yemeği çerçeve içine alın'**
  String get aiAnalysisHint;

  /// No description provided for @aiAnalyzing.
  ///
  /// In tr, this message translates to:
  /// **'AI analiz ediyor...'**
  String get aiAnalyzing;

  /// No description provided for @aiAnalysisResult.
  ///
  /// In tr, this message translates to:
  /// **'AI Analiz Sonucu'**
  String get aiAnalysisResult;

  /// No description provided for @aiEstimatedPortion.
  ///
  /// In tr, this message translates to:
  /// **'Tahmini porsiyon'**
  String get aiEstimatedPortion;

  /// No description provided for @aiConfidence.
  ///
  /// In tr, this message translates to:
  /// **'AI Doğruluk Tahmini'**
  String get aiConfidence;

  /// No description provided for @aiSaveToHistory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmişe Kaydet'**
  String get aiSaveToHistory;

  /// No description provided for @aiRetake.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Çek'**
  String get aiRetake;

  /// No description provided for @aiSaved.
  ///
  /// In tr, this message translates to:
  /// **'AI analiz sonucu kaydedildi'**
  String get aiSaved;

  /// No description provided for @aiFailed.
  ///
  /// In tr, this message translates to:
  /// **'AI analiz başarısız oldu. Tekrar deneyin.'**
  String get aiFailed;

  /// No description provided for @aiServiceUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'AI servisi şu an çalışmıyor — yedek tarama kullanılıyor, sonuçlar daha az hassas olabilir.'**
  String get aiServiceUnavailable;

  /// No description provided for @aiServiceUnavailableNoFallback.
  ///
  /// In tr, this message translates to:
  /// **'AI servisi şu an çalışmıyor. Lütfen birkaç dakika sonra tekrar deneyin.'**
  String get aiServiceUnavailableNoFallback;

  /// No description provided for @aiServiceDownTitle.
  ///
  /// In tr, this message translates to:
  /// **'AI Servisi Çalışmıyor'**
  String get aiServiceDownTitle;

  /// No description provided for @aiServiceDownBody.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler okuma servisi şu an yanıt vermiyor. Birkaç dakika sonra tekrar deneyin ya da içindekileri elle girin.'**
  String get aiServiceDownBody;

  /// No description provided for @manualEntry.
  ///
  /// In tr, this message translates to:
  /// **'Elle Gir'**
  String get manualEntry;

  /// No description provided for @tryAgain.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get tryAgain;

  /// No description provided for @aiLowConfidence.
  ///
  /// In tr, this message translates to:
  /// **'Düşük güven — sonuçlar tahminidir'**
  String get aiLowConfidence;

  /// No description provided for @aiEstimate.
  ///
  /// In tr, this message translates to:
  /// **'AI Tahmin'**
  String get aiEstimate;

  /// No description provided for @aiPackagedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Paketli Ürün Algılandı'**
  String get aiPackagedTitle;

  /// No description provided for @aiPackagedBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu bir paketli market ürünü gibi görünüyor. Doğru sağlık puanı için barkodunu okutmanı öneririz. Yine de yemek olarak analiz etmek istersen devam edebilirsin.'**
  String get aiPackagedBody;

  /// No description provided for @aiAnalyzeAnyway.
  ///
  /// In tr, this message translates to:
  /// **'Yine de analiz et'**
  String get aiAnalyzeAnyway;

  /// No description provided for @carbohydrates.
  ///
  /// In tr, this message translates to:
  /// **'Karbonhidrat'**
  String get carbohydrates;

  /// No description provided for @description.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get description;

  /// No description provided for @turkishCodex.
  ///
  /// In tr, this message translates to:
  /// **'Türk Kodeksi'**
  String get turkishCodex;

  /// No description provided for @riskLevel.
  ///
  /// In tr, this message translates to:
  /// **'Risk Seviyesi'**
  String get riskLevel;

  /// No description provided for @dietarySuitability.
  ///
  /// In tr, this message translates to:
  /// **'Diyet Uygunluğu'**
  String get dietarySuitability;

  /// No description provided for @vegan.
  ///
  /// In tr, this message translates to:
  /// **'Vegan'**
  String get vegan;

  /// No description provided for @vegetarian.
  ///
  /// In tr, this message translates to:
  /// **'Vejetaryen'**
  String get vegetarian;

  /// No description provided for @halal.
  ///
  /// In tr, this message translates to:
  /// **'Helal'**
  String get halal;

  /// No description provided for @bannedAdditive.
  ///
  /// In tr, this message translates to:
  /// **'Bu katkı maddesi EFSA veya Türk Gıda Kodeksi tarafından yasaklanmıştır.'**
  String get bannedAdditive;

  /// No description provided for @counterfeitWarningTitle.
  ///
  /// In tr, this message translates to:
  /// **'UYARI: Taklit/Tağşiş Listesinde!'**
  String get counterfeitWarningTitle;

  /// No description provided for @counterfeitViewSource.
  ///
  /// In tr, this message translates to:
  /// **'Tarım Bakanlığı kaynağını görüntüle'**
  String get counterfeitViewSource;

  /// No description provided for @counterfeitSyncing.
  ///
  /// In tr, this message translates to:
  /// **'Taklit ürün listesi güncelleniyor...'**
  String get counterfeitSyncing;

  /// No description provided for @noCounterfeitFound.
  ///
  /// In tr, this message translates to:
  /// **'Taklit ürün listesinde bulunamadı'**
  String get noCounterfeitFound;

  /// No description provided for @gaugeExcellent.
  ///
  /// In tr, this message translates to:
  /// **'Mükemmel'**
  String get gaugeExcellent;

  /// No description provided for @gaugeGood.
  ///
  /// In tr, this message translates to:
  /// **'İyi'**
  String get gaugeGood;

  /// No description provided for @gaugeModerate.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get gaugeModerate;

  /// No description provided for @gaugeWeak.
  ///
  /// In tr, this message translates to:
  /// **'Zayıf'**
  String get gaugeWeak;

  /// No description provided for @gaugeBad.
  ///
  /// In tr, this message translates to:
  /// **'Kötü'**
  String get gaugeBad;

  /// No description provided for @hpScoreLabel.
  ///
  /// In tr, this message translates to:
  /// **'HP Puanı'**
  String get hpScoreLabel;

  /// No description provided for @allergenWarningTitle.
  ///
  /// In tr, this message translates to:
  /// **'UYARI: Alerjen İçeriyor'**
  String get allergenWarningTitle;

  /// No description provided for @continueAsGuest.
  ///
  /// In tr, this message translates to:
  /// **'Misafir olarak devam et'**
  String get continueAsGuest;

  /// No description provided for @guestUser.
  ///
  /// In tr, this message translates to:
  /// **'Misafir Kullanıcısı'**
  String get guestUser;

  /// No description provided for @guestDataLocal.
  ///
  /// In tr, this message translates to:
  /// **'Verilerin sadece bu cihazda'**
  String get guestDataLocal;

  /// No description provided for @createAccountBackupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap aç, verilerini yedekle'**
  String get createAccountBackupTitle;

  /// No description provided for @createAccountBackupSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Tarama geçmişin, öğünlerin her cihazda'**
  String get createAccountBackupSubtitle;

  /// No description provided for @guestLastFreeScan.
  ///
  /// In tr, this message translates to:
  /// **'Son ücretsiz taraman. Kayıt olursan tüm geçmişin saklanır.'**
  String get guestLastFreeScan;

  /// No description provided for @guestScanLimitTitle.
  ///
  /// In tr, this message translates to:
  /// **'5 ücretsiz tarama bitti'**
  String get guestScanLimitTitle;

  /// No description provided for @guestScanLimitMessage.
  ///
  /// In tr, this message translates to:
  /// **'Hesap açtığında tarama hakkın yenilenir, geçmişin ve öğünlerin her cihazda görünür.'**
  String get guestScanLimitMessage;

  /// No description provided for @guestFeatureLockedTitle.
  ///
  /// In tr, this message translates to:
  /// **'{feature} için hesap gerekli'**
  String guestFeatureLockedTitle(String feature);

  /// No description provided for @guestFeatureLockedMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu özellik bulutta saklanır. Hesap açıp giriş yapınca aktif olur.'**
  String get guestFeatureLockedMessage;

  /// No description provided for @createAccountCta.
  ///
  /// In tr, this message translates to:
  /// **'Hesap aç'**
  String get createAccountCta;

  /// No description provided for @notNow.
  ///
  /// In tr, this message translates to:
  /// **'Şu an değil'**
  String get notNow;

  /// No description provided for @featureFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get featureFavorites;

  /// No description provided for @featureBlacklist.
  ///
  /// In tr, this message translates to:
  /// **'Kara liste'**
  String get featureBlacklist;

  /// No description provided for @featurePremium.
  ///
  /// In tr, this message translates to:
  /// **'Premium'**
  String get featurePremium;

  /// No description provided for @featureAddProduct.
  ///
  /// In tr, this message translates to:
  /// **'Ürün ekleme'**
  String get featureAddProduct;

  /// No description provided for @migrationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Misafir verilerin var'**
  String get migrationTitle;

  /// No description provided for @migrationMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda {dataLine} bulunuyor. Bunları yeni hesabına yükleyelim mi?'**
  String migrationMessage(String dataLine);

  /// No description provided for @migrationYes.
  ///
  /// In tr, this message translates to:
  /// **'Evet, hesabıma yükle'**
  String get migrationYes;

  /// No description provided for @migrationNo.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırdan başla'**
  String get migrationNo;

  /// No description provided for @scanCountUnit.
  ///
  /// In tr, this message translates to:
  /// **'{count} tarama'**
  String scanCountUnit(int count);

  /// No description provided for @mealCountUnit.
  ///
  /// In tr, this message translates to:
  /// **'{count} öğün'**
  String mealCountUnit(int count);

  /// No description provided for @forgotPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifremi unuttum'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In tr, this message translates to:
  /// **'Şifreni mi unuttun?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabına bağlı email adresini gir, sıfırlama bağlantısı gönderelim.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendResetLink.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırlama bağlantısı gönder'**
  String get sendResetLink;

  /// No description provided for @resetLinkSentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı gönderildi'**
  String get resetLinkSentTitle;

  /// No description provided for @resetLinkSentMessage.
  ///
  /// In tr, this message translates to:
  /// **'Email kutunu kontrol et. Bağlantıya dokunarak yeni şifreni belirleyebilirsin.'**
  String get resetLinkSentMessage;

  /// No description provided for @backToLogin.
  ///
  /// In tr, this message translates to:
  /// **'Girişe dön'**
  String get backToLogin;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre belirle'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabını korumak için güçlü bir şifre seç.'**
  String get resetPasswordSubtitle;

  /// No description provided for @newPassword.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre'**
  String get newPassword;

  /// No description provided for @updatePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi güncelle'**
  String get updatePassword;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In tr, this message translates to:
  /// **'Şifreler eşleşmiyor'**
  String get passwordsDontMatch;

  /// No description provided for @passwordUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Şifren güncellendi'**
  String get passwordUpdated;

  /// No description provided for @enterPasswordAgain.
  ///
  /// In tr, this message translates to:
  /// **'Şifre tekrar girin'**
  String get enterPasswordAgain;

  /// No description provided for @guestScanCounter.
  ///
  /// In tr, this message translates to:
  /// **'{remaining}/5 ücretsiz tarama'**
  String guestScanCounter(int remaining);

  /// No description provided for @appVersion.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm'**
  String get appVersion;

  /// No description provided for @testCrashReporting.
  ///
  /// In tr, this message translates to:
  /// **'Crash raporlamayı test et'**
  String get testCrashReporting;

  /// No description provided for @myMeals.
  ///
  /// In tr, this message translates to:
  /// **'Öğünlerim'**
  String get myMeals;

  /// No description provided for @mealsLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Öğünler yüklenemedi.'**
  String get mealsLoadError;

  /// No description provided for @summaryToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get summaryToday;

  /// No description provided for @summaryWeek.
  ///
  /// In tr, this message translates to:
  /// **'Hafta'**
  String get summaryWeek;

  /// No description provided for @summaryMonth.
  ///
  /// In tr, this message translates to:
  /// **'Ay'**
  String get summaryMonth;

  /// No description provided for @scoreLabel.
  ///
  /// In tr, this message translates to:
  /// **'Skor'**
  String get scoreLabel;

  /// No description provided for @deleteMealTitle.
  ///
  /// In tr, this message translates to:
  /// **'Öğünü sil'**
  String get deleteMealTitle;

  /// No description provided for @deleteMealConfirm.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" silinsin mi?'**
  String deleteMealConfirm(String name);

  /// No description provided for @noMealsYet.
  ///
  /// In tr, this message translates to:
  /// **'Henüz öğün yok'**
  String get noMealsYet;

  /// No description provided for @noMealsHint.
  ///
  /// In tr, this message translates to:
  /// **'Tarama ekranındaki AI Analizi ile yemeğini fotoğraflayıp buraya kaydedebilirsin.'**
  String get noMealsHint;

  /// No description provided for @ingredientsTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçerik'**
  String get ingredientsTitle;

  /// No description provided for @confidenceSuffix.
  ///
  /// In tr, this message translates to:
  /// **'güven'**
  String get confidenceSuffix;

  /// No description provided for @aiConfidenceHint.
  ///
  /// In tr, this message translates to:
  /// **'Yapay zekânın tespit ettiği yemek, porsiyon ve kalori tahmininden ne kadar emin olduğunu gösterir.'**
  String get aiConfidenceHint;

  /// No description provided for @risk1.
  ///
  /// In tr, this message translates to:
  /// **'Risksiz'**
  String get risk1;

  /// No description provided for @risk2.
  ///
  /// In tr, this message translates to:
  /// **'Az riskli'**
  String get risk2;

  /// No description provided for @risk3.
  ///
  /// In tr, this message translates to:
  /// **'Orta riskli'**
  String get risk3;

  /// No description provided for @risk4.
  ///
  /// In tr, this message translates to:
  /// **'Riskli'**
  String get risk4;

  /// No description provided for @risk5.
  ///
  /// In tr, this message translates to:
  /// **'Çok riskli'**
  String get risk5;

  /// No description provided for @mealSavedToast.
  ///
  /// In tr, this message translates to:
  /// **'Öğün kaydedildi'**
  String get mealSavedToast;

  /// No description provided for @mealNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Öğün adı'**
  String get mealNameLabel;

  /// No description provided for @mealSourceLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak'**
  String get mealSourceLabel;

  /// No description provided for @estimatedContent.
  ///
  /// In tr, this message translates to:
  /// **'Tahmini içerik'**
  String get estimatedContent;

  /// No description provided for @recalculate.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden Hesapla'**
  String get recalculate;

  /// No description provided for @recalcHint.
  ///
  /// In tr, this message translates to:
  /// **'İçeriği düzenle ve/veya porsiyon notu ekle; ikisini de hesaba katar.'**
  String get recalcHint;

  /// No description provided for @saveToMeals.
  ///
  /// In tr, this message translates to:
  /// **'Öğünlere kaydet'**
  String get saveToMeals;

  /// No description provided for @portionQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Ne kadar yedin?'**
  String get portionQuestion;

  /// No description provided for @portionLittle.
  ///
  /// In tr, this message translates to:
  /// **'Az'**
  String get portionLittle;

  /// No description provided for @portionNormal.
  ///
  /// In tr, this message translates to:
  /// **'Normal'**
  String get portionNormal;

  /// No description provided for @portionLots.
  ///
  /// In tr, this message translates to:
  /// **'Bol'**
  String get portionLots;

  /// No description provided for @portionTwoServings.
  ///
  /// In tr, this message translates to:
  /// **'İki kişilik'**
  String get portionTwoServings;

  /// No description provided for @recalcFailedNutrition.
  ///
  /// In tr, this message translates to:
  /// **'Besin değerleri hesaplanamadı, tekrar dene.'**
  String get recalcFailedNutrition;

  /// No description provided for @recalcFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden hesaplama başarısız.'**
  String get recalcFailed;

  /// No description provided for @mealTypeBreakfast.
  ///
  /// In tr, this message translates to:
  /// **'Kahvaltı'**
  String get mealTypeBreakfast;

  /// No description provided for @mealTypeLunch.
  ///
  /// In tr, this message translates to:
  /// **'Öğlen Yemeği'**
  String get mealTypeLunch;

  /// No description provided for @mealTypeDinner.
  ///
  /// In tr, this message translates to:
  /// **'Akşam Yemeği'**
  String get mealTypeDinner;

  /// No description provided for @mealTypeSnack.
  ///
  /// In tr, this message translates to:
  /// **'Ara Öğün'**
  String get mealTypeSnack;

  /// No description provided for @mealBrandHomemade.
  ///
  /// In tr, this message translates to:
  /// **'Ev yapımı'**
  String get mealBrandHomemade;

  /// No description provided for @mealBrandReadyMade.
  ///
  /// In tr, this message translates to:
  /// **'Hazır Gıda'**
  String get mealBrandReadyMade;

  /// No description provided for @additiveNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Bu katkı maddesi hakkında bilgi bulunamadı.'**
  String get additiveNotFound;

  /// No description provided for @dietarySuitabilityNote.
  ///
  /// In tr, this message translates to:
  /// **'Tespit edilen katkı ve içeriklerden tahmin edilmiştir — sertifika değildir.'**
  String get dietarySuitabilityNote;

  /// No description provided for @aiQuotaExhausted.
  ///
  /// In tr, this message translates to:
  /// **'AI analizi yoğunluk nedeniyle geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.'**
  String get aiQuotaExhausted;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta zaten kayıtlı — giriş yapmayı veya \'Şifremi unuttum\'u deneyin.'**
  String get emailAlreadyRegistered;

  /// No description provided for @verificationEmailResent.
  ///
  /// In tr, this message translates to:
  /// **'Yeni doğrulama maili gönderildi'**
  String get verificationEmailResent;

  /// No description provided for @emailSendFailed.
  ///
  /// In tr, this message translates to:
  /// **'Mail gönderilemedi: {error}'**
  String emailSendFailed(Object error);

  /// No description provided for @emailHint.
  ///
  /// In tr, this message translates to:
  /// **'ornek@email.com'**
  String get emailHint;

  /// No description provided for @orSeparator.
  ///
  /// In tr, this message translates to:
  /// **'ya da'**
  String get orSeparator;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabın var mı?'**
  String get alreadyHaveAccount;

  /// No description provided for @verifyYourEmail.
  ///
  /// In tr, this message translates to:
  /// **'Email adresini doğrula'**
  String get verifyYourEmail;

  /// No description provided for @verificationLinkPrefix.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama bağlantısı '**
  String get verificationLinkPrefix;

  /// No description provided for @verificationLinkSuffix.
  ///
  /// In tr, this message translates to:
  /// **' adresine gönderildi. Bağlantıya **telefonundan** dokun, hesabın aktif olsun.'**
  String get verificationLinkSuffix;

  /// No description provided for @checkSpamFolder.
  ///
  /// In tr, this message translates to:
  /// **'Spam / Gereksiz klasörünü de kontrol et. Yeni gönderici domaini olduğu için bazı sağlayıcılar ilk maili oraya atabilir.'**
  String get checkSpamFolder;

  /// No description provided for @resendEmail.
  ///
  /// In tr, this message translates to:
  /// **'Maili tekrar gönder'**
  String get resendEmail;

  /// No description provided for @scanLimitNetworkError.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı kurulamadı. Tarama limitini doğrulamak için internete bağlan.'**
  String get scanLimitNetworkError;

  /// No description provided for @editIngredientsHint.
  ///
  /// In tr, this message translates to:
  /// **'İçerik ekle veya düzenle...'**
  String get editIngredientsHint;

  /// No description provided for @portionNoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Porsiyon notu (opsiyonel)'**
  String get portionNoteLabel;

  /// No description provided for @portionNoteHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn: \"yarım porsiyon\" · \"tabağın yarısı kaldı, full hesapla\" · \"300 g yedim\"'**
  String get portionNoteHint;

  /// No description provided for @favoritesLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler yüklenemedi'**
  String get favoritesLoadError;

  /// No description provided for @ocrPreparingImage.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf hazırlanıyor...'**
  String get ocrPreparingImage;

  /// No description provided for @ocrAnalyzingWithAi.
  ///
  /// In tr, this message translates to:
  /// **'Yapay zeka ile analiz ediliyor...'**
  String get ocrAnalyzingWithAi;

  /// No description provided for @ocrFillingForm.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçlar forma yazılıyor...'**
  String get ocrFillingForm;

  /// No description provided for @premiumTitle.
  ///
  /// In tr, this message translates to:
  /// **'NutriLens Premium'**
  String get premiumTitle;

  /// No description provided for @premiumRestore.
  ///
  /// In tr, this message translates to:
  /// **'Geri Yükle'**
  String get premiumRestore;

  /// No description provided for @premiumActivated.
  ///
  /// In tr, this message translates to:
  /// **'Premium aktif! 🎉'**
  String get premiumActivated;

  /// No description provided for @premiumFeatureUnlimitedScans.
  ///
  /// In tr, this message translates to:
  /// **'Sınırsız tarama'**
  String get premiumFeatureUnlimitedScans;

  /// No description provided for @premiumFeatureNoAds.
  ///
  /// In tr, this message translates to:
  /// **'Reklamsız deneyim'**
  String get premiumFeatureNoAds;

  /// No description provided for @premiumFeatureUnlimitedAi.
  ///
  /// In tr, this message translates to:
  /// **'Sınırsız AI tarama'**
  String get premiumFeatureUnlimitedAi;

  /// No description provided for @premiumFeaturePrioritySupport.
  ///
  /// In tr, this message translates to:
  /// **'Öncelikli destek'**
  String get premiumFeaturePrioritySupport;

  /// No description provided for @premiumPlanAnnual.
  ///
  /// In tr, this message translates to:
  /// **'Yıllık'**
  String get premiumPlanAnnual;

  /// No description provided for @premiumPlanMonthly.
  ///
  /// In tr, this message translates to:
  /// **'Aylık'**
  String get premiumPlanMonthly;

  /// No description provided for @premiumPerMonth.
  ///
  /// In tr, this message translates to:
  /// **'{price}/ay'**
  String premiumPerMonth(Object price);

  /// No description provided for @premiumBilledAnnually.
  ///
  /// In tr, this message translates to:
  /// **'Yıllık {price} olarak faturalandırılır'**
  String premiumBilledAnnually(Object price);

  /// No description provided for @premiumSaveBadge.
  ///
  /// In tr, this message translates to:
  /// **'%{percent} tasarruf'**
  String premiumSaveBadge(Object percent);

  /// No description provided for @premiumMostPopular.
  ///
  /// In tr, this message translates to:
  /// **'En popüler'**
  String get premiumMostPopular;

  /// No description provided for @premiumTrialBadge.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün ücretsiz'**
  String premiumTrialBadge(Object days);

  /// No description provided for @premiumTrialCta.
  ///
  /// In tr, this message translates to:
  /// **'{days} Gün Ücretsiz Dene'**
  String premiumTrialCta(Object days);

  /// No description provided for @premiumContinueCta.
  ///
  /// In tr, this message translates to:
  /// **'Premium\'a Geç'**
  String get premiumContinueCta;

  /// No description provided for @premiumAutoRenewNote.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik otomatik yenilenir. İstediğin zaman iptal edebilirsin.'**
  String get premiumAutoRenewNote;

  /// No description provided for @premiumTrialAutoRenewNote.
  ///
  /// In tr, this message translates to:
  /// **'Deneme bittiğinde ücretli aboneliğe geçer. Deneme süresince istediğin zaman iptal edebilirsin.'**
  String get premiumTrialAutoRenewNote;

  /// No description provided for @premiumTrustCancelAnytime.
  ///
  /// In tr, this message translates to:
  /// **'İstediğin an iptal'**
  String get premiumTrustCancelAnytime;

  /// No description provided for @premiumTrustSecurePayment.
  ///
  /// In tr, this message translates to:
  /// **'Google Play güvencesi'**
  String get premiumTrustSecurePayment;

  /// No description provided for @premiumTrustInstantAccess.
  ///
  /// In tr, this message translates to:
  /// **'Anında erişim'**
  String get premiumTrustInstantAccess;

  /// No description provided for @premiumPackagesLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik paketleri yüklenemedi.\nİnternet bağlantınızı kontrol edin.'**
  String get premiumPackagesLoadError;

  /// No description provided for @premiumPackagesUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Paketler yüklenemedi.'**
  String get premiumPackagesUnavailable;

  /// No description provided for @premiumPurchaseFailed.
  ///
  /// In tr, this message translates to:
  /// **'Satın alma tamamlanamadı. Lütfen tekrar deneyin.'**
  String get premiumPurchaseFailed;

  /// No description provided for @premiumPurchaseUnexpectedError.
  ///
  /// In tr, this message translates to:
  /// **'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.'**
  String get premiumPurchaseUnexpectedError;

  /// No description provided for @premiumRestored.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik geri yüklendi!'**
  String get premiumRestored;

  /// No description provided for @premiumNoActiveSubscription.
  ///
  /// In tr, this message translates to:
  /// **'Aktif abonelik bulunamadı.'**
  String get premiumNoActiveSubscription;

  /// No description provided for @premiumErrorNetwork.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantınızı kontrol edin.'**
  String get premiumErrorNetwork;

  /// No description provided for @premiumErrorPaymentPending.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme onay bekliyor. Birkaç dakika içinde aktifleşecek.'**
  String get premiumErrorPaymentPending;

  /// No description provided for @premiumErrorProductUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu ürün şu anda satın alınamıyor.'**
  String get premiumErrorProductUnavailable;

  /// No description provided for @premiumErrorAlreadyPurchased.
  ///
  /// In tr, this message translates to:
  /// **'Bu abonelik zaten aktif. \"Geri Yükle\" seçeneğini deneyin.'**
  String get premiumErrorAlreadyPurchased;

  /// No description provided for @premiumErrorStoreProblem.
  ///
  /// In tr, this message translates to:
  /// **'Play Store geçici bir sorun yaşıyor. Lütfen tekrar deneyin.'**
  String get premiumErrorStoreProblem;

  /// No description provided for @premiumPrivacyPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get premiumPrivacyPolicy;

  /// No description provided for @premiumTermsOfUse.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşulları'**
  String get premiumTermsOfUse;

  /// No description provided for @scanLimitTitle.
  ///
  /// In tr, this message translates to:
  /// **'Günlük Tarama Hakkın Doldu'**
  String get scanLimitTitle;

  /// No description provided for @scanLimitSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Premium üyelikle sınırsız tarama yapabilirsin.'**
  String get scanLimitSubtitle;

  /// No description provided for @scanLimitGoPremium.
  ///
  /// In tr, this message translates to:
  /// **'Premium\'a Geç'**
  String get scanLimitGoPremium;

  /// No description provided for @scanLimitWatchAd.
  ///
  /// In tr, this message translates to:
  /// **'Reklam İzle → +1 Tarama'**
  String get scanLimitWatchAd;

  /// No description provided for @scanLimitClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get scanLimitClose;

  /// No description provided for @enterBarcodeManually.
  ///
  /// In tr, this message translates to:
  /// **'Barkodu El ile Girin'**
  String get enterBarcodeManually;

  /// No description provided for @barcodeInputHint.
  ///
  /// In tr, this message translates to:
  /// **'8 veya 13 haneli barkod girin'**
  String get barcodeInputHint;

  /// No description provided for @barcodeInputLabel.
  ///
  /// In tr, this message translates to:
  /// **'Barkod'**
  String get barcodeInputLabel;

  /// No description provided for @search.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get search;

  /// No description provided for @startFree.
  ///
  /// In tr, this message translates to:
  /// **'Ücretsiz başla'**
  String get startFree;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabım var'**
  String get alreadyHaveAccountSignIn;

  /// No description provided for @addProductIntro.
  ///
  /// In tr, this message translates to:
  /// **'Bu ürün henüz veritabanımızda yok.\nBilgileri girerek topluluk veritabanına ekleyebilirsiniz!'**
  String get addProductIntro;

  /// No description provided for @productPhotoOptional.
  ///
  /// In tr, this message translates to:
  /// **'Ürün Fotoğrafı (opsiyonel)'**
  String get productPhotoOptional;

  /// No description provided for @productNameHint.
  ///
  /// In tr, this message translates to:
  /// **'örn: Ülker Çikolatalı Gofret'**
  String get productNameHint;

  /// No description provided for @brandHint.
  ///
  /// In tr, this message translates to:
  /// **'örn: Ülker'**
  String get brandHint;

  /// No description provided for @completeWithPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileri Fotoğrafla Tamamla'**
  String get completeWithPhoto;

  /// No description provided for @invalidECodeFormat.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz E kodu formatı (örn: E471)'**
  String get invalidECodeFormat;

  /// No description provided for @productAddedToDb.
  ///
  /// In tr, this message translates to:
  /// **'Bu ürünü veritabanımıza eklediniz!'**
  String get productAddedToDb;

  /// No description provided for @manualEntryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Manuel Giriş'**
  String get manualEntryTitle;

  /// No description provided for @ingredientsTextOptional.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler Metni (opsiyonel)'**
  String get ingredientsTextOptional;

  /// No description provided for @ingredientsPasteHint.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler listesini buraya yapıştırın...'**
  String get ingredientsPasteHint;

  /// No description provided for @additivesECodes.
  ///
  /// In tr, this message translates to:
  /// **'Katkı Maddeleri (E Kodları)'**
  String get additivesECodes;

  /// No description provided for @tapToRemove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldırmak için dokunun'**
  String get tapToRemove;

  /// No description provided for @saveAction.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get saveAction;

  /// No description provided for @verifyIngredientsTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçerik Doğrulama'**
  String get verifyIngredientsTitle;

  /// No description provided for @ocrIngredientsHint.
  ///
  /// In tr, this message translates to:
  /// **'OCR ile okunan içindekiler metni...'**
  String get ocrIngredientsHint;

  /// No description provided for @hideRawOcr.
  ///
  /// In tr, this message translates to:
  /// **'Ham OCR metnini gizle'**
  String get hideRawOcr;

  /// No description provided for @showRawOcr.
  ///
  /// In tr, this message translates to:
  /// **'Ham OCR metnini göster'**
  String get showRawOcr;

  /// No description provided for @detectedAdditives.
  ///
  /// In tr, this message translates to:
  /// **'Tespit Edilen Katkı Maddeleri'**
  String get detectedAdditives;

  /// No description provided for @unknownECodes.
  ///
  /// In tr, this message translates to:
  /// **'Veritabanında Bulunamayan E Kodları'**
  String get unknownECodes;

  /// No description provided for @ocrConfidence.
  ///
  /// In tr, this message translates to:
  /// **'OCR Güvenilirlik: %{percent}'**
  String ocrConfidence(String percent);

  /// No description provided for @retakePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Çek'**
  String get retakePhoto;

  /// No description provided for @confirmAndSave.
  ///
  /// In tr, this message translates to:
  /// **'Onayla ve Kaydet'**
  String get confirmAndSave;

  /// No description provided for @ingredientsSectionNotFound.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler Bölümü Bulunamadı'**
  String get ingredientsSectionNotFound;

  /// No description provided for @ingredientsSectionNotFoundBody.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafta \"İçindekiler:\" yazan bölüm okunamadı. Lütfen:\n\n• Paketi düz tutun (yazılar yatay olsun)\n• İçindekiler yazan kısmı ortalayın\n• Işık yansımasından kaçının\n• Yazı net ve okunabilir mesafede olsun'**
  String get ingredientsSectionNotFoundBody;

  /// No description provided for @textUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Metin Okunamadı'**
  String get textUnreadable;

  /// No description provided for @textUnreadableBody.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler listesi okunamadı. Lütfen daha yakın ve net bir fotoğraf çekin.'**
  String get textUnreadableBody;

  /// No description provided for @ingredientsPhotoTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler Fotoğrafı'**
  String get ingredientsPhotoTitle;

  /// No description provided for @analyzingIngredients.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler analiz ediliyor...'**
  String get analyzingIngredients;

  /// No description provided for @photographIngredientsList.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler listesinin fotoğrafını çekin'**
  String get photographIngredientsList;

  /// No description provided for @tipHoldFlat.
  ///
  /// In tr, this message translates to:
  /// **'Paketi düz tutun, yazılar yatay olsun'**
  String get tipHoldFlat;

  /// No description provided for @tipCenterIngredients.
  ///
  /// In tr, this message translates to:
  /// **'\"İçindekiler\" yazan bölümü ortalayın'**
  String get tipCenterIngredients;

  /// No description provided for @tipAvoidGlare.
  ///
  /// In tr, this message translates to:
  /// **'Parlama/yansımadan kaçının'**
  String get tipAvoidGlare;

  /// No description provided for @tipZoomIn.
  ///
  /// In tr, this message translates to:
  /// **'Yazılar net okunabilsin — yakınlaşın'**
  String get tipZoomIn;

  /// No description provided for @genericErrorWith.
  ///
  /// In tr, this message translates to:
  /// **'Hata: {error}'**
  String genericErrorWith(Object error);

  /// No description provided for @welcomeBack.
  ///
  /// In tr, this message translates to:
  /// **'Hoş geldin'**
  String get welcomeBack;

  /// No description provided for @nutritionFacts100g.
  ///
  /// In tr, this message translates to:
  /// **'Besin Değerleri (100g)'**
  String get nutritionFacts100g;

  /// No description provided for @energyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Enerji'**
  String get energyLabel;

  /// No description provided for @carbohydrateShort.
  ///
  /// In tr, this message translates to:
  /// **'Karbonhidrat'**
  String get carbohydrateShort;

  /// No description provided for @noIngredientInfo.
  ///
  /// In tr, this message translates to:
  /// **'İçerik bilgisi mevcut değil'**
  String get noIngredientInfo;

  /// No description provided for @collapse.
  ///
  /// In tr, this message translates to:
  /// **'Daralt'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In tr, this message translates to:
  /// **'Genişlet'**
  String get expand;

  /// No description provided for @riskLow.
  ///
  /// In tr, this message translates to:
  /// **'Düşük Risk'**
  String get riskLow;

  /// No description provided for @riskAcceptable.
  ///
  /// In tr, this message translates to:
  /// **'Kabul Edilebilir'**
  String get riskAcceptable;

  /// No description provided for @riskModerate.
  ///
  /// In tr, this message translates to:
  /// **'Orta Risk'**
  String get riskModerate;

  /// No description provided for @riskHigh.
  ///
  /// In tr, this message translates to:
  /// **'Yüksek Risk'**
  String get riskHigh;

  /// No description provided for @riskDangerous.
  ///
  /// In tr, this message translates to:
  /// **'Tehlikeli'**
  String get riskDangerous;

  /// No description provided for @unknownProduct.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen Ürün'**
  String get unknownProduct;

  /// No description provided for @communityContribution.
  ///
  /// In tr, this message translates to:
  /// **'Topluluk Katkısı'**
  String get communityContribution;

  /// No description provided for @partialAnalysisNoNutrition.
  ///
  /// In tr, this message translates to:
  /// **'Besin değerleri bilinmediği için kısmi analiz'**
  String get partialAnalysisNoNutrition;

  /// No description provided for @premiumBenefits.
  ///
  /// In tr, this message translates to:
  /// **'Sınırsız tarama, reklamsız'**
  String get premiumBenefits;

  /// No description provided for @catMilk.
  ///
  /// In tr, this message translates to:
  /// **'Süt'**
  String get catMilk;

  /// No description provided for @catYogurt.
  ///
  /// In tr, this message translates to:
  /// **'Yoğurt'**
  String get catYogurt;

  /// No description provided for @catCheese.
  ///
  /// In tr, this message translates to:
  /// **'Peynir'**
  String get catCheese;

  /// No description provided for @catButterMargarine.
  ///
  /// In tr, this message translates to:
  /// **'Tereyağı / Margarin'**
  String get catButterMargarine;

  /// No description provided for @catBiscuitCracker.
  ///
  /// In tr, this message translates to:
  /// **'Bisküvi / Kraker'**
  String get catBiscuitCracker;

  /// No description provided for @catChocolate.
  ///
  /// In tr, this message translates to:
  /// **'Çikolata'**
  String get catChocolate;

  /// No description provided for @catCandy.
  ///
  /// In tr, this message translates to:
  /// **'Şekerleme'**
  String get catCandy;

  /// No description provided for @catChipsSnack.
  ///
  /// In tr, this message translates to:
  /// **'Cips / Atıştırmalık'**
  String get catChipsSnack;

  /// No description provided for @catNuts.
  ///
  /// In tr, this message translates to:
  /// **'Kuruyemiş'**
  String get catNuts;

  /// No description provided for @catSoda.
  ///
  /// In tr, this message translates to:
  /// **'Gazlı içecek'**
  String get catSoda;

  /// No description provided for @catJuice.
  ///
  /// In tr, this message translates to:
  /// **'Meyve suyu'**
  String get catJuice;

  /// No description provided for @catWater.
  ///
  /// In tr, this message translates to:
  /// **'Su / Maden suyu'**
  String get catWater;

  /// No description provided for @catCoffeeTea.
  ///
  /// In tr, this message translates to:
  /// **'Kahve / Çay'**
  String get catCoffeeTea;

  /// No description provided for @catBread.
  ///
  /// In tr, this message translates to:
  /// **'Ekmek / Unlu mamul'**
  String get catBread;

  /// No description provided for @catCereal.
  ///
  /// In tr, this message translates to:
  /// **'Kahvaltılık gevrek'**
  String get catCereal;

  /// No description provided for @catReadyMeal.
  ///
  /// In tr, this message translates to:
  /// **'Hazır yemek / Konserve'**
  String get catReadyMeal;

  /// No description provided for @catSauce.
  ///
  /// In tr, this message translates to:
  /// **'Sos'**
  String get catSauce;

  /// No description provided for @catJamHoney.
  ///
  /// In tr, this message translates to:
  /// **'Reçel / Bal'**
  String get catJamHoney;

  /// No description provided for @catMeatDeli.
  ///
  /// In tr, this message translates to:
  /// **'Et / Şarküteri'**
  String get catMeatDeli;

  /// No description provided for @catOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get catOther;

  /// No description provided for @catPastaLegumes.
  ///
  /// In tr, this message translates to:
  /// **'Makarna / Bakliyat'**
  String get catPastaLegumes;

  /// No description provided for @catIceCream.
  ///
  /// In tr, this message translates to:
  /// **'Dondurma'**
  String get catIceCream;

  /// No description provided for @subscription.
  ///
  /// In tr, this message translates to:
  /// **'Abonelik'**
  String get subscription;

  /// No description provided for @premiumActive.
  ///
  /// In tr, this message translates to:
  /// **'Premium Aktif'**
  String get premiumActive;

  /// No description provided for @activeStatus.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get activeStatus;

  /// No description provided for @sentryTestEventSent.
  ///
  /// In tr, this message translates to:
  /// **'Sentry test olayı gönderildi ✓'**
  String get sentryTestEventSent;

  /// No description provided for @sentryTestFailed.
  ///
  /// In tr, this message translates to:
  /// **'Sentry testi başarısız: {error}'**
  String sentryTestFailed(String error);

  /// No description provided for @scanFood.
  ///
  /// In tr, this message translates to:
  /// **'Yemek Tara'**
  String get scanFood;

  /// No description provided for @noHistoryScanCta.
  ///
  /// In tr, this message translates to:
  /// **'Barkod Tara'**
  String get noHistoryScanCta;

  /// No description provided for @historyLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş yüklenemedi.'**
  String get historyLoadError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'pt',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
