import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  // Authentication
  @override
  String get appName => 'RavenGate';

  @override
  String get signInToAccessAccount => 'Sign in to access your account';

  @override
  String get createAccount => 'Create account';

  @override
  String get signUpToStart => 'Sign up to start';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get pleaseEnterYourEmail => 'Please enter your email';

  @override
  String get pleaseEnterYourPassword => 'Please enter your password';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email address';

  @override
  String get passwordMustBeAtLeast6Characters =>
      'Password must be at least 6 characters';

  @override
  String get processing => 'Processing...';

  @override
  String get forgotPassword => 'Forgot Password?';

  // Login screen additional
  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign up';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get orContinueWith => 'Or continue with';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get useBiometrics => 'Use biometrics';

  @override
  String get checkEmailVerification => 'Check email verification status';

  @override
  String get pleaseEnterValidEmailFirst =>
      'Please enter a valid email address first';

  @override
  String get termsAndPrivacy =>
      'By continuing, you agree to our Terms of Service and Privacy Policy';

  // Login messages and errors
  @override
  String get emailAuthServiceNotAvailable =>
      'Email authentication service is not available';

  @override
  String get registrationError => 'Registration error';

  @override
  String get emailVerificationStatus => 'Email verification status';

  @override
  String get verified => 'Verified ✓';

  @override
  String get notVerified => 'Not Verified ✗';

  @override
  String get errorCheckingVerification => 'Error checking verification status';

  @override
  String get unexpectedErrorOccurred => 'An unexpected error occurred';

  // Navigation & Main UI
  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get home => 'Home';

  @override
  String get allDepartures => 'All Departures';

  @override
  String get myDepartures => 'My Departures';

  @override
  String get flightDetails => 'Flight Details';

  @override
  String get archived => 'Archived';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get restore => 'Restore';

  @override
  String get cancel => 'Cancel';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get logOut => 'Log Out';

  // Flight related
  @override
  String get flights => 'flights';

  @override
  String get flight => 'Flight';

  @override
  String get noFlightsFound => 'No flights found';

  @override
  String get showAllFlights => 'Show all flights';

  @override
  String get searchFlights => 'Search flights';

  @override
  String get filterFlights => 'Filter flights';

  @override
  String get resetFilters => 'Reset Filters';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get gate => 'Gate';

  @override
  String get airline => 'Airline';

  @override
  String get destination => 'Destination';

  @override
  String get departureTime => 'Departure Time';

  @override
  String get scheduledTime => 'Scheduled';

  @override
  String get actualTime => 'Actual';

  @override
  String get delayed => 'Delayed';

  @override
  String get onTime => 'On Time';

  @override
  String get cancelled => 'Cancelled';

  String get boarding => 'Boarding';

  @override
  String get departed => 'Departed';

  // Actions & Messages
  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get refreshData => 'Refresh data';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get justNow => 'just now';

  @override
  String get minutesAgo => 'minutes ago';

  @override
  String get hoursAgo => 'hours ago';

  @override
  String get yesterday => 'yesterday';

  @override
  String get addedFlights => 'Added flights';

  @override
  String get restoredFlights => 'Restored flights';

  @override
  String get archivedFlights => 'Archived flights';

  @override
  String get flightSavedSuccessfully => 'Flight saved successfully';

  @override
  String get flightArchivedSuccessfully => 'Flight archived successfully';

  @override
  String get flightRestoredSuccessfully => 'Flight restored successfully';

  @override
  String get flightDeletedSuccessfully => 'Flight deleted successfully';

  @override
  String get noSavedFlights => 'You don\'t have any saved flights';

  @override
  String get noArchivedFlights => 'No archived flights';

  // Settings & Configuration
  @override
  String get languageSettings => 'Language Settings';

  @override
  String get selectLanguage => 'Select your preferred language';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get configureNotifications =>
      'Configure flight alerts and notifications';

  @override
  String get delayNotifications => 'Delay Notifications';

  @override
  String get departureNotifications => 'Departure Notifications';

  @override
  String get gateChangeNotifications => 'Gate Change Notifications';

  @override
  String get developerMode => 'Developer Mode';

  @override
  String get dataVisualizationSettings => 'Data Visualization Settings';

  @override
  String get preferences => 'Preferences';

  @override
  String get general => 'General';

  // Time formats
  @override
  String formatMinutesAgo(int minutes) {
    if (minutes == 1) {
      return '1 minute ago';
    }
    return '$minutes minutes ago';
  }

  @override
  String formatHoursAgo(int hours) {
    if (hours == 1) {
      return '1 hour ago';
    }
    return '$hours hours ago';
  }

  @override
  String formatFlightsCount(int count) {
    if (count == 1) {
      return '1 flight';
    }
    return '$count flights';
  }

  @override
  String formatAddedFlights(int count) {
    if (count == 1) {
      return 'Added 1 flight';
    }
    return 'Added $count flights';
  }

  @override
  String formatRestoredFlights(int count) {
    if (count == 1) {
      return 'Restored 1 flight';
    }
    return 'Restored $count flights';
  }

  @override
  String formatArchivedFlights(int count) {
    if (count == 1) {
      return 'Archived 1 flight';
    }
    return 'Archived $count flights';
  }

  // Confirmation dialogs
  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get confirmArchive => 'Confirm Archive';

  @override
  String get confirmRestore => 'Confirm Restore';

  @override
  String get areYouSure => 'Are you sure?';

  @override
  String get thisActionCannotBeUndone => 'This action cannot be undone';

  // Norwegian equivalence
  @override
  String get showingNorwegianEquivalent => 'Showing Norwegian equivalent';

  @override
  String get norwegianEquivalenceTooltip =>
      'Showing equivalent flights between Norwegian (DY) and Norwegian Air International (D8)';

  // Settings subtitles
  @override
  String get customizeDataDisplaySubtitle =>
      'Customize how flight data is displayed';

  @override
  String get enableDeveloperModeSubtitle =>
      'Enable advanced diagnostics and debugging tools';

  // Bottom navigation
  @override
  String get allDeparturesLabel => 'All Departures';

  @override
  String get myDeparturesLabel => 'My Departures';

  @override
  String get profileLabel => 'Profile';

  // Flight card
  @override
  String get trolley => 'Trolley';

  @override
  String get trolleysAtGate => 'Trolleys at gate';

  @override
  String get departedShort => 'DEP.';

  // Flight details
  @override
  String get currentTrolleyCount => 'Current';

  @override
  String get enterQuantity => 'Enter quantity';

  @override
  String get deliver => 'Deliver';

  @override
  String get showHistory => 'Show history';

  @override
  String get hideHistory => 'Hide history';

  @override
  String get noHistoryAvailable => 'No history available';

  @override
  String get gateTrolleysHistory => 'Gate Trolleys History';

  @override
  String get gateChangeHistory => 'Gate Change History';

  @override
  String get noGateChangesRecorded =>
      'No gate changes recorded for this flight.';

  @override
  String get confirmDelivery => 'Confirm Delivery';

  @override
  String get confirmDeletion => 'Confirm Deletion';

  @override
  String get pleaseConfirmDelivery => 'Please confirm that you are leaving';

  @override
  String get confirmRegister => 'Confirm Register';

  @override
  String get pleaseConfirmRegister => 'Please confirm the registration of';

  @override
  String get forFlight => 'for flight';

  @override
  String get completed => 'completed';

  @override
  String get errorPrefix => 'Error';

  @override
  String get areYouSureDelete =>
      'Are you sure you want to mark as deleted the delivery of';

  @override
  String get deleteAllDeliveries =>
      'Delete All Deliveries (Use for gate changes)';

  @override
  String get deleteAllGateChanges =>
      'This action should only be used in specific cases like gate changes.\\n\\nAre you sure you want to mark all deliveries as deleted? This action cannot be undone.';

  @override
  String get trolleysData => 'Trolleys Data:';

  @override
  String get errorLoadingTrolleysData => 'Error loading trolleys data:';

  @override
  String get noTrolleysDataAvailable => 'No trolleys data available';

  @override
  String get deliveredAtGate => 'delivered at gate';

  @override
  String get pleaseEnterNumber => 'Please enter a number';

  @override
  String get pleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String get errorSaving => 'Error saving:';

  @override
  String get deliveryMarkedDeleted => 'Delivery has been marked as deleted';

  @override
  String get noDeliveriesToDelete => 'No deliveries to delete';

  @override
  String get allDeliveriesDeleted =>
      'All deliveries have been marked as deleted';

  @override
  String get registerTrolleysLeft =>
      'Register the number of trolleys left at gate';

  // Flight details screen
  @override
  String get flightTitle => 'Flight';

  @override
  String get noDataFoundForFlight => 'No data found for this flight';

  @override
  String get details => 'details';

  // Gate history
  @override
  String get showingChangesFrom => 'Showing changes from';

  @override
  String get twoHoursBefore => '2 hours before';

  @override
  String get scheduledDepartureAt => 'scheduled departure at';

  @override
  String get changedFrom => 'Changed from';

  @override
  String get to => 'to';

  // Flight header
  @override
  String get destinationLabel => 'Destination';

  @override
  String get newTime => 'New Time';

  @override
  String get departedUpper => 'DEPARTED';

  @override
  String get cancelledUpper => 'CANCELLED';

  @override
  String get delayedUpper => 'DELAYED';

  // Language settings
  @override
  String get languageInfo => 'Information';

  @override
  String get languageChangeInfo =>
      'Language changes will be applied immediately throughout the app. Settings will be saved automatically.';

  // Notifications screen
  @override
  String get notificationsDescription =>
      'Configure which notifications you want to receive for your saved flights';

  @override
  String get flightDelayNotifications => 'Flight Delay Notifications';

  @override
  String get delayNotificationsSubtitle =>
      'Receive alerts when flights saved in My Departures are delayed';

  @override
  String get flightDepartureNotifications => 'Flight Departure Notifications';

  @override
  String get departureNotificationsSubtitle =>
      'Receive alerts when flights saved in My Departures have departed';

  @override
  String get gateChangeNotificationsSubtitle =>
      'Receive alerts when flights saved in My Departures have gate changes';

  // Data visualization screen
  @override
  String get norwegianDyD8Equivalence => 'Norwegian DY/D8 Equivalence';

  @override
  String get norwegianDyD8EquivalenceSubtitle =>
      'Show flights with DY code when searching for D8 and vice versa';

  // Oversize item registration form
  @override
  String get itemTypeLabel => 'Item type:';

  @override
  String get referenceLabel => 'Reference';

  @override
  String get avihReferenceLabel => 'AVIH Reference';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get passengerNameLabel => 'Passenger name';

  @override
  String get fragileLabel => 'Fragile';

  @override
  String get requiresSpecialHandlingLabel => 'Requires special handling';

  @override
  String get spareItem => 'Spare Item';

  @override
  String get avih => 'AVIH';

  @override
  String get pleaseEnterAvihReference => 'Please enter AVIH reference';

  @override
  String get pleaseEnterPassengerName => 'Please enter passenger name';

  // New labels
  @override
  String get addToMyDepartures => 'Add to My Departures';

  @override
  String get archiveDepartures => 'Archive Departures';

  @override
  String get weap => 'WEAP';

  // Oversize baggage management
  @override
  String get oversizeBaggageManagement => 'Oversize Baggage Management';

  @override
  String get registeredLabel => 'Registered';

  @override
  String get deletedLabel => 'Deleted';

  @override
  String get byLabel => 'By';

  @override
  String get deleteAllRegistries => 'Delete All Registries';

  @override
  String get deleteAllRecords => 'Delete All Records';

  @override
  String get noRegistriesToDelete => 'No registries to delete';

  @override
  String get registriesDeleted => 'registries deleted';

  @override
  String get userNotAuthenticated => 'User not authenticated';

  @override
  String get deleteRegistryConfirmation =>
      'Are you sure you want to delete the registry of';

  @override
  String get deleteAllRegistriesConfirmation =>
      'Are you sure you want to delete ALL registries? This action cannot be undone.';

  // Special handling details
  @override
  String get specialHandlingDetails => 'Special Handling Details';

  @override
  String get enterSpecialHandlingDetails => 'Enter special handling details';

  @override
  String get specialHandlingPlaceholder =>
      'e.g., Very heavy, fragile handle, temperature sensitive...';

  // Converted label
  @override
  String get convertedLabel => 'Converted';

  @override
  String get currentLabel => 'Current';

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
  String get currentOversizeInfo => 'Current Oversize items in PMZ';

  // Gate change notifications
  @override
  String get gateChangeNotificationTitle => 'Gate Change';

  @override
  String gateChangeNotificationBody(String flightId, String airline,
          String destination, String oldGate, String newGate, String date) =>
      'Flight $flightId ($airline) to $destination changed gate from $oldGate to $newGate on $date';

  // Oversize registration notifications
  @override
  String get oversizeRegistrationNotificationTitle =>
      'New Oversize Registration';

  @override
  String oversizeRegistrationNotificationBody(String itemType, String flightId,
          String airline, String destination, String gate, String date) =>
      'A new $itemType was registered for flight $flightId ($airline) to $destination at gate $gate on $date';
}
