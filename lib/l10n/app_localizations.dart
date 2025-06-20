import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_no.dart';

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
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
    Locale('es'),
    Locale('no')
  ];

  // Authentication
  String get appName;
  String get signInToAccessAccount;
  String get createAccount;
  String get signUpToStart;
  String get email;
  String get password;
  String get signIn;
  String get signUp;
  String get login;
  String get register;
  String get pleaseEnterYourEmail;
  String get pleaseEnterYourPassword;
  String get pleaseEnterValidEmail;
  String get passwordMustBeAtLeast6Characters;
  String get processing;
  String get forgotPassword;

  // Login screen additional
  String get dontHaveAccount;
  String get alreadyHaveAccount;
  String get orContinueWith;
  String get continueWithGoogle;
  String get useBiometrics;
  String get checkEmailVerification;
  String get pleaseEnterValidEmailFirst;
  String get termsAndPrivacy;

  // Login messages and errors
  String get emailAuthServiceNotAvailable;
  String get registrationError;
  String get emailVerificationStatus;
  String get verified;
  String get notVerified;
  String get errorCheckingVerification;
  String get unexpectedErrorOccurred;

  // Navigation & Main UI
  String get profile;
  String get settings;
  String get notifications;
  String get home;
  String get allDepartures;
  String get myDepartures;
  String get flightDetails;
  String get archived;
  String get addToMyDepartures;
  String get archiveDepartures;
  String get save;
  String get delete;
  String get restore;
  String get cancel;
  String get edit;
  String get back;
  String get close;
  String get done;
  String get logOut;

  // Flight related
  String get flights;
  String get flight;
  String get noFlightsFound;
  String get showAllFlights;
  String get searchFlights;
  String get filterFlights;
  String get resetFilters;
  String get selectAll;
  String get deselectAll;
  String get gate;
  String get airline;
  String get destination;
  String get departureTime;
  String get scheduledTime;
  String get actualTime;
  String get delayed;
  String get onTime;
  String get cancelled;
  String get departed;

  // Actions & Messages
  String get loading;
  String get error;
  String get success;
  String get noDataAvailable;
  String get refreshData;
  String get lastUpdated;
  String get justNow;
  String get minutesAgo;
  String get hoursAgo;
  String get yesterday;
  String get addedFlights;
  String get restoredFlights;
  String get archivedFlights;
  String get flightSavedSuccessfully;
  String get flightArchivedSuccessfully;
  String get flightRestoredSuccessfully;
  String get flightDeletedSuccessfully;
  String get noSavedFlights;
  String get noArchivedFlights;

  // Settings & Configuration
  String get languageSettings;
  String get selectLanguage;
  String get notificationSettings;
  String get configureNotifications;
  String get delayNotifications;
  String get departureNotifications;
  String get gateChangeNotifications;
  String get developerMode;
  String get dataVisualizationSettings;
  String get preferences;
  String get general;

  // Time formats
  String formatMinutesAgo(int minutes);
  String formatHoursAgo(int hours);
  String formatFlightsCount(int count);
  String formatAddedFlights(int count);
  String formatRestoredFlights(int count);
  String formatArchivedFlights(int count);

  // Confirmation dialogs
  String get confirmDelete;
  String get confirmArchive;
  String get confirmRestore;
  String get areYouSure;
  String get thisActionCannotBeUndone;

  // Norwegian equivalence
  String get showingNorwegianEquivalent;
  String get norwegianEquivalenceTooltip;

  // Settings subtitles
  String get customizeDataDisplaySubtitle;
  String get enableDeveloperModeSubtitle;

  // Bottom navigation
  String get allDeparturesLabel;
  String get myDeparturesLabel;
  String get profileLabel;

  // Flight card
  String get trolley;
  String get trolleysAtGate;
  String get departedShort;

  // Flight details
  String get currentTrolleyCount;
  String get enterQuantity;
  String get deliver;
  String get showHistory;
  String get hideHistory;
  String get noHistoryAvailable;
  String get gateTrolleysHistory;
  String get gateChangeHistory;
  String get noGateChangesRecorded;
  String get confirmDelivery;
  String get confirmDeletion;
  String get pleaseConfirmDelivery;
  String get confirmRegister;
  String get pleaseConfirmRegister;
  String get forFlight;
  String get completed;
  String get errorPrefix;
  String get areYouSureDelete;
  String get deleteAllDeliveries;
  String get deleteAllGateChanges;
  String get trolleysData;
  String get errorLoadingTrolleysData;
  String get noTrolleysDataAvailable;
  String get deliveredAtGate;
  String get pleaseEnterNumber;
  String get pleaseEnterValidNumber;
  String get errorSaving;
  String get deliveryMarkedDeleted;
  String get noDeliveriesToDelete;
  String get allDeliveriesDeleted;
  String get registerTrolleysLeft;

  // Flight details screen
  String get flightTitle;
  String get noDataFoundForFlight;
  String get details;

  // Gate history
  String get showingChangesFrom;
  String get twoHoursBefore;
  String get scheduledDepartureAt;
  String get changedFrom;
  String get to;

  // Flight header
  String get destinationLabel;
  String get newTime;
  String get departedUpper;
  String get cancelledUpper;
  String get delayedUpper;

  // Language settings
  String get languageInfo;
  String get languageChangeInfo;

  // Notifications screen
  String get notificationsDescription;
  String get flightDelayNotifications;
  String get delayNotificationsSubtitle;
  String get flightDepartureNotifications;
  String get departureNotificationsSubtitle;
  String get gateChangeNotificationsSubtitle;

  // Data visualization screen
  String get norwegianDyD8Equivalence;
  String get norwegianDyD8EquivalenceSubtitle;

  // Oversize item registration form
  String get itemTypeLabel;
  String get referenceLabel;
  String get avihReferenceLabel;
  String get descriptionLabel;
  String get passengerNameLabel;
  String get fragileLabel;
  String get requiresSpecialHandlingLabel;
  String get spareItem;
  String get avih;
  String get weap;
  String get pleaseEnterAvihReference;
  String get pleaseEnterPassengerName;

  // Oversize baggage management
  String get oversizeBaggageManagement;
  String get registeredLabel;
  String get deletedLabel;
  String get byLabel;
  String get deleteAllRegistries;
  String get deleteAllRecords;
  String get noRegistriesToDelete;
  String get registriesDeleted;
  String get userNotAuthenticated;
  String get deleteRegistryConfirmation;
  String get deleteAllRegistriesConfirmation;

  // Converted label
  String get convertedLabel;

  // Special handling details
  String get specialHandlingDetails;
  String get enterSpecialHandlingDetails;
  String get specialHandlingPlaceholder;

  // Generic labels
  String get currentLabel;

  // Oversize conversion dialogs
  String get convertToTrolleyTitle;
  String get convertConfirmationMessage; // expects placeholder {count}
  String get convertAction;
  String get noSpareItemsToConvert;
  String get noSpareItemsAvailable;
  String get spareItemsConverted;

  // Oversize info panel
  String get currentOversizeInfo;

  // Gate change notifications
  String get gateChangeNotificationTitle;
  String gateChangeNotificationBody(String flightId, String airline,
      String destination, String oldGate, String newGate, String date);

  // Oversize registration notifications
  String get oversizeRegistrationNotificationTitle;
  String oversizeRegistrationNotificationBody(String itemType, String flightId,
      String airline, String destination, String gate);
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
      <String>['en', 'es', 'no'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'no':
      return AppLocalizationsNo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue on GitHub with a '
      'reproducible sample app and the gen-l10n configuration that was used.');
}
