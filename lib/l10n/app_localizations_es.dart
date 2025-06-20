import 'app_localizations.dart';

/// The translations for Spanish (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  // Authentication
  @override
  String get appName => 'RavenGate';

  @override
  String get signInToAccessAccount => 'Inicia sesión para acceder a tu cuenta';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get signUpToStart => 'Regístrate para comenzar';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get signIn => 'Iniciar Sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get login => 'Acceder';

  @override
  String get register => 'Registrar';

  @override
  String get pleaseEnterYourEmail => 'Por favor, ingresa tu correo electrónico';

  @override
  String get pleaseEnterYourPassword => 'Por favor, ingresa tu contraseña';

  @override
  String get pleaseEnterValidEmail =>
      'Por favor, ingresa una dirección de correo válida';

  @override
  String get passwordMustBeAtLeast6Characters =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get processing => 'Procesando...';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  // Login screen additional
  @override
  String get dontHaveAccount => '¿No tienes cuenta? Regístrate';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get orContinueWith => 'O continúa con';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get useBiometrics => 'Usar biometría';

  @override
  String get checkEmailVerification =>
      'Verificar estado de verificación del email';

  @override
  String get pleaseEnterValidEmailFirst =>
      'Por favor ingresa una dirección de email válida primero';

  @override
  String get termsAndPrivacy =>
      'Al continuar, aceptas nuestros Términos de Servicio y Política de Privacidad';

  // Login messages and errors
  @override
  String get emailAuthServiceNotAvailable =>
      'El servicio de autenticación por email no está disponible';

  @override
  String get registrationError => 'Error de registro';

  @override
  String get emailVerificationStatus => 'Estado de verificación del email';

  @override
  String get verified => 'Verificado ✓';

  @override
  String get notVerified => 'No Verificado ✗';

  @override
  String get errorCheckingVerification =>
      'Error verificando estado de verificación';

  @override
  String get unexpectedErrorOccurred => 'Ocurrió un error inesperado';

  // Navigation & Main UI
  @override
  String get profile => 'Perfil';

  @override
  String get settings => 'Configuración';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get home => 'Inicio';

  @override
  String get allDepartures => 'Todas las Salidas';

  @override
  String get myDepartures => 'Mis Salidas';

  @override
  String get flightDetails => 'Detalles del Vuelo';

  @override
  String get archived => 'Archivados';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get restore => 'Restaurar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get edit => 'Editar';

  @override
  String get back => 'Atrás';

  @override
  String get close => 'Cerrar';

  @override
  String get done => 'Listo';

  @override
  String get logOut => 'Cerrar Sesión';

  // Flight related
  @override
  String get flights => 'vuelos';

  @override
  String get flight => 'Vuelo';

  @override
  String get noFlightsFound => 'No se encontraron vuelos';

  @override
  String get showAllFlights => 'Mostrar todos los vuelos';

  @override
  String get searchFlights => 'Buscar vuelos';

  @override
  String get filterFlights => 'Filtrar vuelos';

  @override
  String get resetFilters => 'Restablecer Filtros';

  @override
  String get selectAll => 'Seleccionar Todo';

  @override
  String get deselectAll => 'Deseleccionar Todo';

  @override
  String get gate => 'Puerta';

  @override
  String get airline => 'Aerolínea';

  @override
  String get destination => 'Destino';

  @override
  String get departureTime => 'Hora de Salida';

  @override
  String get scheduledTime => 'Programado';

  @override
  String get actualTime => 'Real';

  @override
  String get delayed => 'Retrasado';

  @override
  String get onTime => 'A Tiempo';

  @override
  String get cancelled => 'Cancelado';

  String get boarding => 'Embarcando';

  @override
  String get departed => 'Despegado';

  // Actions & Messages
  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Éxito';

  @override
  String get noDataAvailable => 'No hay datos disponibles';

  @override
  String get refreshData => 'Actualizar datos';

  @override
  String get lastUpdated => 'Última actualización';

  @override
  String get justNow => 'hace unos segundos';

  @override
  String get minutesAgo => 'minutos atrás';

  @override
  String get hoursAgo => 'horas atrás';

  @override
  String get yesterday => 'ayer';

  @override
  String get addedFlights => 'Vuelos agregados';

  @override
  String get restoredFlights => 'Vuelos restaurados';

  @override
  String get archivedFlights => 'Vuelos archivados';

  @override
  String get flightSavedSuccessfully => 'Vuelo guardado exitosamente';

  @override
  String get flightArchivedSuccessfully => 'Vuelo archivado exitosamente';

  @override
  String get flightRestoredSuccessfully => 'Vuelo restaurado exitosamente';

  @override
  String get flightDeletedSuccessfully => 'Vuelo eliminado exitosamente';

  @override
  String get noSavedFlights => 'No tienes vuelos guardados';

  @override
  String get noArchivedFlights => 'No hay vuelos archivados';

  // Settings & Configuration
  @override
  String get languageSettings => 'Configuración de Idioma';

  @override
  String get selectLanguage => 'Selecciona tu idioma preferido';

  @override
  String get notificationSettings => 'Configuración de Notificaciones';

  @override
  String get configureNotifications =>
      'Configurar alertas y notificaciones de vuelos';

  @override
  String get delayNotifications => 'Notificaciones de Retrasos';

  @override
  String get departureNotifications => 'Notificaciones de Despegues';

  @override
  String get gateChangeNotifications => 'Notificaciones de Cambio de Puerta';

  @override
  String get developerMode => 'Modo Desarrollador';

  @override
  String get dataVisualizationSettings =>
      'Configuración de Visualización de Datos';

  @override
  String get preferences => 'Preferencias';

  @override
  String get general => 'General';

  // Time formats
  @override
  String formatMinutesAgo(int minutes) {
    if (minutes == 1) {
      return 'hace 1 minuto';
    }
    return 'hace $minutes minutos';
  }

  @override
  String formatHoursAgo(int hours) {
    if (hours == 1) {
      return 'hace 1 hora';
    }
    return 'hace $hours horas';
  }

  @override
  String formatFlightsCount(int count) {
    if (count == 1) {
      return '1 vuelo';
    }
    return '$count vuelos';
  }

  @override
  String formatAddedFlights(int count) {
    if (count == 1) {
      return 'Agregado 1 vuelo';
    }
    return 'Agregados $count vuelos';
  }

  @override
  String formatRestoredFlights(int count) {
    if (count == 1) {
      return 'Restaurado 1 vuelo';
    }
    return 'Restaurados $count vuelos';
  }

  @override
  String formatArchivedFlights(int count) {
    if (count == 1) {
      return 'Archivado 1 vuelo';
    }
    return 'Archivados $count vuelos';
  }

  // Confirmation dialogs
  @override
  String get confirmDelete => 'Confirmar Eliminación';

  @override
  String get confirmArchive => 'Confirmar Archivo';

  @override
  String get confirmRestore => 'Confirmar Restauración';

  @override
  String get areYouSure => '¿Estás seguro?';

  @override
  String get thisActionCannotBeUndone => 'Esta acción no se puede deshacer';

  // Norwegian equivalence
  @override
  String get showingNorwegianEquivalent =>
      'Mostrando equivalentes de Norwegian';

  @override
  String get norwegianEquivalenceTooltip =>
      'Mostrando vuelos equivalentes entre Norwegian (DY) y Norwegian Air International (D8)';

  // Settings subtitles
  @override
  String get customizeDataDisplaySubtitle =>
      'Personalizar cómo se muestran los datos de vuelo';

  @override
  String get enableDeveloperModeSubtitle =>
      'Habilitar herramientas avanzadas de diagnóstico y depuración';

  // Bottom navigation
  @override
  String get allDeparturesLabel => 'Todas las Salidas';

  @override
  String get myDeparturesLabel => 'Mis Salidas';

  @override
  String get profileLabel => 'Perfil';

  // Flight card
  @override
  String get trolley => 'Trolley';

  @override
  String get trolleysAtGate => 'Trolleys en puerta';

  @override
  String get departedShort => 'DEP.';

  // Flight details
  @override
  String get currentTrolleyCount => 'Actual';

  @override
  String get enterQuantity => 'Ingresar cantidad';

  @override
  String get deliver => 'Entregar';

  @override
  String get showHistory => 'Mostrar historial';

  @override
  String get hideHistory => 'Ocultar historial';

  @override
  String get noHistoryAvailable => 'No hay historial disponible';

  @override
  String get gateTrolleysHistory => 'Historial de Trolleys de Puerta';

  @override
  String get gateChangeHistory => 'Historial de Cambios de Puerta';

  @override
  String get noGateChangesRecorded =>
      'No hay cambios de puerta registrados para este vuelo.';

  @override
  String get confirmDelivery => 'Confirmar Entrega';

  @override
  String get confirmDeletion => 'Confirmar Eliminación';

  @override
  String get pleaseConfirmDelivery => 'Por favor confirma que estás dejando';

  @override
  String get confirmRegister => 'Confirmar Registro';

  @override
  String get pleaseConfirmRegister => 'Por favor confirma el registro de';

  @override
  String get forFlight => 'para el vuelo';

  @override
  String get completed => 'completado';

  @override
  String get errorPrefix => 'Error';

  @override
  String get areYouSureDelete =>
      '¿Estás seguro de que quieres marcar como eliminada la entrega de';

  @override
  String get deleteAllDeliveries =>
      'Eliminar Todas las Entregas (Usar para cambios de puerta)';

  @override
  String get deleteAllGateChanges =>
      'Esta acción solo debe usarse en casos específicos como cambios de puerta.\\n\\n¿Estás seguro de que quieres marcar todas las entregas como eliminadas? Esta acción no se puede deshacer.';

  @override
  String get trolleysData => 'Datos de Trolleys:';

  @override
  String get errorLoadingTrolleysData => 'Error al cargar datos de trolleys:';

  @override
  String get noTrolleysDataAvailable => 'No hay datos de trolleys disponibles';

  @override
  String get deliveredAtGate => 'entregados en puerta';

  @override
  String get pleaseEnterNumber => 'Por favor ingresa un número';

  @override
  String get pleaseEnterValidNumber => 'Por favor ingresa un número válido';

  @override
  String get errorSaving => 'Error al guardar:';

  @override
  String get deliveryMarkedDeleted =>
      'La entrega ha sido marcada como eliminada';

  @override
  String get noDeliveriesToDelete => 'No hay entregas para eliminar';

  @override
  String get allDeliveriesDeleted =>
      'Todas las entregas han sido marcadas como eliminadas';

  @override
  String get registerTrolleysLeft =>
      'Registrar el número de trolleys dejados en puerta';

  // Flight details screen
  @override
  String get flightTitle => 'Vuelo';

  @override
  String get noDataFoundForFlight => 'No se encontraron datos para este vuelo';

  @override
  String get details => 'detalles';

  // Gate history
  @override
  String get showingChangesFrom => 'Mostrando cambios desde';

  @override
  String get twoHoursBefore => '2 horas antes';

  @override
  String get scheduledDepartureAt => 'de la salida programada a las';

  @override
  String get changedFrom => 'Cambió de';

  @override
  String get to => 'a';

  // Flight header
  @override
  String get destinationLabel => 'Destino';

  @override
  String get newTime => 'Nueva Hora';

  @override
  String get departedUpper => 'DESPEGADO';

  @override
  String get cancelledUpper => 'CANCELADO';

  @override
  String get delayedUpper => 'RETRASADO';

  // Language settings
  @override
  String get languageInfo => 'Información';

  @override
  String get languageChangeInfo =>
      'Los cambios de idioma se aplicarán inmediatamente en toda la aplicación. La configuración se guardará automáticamente.';

  // Notifications screen
  @override
  String get notificationsDescription =>
      'Configura qué notificaciones quieres recibir para tus vuelos guardados';

  @override
  String get flightDelayNotifications => 'Notificaciones de Retrasos';

  @override
  String get delayNotificationsSubtitle =>
      'Recibe alertas cuando los vuelos guardados en Mis Salidas se retrasen';

  @override
  String get flightDepartureNotifications => 'Notificaciones de Despegues';

  @override
  String get departureNotificationsSubtitle =>
      'Recibe alertas cuando los vuelos guardados en Mis Salidas hayan despegado';

  @override
  String get gateChangeNotificationsSubtitle =>
      'Recibe alertas cuando los vuelos guardados en Mis Salidas cambien de puerta';

  // Data visualization screen
  @override
  String get norwegianDyD8Equivalence => 'Equivalencia Norwegian DY/D8';

  @override
  String get norwegianDyD8EquivalenceSubtitle =>
      'Mostrar vuelos con código DY al buscar D8 y viceversa';

  // Oversize item registration form
  @override
  String get itemTypeLabel => 'Tipo de artículo:';

  @override
  String get referenceLabel => 'Referencia';

  @override
  String get avihReferenceLabel => 'Referencia AVIH';

  @override
  String get descriptionLabel => 'Descripción';

  @override
  String get passengerNameLabel => 'Nombre del pasajero';

  @override
  String get fragileLabel => 'Frágil';

  @override
  String get requiresSpecialHandlingLabel => 'Requiere manejo especial';

  @override
  String get spareItem => 'Artículo de repuesto';

  @override
  String get avih => 'AVIH';

  @override
  String get pleaseEnterAvihReference => 'Por favor ingrese la referencia AVIH';

  @override
  String get pleaseEnterPassengerName =>
      'Por favor ingrese el nombre del pasajero';

  // Nuevas etiquetas
  @override
  String get addToMyDepartures => 'Agregar a Mis Salidas';

  @override
  String get archiveDepartures => 'Archivar Salidas';

  @override
  String get weap => 'WEAP';

  // Oversize baggage management
  @override
  String get oversizeBaggageManagement => 'Gestión de Equipaje Especial';

  @override
  String get registeredLabel => 'Registrado';

  @override
  String get deletedLabel => 'Eliminado';

  @override
  String get byLabel => 'Por';

  @override
  String get deleteAllRegistries => 'Eliminar Todos los Registros';

  @override
  String get deleteAllRecords => 'Eliminar Todos los Registros';

  @override
  String get noRegistriesToDelete => 'No hay registros para eliminar';

  @override
  String get registriesDeleted => 'registros eliminados';

  @override
  String get userNotAuthenticated => 'Usuario no autenticado';

  @override
  String get deleteRegistryConfirmation =>
      '¿Estás seguro de que quieres eliminar el registro de';

  @override
  String get deleteAllRegistriesConfirmation =>
      '¿Estás seguro de que quieres eliminar TODOS los registros? Esta acción no se puede deshacer.';

  // Special handling details
  @override
  String get specialHandlingDetails => 'Detalles de Manejo Especial';

  @override
  String get enterSpecialHandlingDetails =>
      'Ingrese detalles de manejo especial';

  @override
  String get specialHandlingPlaceholder =>
      'ej., Muy pesado, manejo frágil, sensible a temperatura...';

  // Etiqueta convertido
  @override
  String get convertedLabel => 'Convertido';

  @override
  String get currentLabel => 'Actual';

  // Diálogos de conversión de oversize
  @override
  String get convertToTrolleyTitle => 'Convertir a trolley';

  @override
  String get convertConfirmationMessage =>
      '¿Desea convertir {count} piezas de equipaje en 1 trolley?';

  @override
  String get convertAction => 'Convertir';

  @override
  String get noSpareItemsToConvert =>
      'No hay artículos de repuesto para convertir';

  @override
  String get noSpareItemsAvailable =>
      'No hay artículos de repuesto disponibles';

  @override
  String get spareItemsConverted =>
      'Artículos de repuesto convertidos en trolley';

  @override
  String get currentOversizeInfo => 'Información Actual de Oversize';

  // Gate change notifications
  @override
  String get gateChangeNotificationTitle => 'Cambio de Puerta';

  @override
  String gateChangeNotificationBody(String flightId, String airline,
          String destination, String oldGate, String newGate, String date) =>
      'El vuelo $flightId ($airline) a $destination cambió de puerta de $oldGate a $newGate el $date';

  // Oversize registration notifications
  @override
  String get oversizeRegistrationNotificationTitle => 'Nuevo Registro Oversize';

  @override
  String oversizeRegistrationNotificationBody(String itemType, String flightId,
          String airline, String destination, String gate, String date) =>
      'Se registró un nuevo $itemType para el vuelo $flightId ($airline) a $destination en puerta $gate el $date';
}
