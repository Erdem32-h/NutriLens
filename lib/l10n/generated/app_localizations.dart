import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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
    Locale('en'),
    Locale('tr'),
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
  /// **'Geçmiş'**
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
  /// **'Şifre Tekrar'**
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
  /// **'YAĞ'**
  String get fatLabel;

  /// No description provided for @sugarLabel.
  ///
  /// In tr, this message translates to:
  /// **'ŞEKER'**
  String get sugarLabel;

  /// No description provided for @saturatedFatLabel.
  ///
  /// In tr, this message translates to:
  /// **'DOYMUŞ YAĞ'**
  String get saturatedFatLabel;

  /// No description provided for @saltLabel.
  ///
  /// In tr, this message translates to:
  /// **'TUZ'**
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
  /// **'İptal'**
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

  /// No description provided for @saveAndView.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet ve Görüntüle'**
  String get saveAndView;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
