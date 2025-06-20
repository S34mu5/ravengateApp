import 'app_localizations.dart';

/// The translations for Norwegian (`no`).
class AppLocalizationsNo extends AppLocalizations {
  AppLocalizationsNo([String locale = 'no']) : super(locale);

  // Authentication
  @override
  String get appName => 'RavenGate';

  @override
  String get signInToAccessAccount =>
      'Logg inn for å få tilgang til kontoen din';

  @override
  String get createAccount => 'Opprett konto';

  @override
  String get signUpToStart => 'Registrer deg for å starte';

  @override
  String get email => 'E-post';

  @override
  String get password => 'Passord';

  @override
  String get signIn => 'Logg Inn';

  @override
  String get signUp => 'Registrer';

  @override
  String get login => 'Login';

  @override
  String get register => 'Registrer';

  @override
  String get pleaseEnterYourEmail => 'Vennligst skriv inn e-posten din';

  @override
  String get pleaseEnterYourPassword => 'Vennligst skriv inn passordet ditt';

  @override
  String get pleaseEnterValidEmail =>
      'Vennligst skriv inn en gyldig e-postadresse';

  @override
  String get passwordMustBeAtLeast6Characters =>
      'Passordet må være minst 6 tegn';

  @override
  String get processing => 'Behandler...';

  @override
  String get forgotPassword => 'Glemt passord?';

  // Login screen additional
  @override
  String get dontHaveAccount => 'Har du ikke konto? Registrer deg';

  @override
  String get alreadyHaveAccount => 'Har du allerede konto? Logg inn';

  @override
  String get orContinueWith => 'Eller fortsett med';

  @override
  String get continueWithGoogle => 'Fortsett med Google';

  @override
  String get useBiometrics => 'Bruk biometri';

  @override
  String get checkEmailVerification => 'Sjekk e-postverifikasjonsstatus';

  @override
  String get pleaseEnterValidEmailFirst =>
      'Vennligst skriv inn en gyldig e-postadresse først';

  @override
  String get termsAndPrivacy =>
      'Ved å fortsette godtar du våre Vilkår for bruk og Personvernerklæring';

  // Login messages and errors
  @override
  String get emailAuthServiceNotAvailable =>
      'E-postautentiseringstjenesten er ikke tilgjengelig';

  @override
  String get registrationError => 'Registreringsfeil';

  @override
  String get emailVerificationStatus => 'E-postverifikasjonsstatus';

  @override
  String get verified => 'Verifisert ✓';

  @override
  String get notVerified => 'Ikke Verifisert ✗';

  @override
  String get errorCheckingVerification =>
      'Feil ved sjekk av verifikasjonsstatus';

  @override
  String get unexpectedErrorOccurred => 'En uventet feil oppstod';

  // Navigation & Main UI
  @override
  String get profile => 'Profil';

  @override
  String get settings => 'Innstillinger';

  @override
  String get notifications => 'Varsler';

  @override
  String get home => 'Hjem';

  @override
  String get allDepartures => 'Alle Avganger';

  @override
  String get myDepartures => 'Mine Avganger';

  @override
  String get flightDetails => 'Flydetaljer';

  @override
  String get archived => 'Arkivert';

  @override
  String get save => 'Lagre';

  @override
  String get delete => 'Slett';

  @override
  String get restore => 'Gjenopprett';

  @override
  String get cancel => 'Avbryt';

  @override
  String get edit => 'Rediger';

  @override
  String get back => 'Tilbake';

  @override
  String get close => 'Lukk';

  @override
  String get done => 'Ferdig';

  @override
  String get logOut => 'Logg Ut';

  // Flight related
  @override
  String get flights => 'fly';

  @override
  String get flight => 'Fly';

  @override
  String get noFlightsFound => 'Ingen fly funnet';

  @override
  String get showAllFlights => 'Vis alle fly';

  @override
  String get searchFlights => 'Søk fly';

  @override
  String get filterFlights => 'Filtrer fly';

  @override
  String get resetFilters => 'Tilbakestill Filtre';

  @override
  String get selectAll => 'Velg Alle';

  @override
  String get deselectAll => 'Fjern Alle';

  @override
  String get gate => 'Gate';

  @override
  String get airline => 'Flyselskap';

  @override
  String get destination => 'Destinasjon';

  @override
  String get departureTime => 'Avgangstid';

  @override
  String get scheduledTime => 'Planlagt';

  @override
  String get actualTime => 'Faktisk';

  @override
  String get delayed => 'Forsinket';

  @override
  String get onTime => 'I Tide';

  @override
  String get cancelled => 'Kansellert';

  String get boarding => 'Ombordstigning';

  @override
  String get departed => 'Avgått';

  // Actions & Messages
  @override
  String get loading => 'Laster...';

  @override
  String get error => 'Feil';

  @override
  String get success => 'Suksess';

  @override
  String get noDataAvailable => 'Ingen data tilgjengelig';

  @override
  String get refreshData => 'Oppdater data';

  @override
  String get lastUpdated => 'Sist oppdatert';

  @override
  String get justNow => 'akkurat nå';

  @override
  String get minutesAgo => 'minutter siden';

  @override
  String get hoursAgo => 'timer siden';

  @override
  String get yesterday => 'i går';

  @override
  String get addedFlights => 'Lagt til fly';

  @override
  String get restoredFlights => 'Gjenopprettet fly';

  @override
  String get archivedFlights => 'Arkiverte fly';

  @override
  String get flightSavedSuccessfully => 'Fly lagret med suksess';

  @override
  String get flightArchivedSuccessfully => 'Fly arkivert med suksess';

  @override
  String get flightRestoredSuccessfully => 'Fly gjenopprettet med suksess';

  @override
  String get flightDeletedSuccessfully => 'Fly slettet med suksess';

  @override
  String get noSavedFlights => 'Du har ingen lagrede fly';

  @override
  String get noArchivedFlights => 'Ingen arkiverte fly';

  // Settings & Configuration
  @override
  String get languageSettings => 'Språkinnstillinger';

  @override
  String get selectLanguage => 'Velg ditt foretrukne språk';

  @override
  String get notificationSettings => 'Varselinnstillinger';

  @override
  String get configureNotifications =>
      'Konfigurer flyvarsler og notifikasjoner';

  @override
  String get delayNotifications => 'Forsinkelsesvarsel';

  @override
  String get departureNotifications => 'Avgangsvarsler';

  @override
  String get gateChangeNotifications => 'Gateendringsvarsler';

  @override
  String get developerMode => 'Utviklermodus';

  @override
  String get dataVisualizationSettings => 'Datavisualiseringsinnstillinger';

  @override
  String get preferences => 'Innstillinger';

  @override
  String get general => 'Generelt';

  // Time formats
  @override
  String formatMinutesAgo(int minutes) {
    if (minutes == 1) {
      return '1 minutt siden';
    }
    return '$minutes minutter siden';
  }

  @override
  String formatHoursAgo(int hours) {
    if (hours == 1) {
      return '1 time siden';
    }
    return '$hours timer siden';
  }

  @override
  String formatFlightsCount(int count) {
    if (count == 1) {
      return '1 fly';
    }
    return '$count fly';
  }

  @override
  String formatAddedFlights(int count) {
    if (count == 1) {
      return 'Lagt til 1 fly';
    }
    return 'Lagt til $count fly';
  }

  @override
  String formatRestoredFlights(int count) {
    if (count == 1) {
      return 'Gjenopprettet 1 fly';
    }
    return 'Gjenopprettet $count fly';
  }

  @override
  String formatArchivedFlights(int count) {
    if (count == 1) {
      return 'Arkivert 1 fly';
    }
    return 'Arkivert $count fly';
  }

  // Confirmation dialogs
  @override
  String get confirmDelete => 'Bekreft Sletting';

  @override
  String get confirmArchive => 'Bekreft Arkivering';

  @override
  String get confirmRestore => 'Bekreft Gjenoppretting';

  @override
  String get areYouSure => 'Er du sikker?';

  @override
  String get thisActionCannotBeUndone => 'Denne handlingen kan ikke angres';

  // Norwegian equivalence
  @override
  String get showingNorwegianEquivalent => 'Viser Norwegian-ekvivalenter';

  @override
  String get norwegianEquivalenceTooltip =>
      'Viser ekvivalente fly mellom Norwegian (DY) og Norwegian Air International (D8)';

  // Settings subtitles
  @override
  String get customizeDataDisplaySubtitle => 'Tilpass hvordan flydata vises';

  @override
  String get enableDeveloperModeSubtitle =>
      'Aktiver avanserte diagnose- og feilsøkingsverktøy';

  // Bottom navigation
  @override
  String get allDeparturesLabel => 'Alle Avganger';

  @override
  String get myDeparturesLabel => 'Mine Avganger';

  @override
  String get profileLabel => 'Profil';

  // Flight card
  @override
  String get trolley => 'Tralle';

  @override
  String get trolleysAtGate => 'Traller ved gate';

  @override
  String get departedShort => 'AVG.';

  // Flight details
  @override
  String get currentTrolleyCount => 'Nåværende';

  @override
  String get enterQuantity => 'Skriv inn antall';

  @override
  String get deliver => 'Lever';

  @override
  String get showHistory => 'Vis historikk';

  @override
  String get hideHistory => 'Skjul historikk';

  @override
  String get noHistoryAvailable => 'Ingen historikk tilgjengelig';

  @override
  String get gateTrolleysHistory => 'Gate Traller Historikk';

  @override
  String get gateChangeHistory => 'Gateendring Historikk';

  @override
  String get noGateChangesRecorded =>
      'Ingen gateendringer registrert for dette flyet.';

  @override
  String get confirmDelivery => 'Bekreft Levering';

  @override
  String get confirmDeletion => 'Bekreft Sletting';

  @override
  String get pleaseConfirmDelivery => 'Vennligst bekreft at du forlater';

  @override
  String get confirmRegister => 'Bekreft Registrering';

  @override
  String get pleaseConfirmRegister => 'Vennligst bekreft registreringen av';

  @override
  String get forFlight => 'for flyreise';

  @override
  String get completed => 'fullført';

  @override
  String get errorPrefix => 'Feil';

  @override
  String get areYouSureDelete =>
      'Er du sikker på at du vil markere som slettet leveringen av';

  @override
  String get deleteAllDeliveries =>
      'Slett Alle Leveringer (Bruk for gateendringer)';

  @override
  String get deleteAllGateChanges =>
      'Denne handlingen bør kun brukes i spesifikke tilfeller som gateendringer.\\n\\nEr du sikker på at du vil markere alle leveringer som slettet? Denne handlingen kan ikke angres.';

  @override
  String get trolleysData => 'Tralledata:';

  @override
  String get errorLoadingTrolleysData => 'Feil ved lasting av tralledata:';

  @override
  String get noTrolleysDataAvailable => 'Ingen tralledata tilgjengelig';

  @override
  String get deliveredAtGate => 'levert ved gate';

  @override
  String get pleaseEnterNumber => 'Vennligst skriv inn et tall';

  @override
  String get pleaseEnterValidNumber => 'Vennligst skriv inn et gyldig tall';

  @override
  String get errorSaving => 'Feil ved lagring:';

  @override
  String get deliveryMarkedDeleted =>
      'Leveringen har blitt markert som slettet';

  @override
  String get noDeliveriesToDelete => 'Ingen leveringer å slette';

  @override
  String get allDeliveriesDeleted =>
      'Alle leveringer har blitt markert som slettet';

  @override
  String get registerTrolleysLeft => 'Registrer antall traller igjen ved gate';

  // Flight details screen
  @override
  String get flightTitle => 'Fly';

  @override
  String get noDataFoundForFlight => 'Ingen data funnet for dette flyet';

  @override
  String get details => 'detaljer';

  // Gate history
  @override
  String get showingChangesFrom => 'Viser endringer fra';

  @override
  String get twoHoursBefore => '2 timer før';

  @override
  String get scheduledDepartureAt => 'planlagt avgang klokka';

  @override
  String get changedFrom => 'Endret fra';

  @override
  String get to => 'til';

  // Flight header
  @override
  String get destinationLabel => 'Destinasjon';

  @override
  String get newTime => 'Ny Tid';

  @override
  String get departedUpper => 'AVGÅTT';

  @override
  String get cancelledUpper => 'KANSELLERT';

  @override
  String get delayedUpper => 'FORSINKET';

  // Language settings
  @override
  String get languageInfo => 'Informasjon';

  @override
  String get languageChangeInfo =>
      'Språkendringer vil bli anvendt umiddelbart i hele appen. Innstillinger vil bli lagret automatisk.';

  // Notifications screen
  @override
  String get notificationsDescription =>
      'Konfigurer hvilke varsler du vil motta for dine lagrede fly';

  @override
  String get flightDelayNotifications => 'Flyforsinkelsesvarsel';

  @override
  String get delayNotificationsSubtitle =>
      'Motta varsler når fly lagret i Mine Avganger blir forsinket';

  @override
  String get flightDepartureNotifications => 'Flyavgangsvarsler';

  @override
  String get departureNotificationsSubtitle =>
      'Motta varsler når fly lagret i Mine Avganger har avgått';

  @override
  String get gateChangeNotificationsSubtitle =>
      'Motta varsler når fly lagret i Mine Avganger får gateendringer';

  // Data visualization screen
  @override
  String get norwegianDyD8Equivalence => 'Norwegian DY/D8 Ekvivalens';

  @override
  String get norwegianDyD8EquivalenceSubtitle =>
      'Vis fly med DY-kode når du søker etter D8 og omvendt';

  // Oversize item registration form
  @override
  String get itemTypeLabel => 'Artikkeltype:';

  @override
  String get referenceLabel => 'Referanse';

  @override
  String get avihReferenceLabel => 'AVIH-referanse';

  @override
  String get descriptionLabel => 'Beskrivelse';

  @override
  String get passengerNameLabel => 'Passasjernavn';

  @override
  String get fragileLabel => 'Skjør';

  @override
  String get requiresSpecialHandlingLabel => 'Krever spesiell håndtering';

  @override
  String get spareItem => 'Kolli';

  @override
  String get avih => 'AVIH';

  @override
  String get pleaseEnterAvihReference => 'Vennligst skriv inn AVIH-referanse';

  @override
  String get pleaseEnterPassengerName => 'Vennligst skriv inn passasjernavn';

  // Nye etiketter
  @override
  String get addToMyDepartures => 'Legg til Mine Avganger';

  @override
  String get archiveDepartures => 'Arkiver Avganger';

  @override
  String get weap => 'WEAP';

  // Oversize baggage management
  @override
  String get oversizeBaggageManagement => 'Håndtering av Overstørrelse Bagasje';

  @override
  String get registeredLabel => 'Registrert';

  @override
  String get deletedLabel => 'Slettet';

  @override
  String get byLabel => 'Av';

  @override
  String get deleteAllRegistries => 'Slett Alle Registre';

  @override
  String get deleteAllRecords => 'Slett Alle Registre';

  @override
  String get noRegistriesToDelete => 'Ingen registre å slette';

  @override
  String get registriesDeleted => 'registreringer slettet';

  @override
  String get userNotAuthenticated => 'Bruker ikke autentisert';

  @override
  String get deleteRegistryConfirmation =>
      'Er du sikker på at du vil slette registret av';

  @override
  String get deleteAllRegistriesConfirmation =>
      'Er du sikker på at du vil slette ALLE registre? Denne handlingen kan ikke angres.';

  // Special handling details
  @override
  String get specialHandlingDetails => 'Spesiell Håndtering Detaljer';

  @override
  String get enterSpecialHandlingDetails =>
      'Skriv inn detaljer for spesiell håndtering';

  @override
  String get specialHandlingPlaceholder =>
      'f.eks., Veldig tung, skjør håndtering, temperatur sensitiv...';

  // Converted label
  @override
  String get convertedLabel => 'Konvertert';

  @override
  String get currentLabel => 'Nåværende';

  // Oversize conversion dialogs
  @override
  String get convertToTrolleyTitle => 'Convert to trolley';

  @override
  String get convertConfirmationMessage =>
      'Do you want to convert {count} spare item(s) into 1 trolley?';

  @override
  String get convertAction => 'Convert';

  @override
  String get noSpareItemsToConvert => 'No spare items to convert';

  @override
  String get noSpareItemsAvailable => 'No spare items available';

  @override
  String get spareItemsConverted => 'Spare items converted to trolley';

  @override
  String get currentOversizeInfo => 'Nåværende Oversize-info';

  // Gate change notifications
  @override
  String get gateChangeNotificationTitle => 'Gate-endring';

  @override
  String gateChangeNotificationBody(String flightId, String airline,
          String destination, String oldGate, String newGate, String date) =>
      'Fly $flightId ($airline) til $destination endret gate fra $oldGate til $newGate den $date';

  // Oversize registration notifications
  @override
  String get oversizeRegistrationNotificationTitle =>
      'Ny Oversize Registrering';

  @override
  String oversizeRegistrationNotificationBody(String itemType, String flightId,
          String airline, String destination, String gate, String date) =>
      'En ny $itemType ble registrert for fly $flightId ($airline) til $destination ved gate $gate den $date';
}
