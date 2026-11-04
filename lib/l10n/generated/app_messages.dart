import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_messages_ar.dart';
import 'app_messages_en.dart';
import 'app_messages_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppMessages
/// returned by `AppMessages.of(context)`.
///
/// Applications need to include `AppMessages.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_messages.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppMessages.localizationsDelegates,
///   supportedLocales: AppMessages.supportedLocales,
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
/// be consistent with the languages listed in the AppMessages.supportedLocales
/// property.
abstract class AppMessages {
  AppMessages(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppMessages of(BuildContext context) {
    return Localizations.of<AppMessages>(context, AppMessages)!;
  }

  static const LocalizationsDelegate<AppMessages> delegate =
      _AppMessagesDelegate();

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
    Locale('fr')
  ];

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get home;

  /// No description provided for @vehicles.
  ///
  /// In fr, this message translates to:
  /// **'Véhicules'**
  String get vehicles;

  /// No description provided for @clients.
  ///
  /// In fr, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @contracts.
  ///
  /// In fr, this message translates to:
  /// **'Contrats'**
  String get contracts;

  /// No description provided for @drivers.
  ///
  /// In fr, this message translates to:
  /// **'Chauffeurs'**
  String get drivers;

  /// No description provided for @assistant.
  ///
  /// In fr, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// No description provided for @localAssistant.
  ///
  /// In fr, this message translates to:
  /// **'Assistant local'**
  String get localAssistant;

  /// No description provided for @quickActions.
  ///
  /// In fr, this message translates to:
  /// **'Actions rapides'**
  String get quickActions;

  /// No description provided for @overview.
  ///
  /// In fr, this message translates to:
  /// **'Vue d’ensemble'**
  String get overview;

  /// No description provided for @currentRentals.
  ///
  /// In fr, this message translates to:
  /// **'Locations en cours'**
  String get currentRentals;

  /// No description provided for @paymentsReceived.
  ///
  /// In fr, this message translates to:
  /// **'Encaissements'**
  String get paymentsReceived;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get seeAll;

  /// No description provided for @newClient.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau client'**
  String get newClient;

  /// No description provided for @newVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau véhicule'**
  String get newVehicle;

  /// No description provided for @newContract.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contrat'**
  String get newContract;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @addAVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un véhicule'**
  String get addAVehicle;

  /// No description provided for @addAClient.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un client'**
  String get addAClient;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer'**
  String get filter;

  /// No description provided for @reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get reset;

  /// No description provided for @available.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get available;

  /// No description provided for @available61af94.
  ///
  /// In fr, this message translates to:
  /// **'Disponibles'**
  String get available61af94;

  /// No description provided for @rented.
  ///
  /// In fr, this message translates to:
  /// **'Loué'**
  String get rented;

  /// No description provided for @rentede06686.
  ///
  /// In fr, this message translates to:
  /// **'Loués'**
  String get rentede06686;

  /// No description provided for @overdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get overdue;

  /// No description provided for @activeContracts.
  ///
  /// In fr, this message translates to:
  /// **'Contrats en cours'**
  String get activeContracts;

  /// No description provided for @noRentalInProgressCreateAContractTo.
  ///
  /// In fr, this message translates to:
  /// **'Aucune location en cours. Créez un contrat pour démarrer.'**
  String get noRentalInProgressCreateAContractTo;

  /// No description provided for @companyInformation.
  ///
  /// In fr, this message translates to:
  /// **'Informations de la société'**
  String get companyInformation;

  /// No description provided for @nameAddressLogoAndSignatureOnContracts.
  ///
  /// In fr, this message translates to:
  /// **'Nom, adresse, logo et signature sur les contrats.'**
  String get nameAddressLogoAndSignatureOnContracts;

  /// No description provided for @companyName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la société'**
  String get companyName;

  /// No description provided for @address.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get address;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @companyLogo.
  ///
  /// In fr, this message translates to:
  /// **'Logo de la société'**
  String get companyLogo;

  /// No description provided for @agencySignature.
  ///
  /// In fr, this message translates to:
  /// **'Signature de l’agence'**
  String get agencySignature;

  /// No description provided for @change.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get change;

  /// No description provided for @reminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels'**
  String get reminders;

  /// No description provided for @returnsPaymentsAndLicence.
  ///
  /// In fr, this message translates to:
  /// **'Retours, paiements et licence.'**
  String get returnsPaymentsAndLicence;

  /// No description provided for @backup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde'**
  String get backup;

  /// No description provided for @protectYourDataIfThePhoneIsLost.
  ///
  /// In fr, this message translates to:
  /// **'Protégez vos données si le téléphone est perdu.'**
  String get protectYourDataIfThePhoneIsLost;

  /// No description provided for @licence.
  ///
  /// In fr, this message translates to:
  /// **'Licence'**
  String get licence;

  /// No description provided for @security.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get security;

  /// No description provided for @renewLicence.
  ///
  /// In fr, this message translates to:
  /// **'Renouveler la licence'**
  String get renewLicence;

  /// No description provided for @newLicenceKey.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle clé de licence'**
  String get newLicenceKey;

  /// No description provided for @applyNewKey.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer la nouvelle clé'**
  String get applyNewKey;

  /// No description provided for @changePIN.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le code PIN'**
  String get changePIN;

  /// No description provided for @recoveryCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération'**
  String get recoveryCode;

  /// No description provided for @biometricUnlock.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouillage biométrique'**
  String get biometricUnlock;

  /// No description provided for @automaticLock.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage automatique'**
  String get automaticLock;

  /// No description provided for @lockNow.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller maintenant'**
  String get lockNow;

  /// No description provided for @remindersActive.
  ///
  /// In fr, this message translates to:
  /// **'Rappels actifs'**
  String get remindersActive;

  /// No description provided for @remindersNeedAttention.
  ///
  /// In fr, this message translates to:
  /// **'Rappels à corriger'**
  String get remindersNeedAttention;

  /// No description provided for @activeLicence.
  ///
  /// In fr, this message translates to:
  /// **'Licence active'**
  String get activeLicence;

  /// No description provided for @inactiveLicence.
  ///
  /// In fr, this message translates to:
  /// **'Licence inactive'**
  String get inactiveLicence;

  /// No description provided for @createABackup.
  ///
  /// In fr, this message translates to:
  /// **'Créer une sauvegarde'**
  String get createABackup;

  /// No description provided for @restoreABackup.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer une sauvegarde'**
  String get restoreABackup;

  /// No description provided for @restore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get restore;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @chooseTheApplicationLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la langue de l’application.'**
  String get chooseTheApplicationLanguage;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In fr, this message translates to:
  /// **'Arabe'**
  String get arabic;

  /// No description provided for @vehicleInspection.
  ///
  /// In fr, this message translates to:
  /// **'État des lieux'**
  String get vehicleInspection;

  /// No description provided for @photosAndDamage.
  ///
  /// In fr, this message translates to:
  /// **'Photos et dégâts'**
  String get photosAndDamage;

  /// No description provided for @clientSignature.
  ///
  /// In fr, this message translates to:
  /// **'Signature du client'**
  String get clientSignature;

  /// No description provided for @contractDeletedSuccessfully.
  ///
  /// In fr, this message translates to:
  /// **'Contrat supprimé avec succès.'**
  String get contractDeletedSuccessfully;

  /// No description provided for @unableToLoadContracts.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement des contrats.'**
  String get unableToLoadContracts;

  /// No description provided for @deleteClient.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le client'**
  String get deleteClient;

  /// No description provided for @deleteVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le véhicule'**
  String get deleteVehicle;

  /// No description provided for @deleteThisContract.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce contrat ?'**
  String get deleteThisContract;

  /// No description provided for @deleteThisClient.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce client ?'**
  String get deleteThisClient;

  /// No description provided for @deleteThisVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce véhicule ?'**
  String get deleteThisVehicle;

  /// No description provided for @savedSuccessfully.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré avec succès.'**
  String get savedSuccessfully;

  /// No description provided for @deletedSuccessfully.
  ///
  /// In fr, this message translates to:
  /// **'Supprimé avec succès.'**
  String get deletedSuccessfully;

  /// No description provided for @anErrorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get anErrorOccurred;

  /// No description provided for @client.
  ///
  /// In fr, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @vehicle.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule'**
  String get vehicle;

  /// No description provided for @contract.
  ///
  /// In fr, this message translates to:
  /// **'Contrat'**
  String get contract;

  /// No description provided for @addAPayment.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un paiement'**
  String get addAPayment;

  /// No description provided for @recordPayment.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un paiement'**
  String get recordPayment;

  /// No description provided for @confirmPayment.
  ///
  /// In fr, this message translates to:
  /// **'Valider le paiement'**
  String get confirmPayment;

  /// No description provided for @payAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout payer'**
  String get payAll;

  /// No description provided for @closee9f075.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get closee9f075;

  /// No description provided for @closeContract.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer le contrat'**
  String get closeContract;

  /// No description provided for @createContract.
  ///
  /// In fr, this message translates to:
  /// **'Créer le contrat'**
  String get createContract;

  /// No description provided for @rentThisVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Louer ce véhicule'**
  String get rentThisVehicle;

  /// No description provided for @maintenance.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @documentsAndMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Documents et entretien'**
  String get documentsAndMaintenance;

  /// No description provided for @exteriorPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos extérieures'**
  String get exteriorPhotos;

  /// No description provided for @takeAPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takeAPhoto;

  /// No description provided for @chooseAPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get chooseAPhoto;

  /// No description provided for @chooseAFile.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un fichier'**
  String get chooseAFile;

  /// No description provided for @useCamera.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser la caméra'**
  String get useCamera;

  /// No description provided for @scanNationalID.
  ///
  /// In fr, this message translates to:
  /// **'Scanner la CIN'**
  String get scanNationalID;

  /// No description provided for @scanDrivingLicence.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le permis'**
  String get scanDrivingLicence;

  /// No description provided for @generalCondition.
  ///
  /// In fr, this message translates to:
  /// **'État général'**
  String get generalCondition;

  /// No description provided for @vehicleCondition.
  ///
  /// In fr, this message translates to:
  /// **'État du véhicule'**
  String get vehicleCondition;

  /// No description provided for @fuelLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau de carburant'**
  String get fuelLevel;

  /// No description provided for @goodCondition.
  ///
  /// In fr, this message translates to:
  /// **'Bon état'**
  String get goodCondition;

  /// No description provided for @damaged.
  ///
  /// In fr, this message translates to:
  /// **'Endommagé'**
  String get damaged;

  /// No description provided for @diesel.
  ///
  /// In fr, this message translates to:
  /// **'Diesel'**
  String get diesel;

  /// No description provided for @petrol.
  ///
  /// In fr, this message translates to:
  /// **'Essence'**
  String get petrol;

  /// No description provided for @hybrid.
  ///
  /// In fr, this message translates to:
  /// **'Hybride'**
  String get hybrid;

  /// No description provided for @electric.
  ///
  /// In fr, this message translates to:
  /// **'Électrique'**
  String get electric;

  /// No description provided for @manual.
  ///
  /// In fr, this message translates to:
  /// **'Manuelle'**
  String get manual;

  /// No description provided for @automatic.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get automatic;

  /// No description provided for @tryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get tryAgain;

  /// No description provided for @generate.
  ///
  /// In fr, this message translates to:
  /// **'Générer'**
  String get generate;

  /// No description provided for @forgotPIN.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN oublié'**
  String get forgotPIN;

  /// No description provided for @unlock.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer'**
  String get unlock;

  /// No description provided for @remoteSignature.
  ///
  /// In fr, this message translates to:
  /// **'Signature à distance'**
  String get remoteSignature;

  /// No description provided for @signOnThisPhone.
  ///
  /// In fr, this message translates to:
  /// **'Signer sur ce téléphone'**
  String get signOnThisPhone;

  /// No description provided for @viewContractPDF.
  ///
  /// In fr, this message translates to:
  /// **'Voir le contrat PDF'**
  String get viewContractPDF;

  /// No description provided for @viewSignedPDF.
  ///
  /// In fr, this message translates to:
  /// **'Voir le PDF signé'**
  String get viewSignedPDF;

  /// No description provided for @localModel.
  ///
  /// In fr, this message translates to:
  /// **'Modèle local'**
  String get localModel;

  /// No description provided for @offlineLocalModel.
  ///
  /// In fr, this message translates to:
  /// **'Modèle local hors ligne'**
  String get offlineLocalModel;

  /// No description provided for @noResultsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat trouvé.'**
  String get noResultsFound;

  /// No description provided for @noRevenueData.
  ///
  /// In fr, this message translates to:
  /// **'Pas de données de revenus.'**
  String get noRevenueData;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @brandModelOrRegistration.
  ///
  /// In fr, this message translates to:
  /// **'Marque, modèle ou immatriculation'**
  String get brandModelOrRegistration;

  /// No description provided for @nameOrNationalID.
  ///
  /// In fr, this message translates to:
  /// **'Nom ou CIN'**
  String get nameOrNationalID;

  /// No description provided for @nameNationalIDOrPhone.
  ///
  /// In fr, this message translates to:
  /// **'Nom, CIN ou téléphone'**
  String get nameNationalIDOrPhone;

  /// No description provided for @searchByNameOrNationalID.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom ou CIN'**
  String get searchByNameOrNationalID;

  /// No description provided for @searchForAClient.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un client'**
  String get searchForAClient;

  /// No description provided for @chooseAClient.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un client'**
  String get chooseAClient;

  /// No description provided for @chooseAVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un véhicule'**
  String get chooseAVehicle;

  /// No description provided for @driver.
  ///
  /// In fr, this message translates to:
  /// **'Chauffeur'**
  String get driver;

  /// No description provided for @additionalDriver.
  ///
  /// In fr, this message translates to:
  /// **'Conducteur secondaire'**
  String get additionalDriver;

  /// No description provided for @searchForAnAdditionalDriver.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un conducteur secondaire'**
  String get searchForAnAdditionalDriver;

  /// No description provided for @brand.
  ///
  /// In fr, this message translates to:
  /// **'Marque'**
  String get brand;

  /// No description provided for @fuel.
  ///
  /// In fr, this message translates to:
  /// **'Carburant'**
  String get fuel;

  /// No description provided for @transmission.
  ///
  /// In fr, this message translates to:
  /// **'Boîte de vitesses'**
  String get transmission;

  /// No description provided for @dailyPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix par jour'**
  String get dailyPrice;

  /// No description provided for @hourlyRate.
  ///
  /// In fr, this message translates to:
  /// **'Prix par heure'**
  String get hourlyRate;

  /// No description provided for @contractTotal.
  ///
  /// In fr, this message translates to:
  /// **'Prix total du contrat'**
  String get contractTotal;

  /// No description provided for @amountDue.
  ///
  /// In fr, this message translates to:
  /// **'Montant à payer'**
  String get amountDue;

  /// No description provided for @amountPaidNow.
  ///
  /// In fr, this message translates to:
  /// **'Montant payé maintenant'**
  String get amountPaidNow;

  /// No description provided for @additionalFees.
  ///
  /// In fr, this message translates to:
  /// **'Frais supplémentaires'**
  String get additionalFees;

  /// No description provided for @notes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @internalNotes.
  ///
  /// In fr, this message translates to:
  /// **'Notes internes'**
  String get internalNotes;

  /// No description provided for @existingDamageNote.
  ///
  /// In fr, this message translates to:
  /// **'Note sur les dégâts existants'**
  String get existingDamageNote;

  /// No description provided for @drivingLicenceNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de permis'**
  String get drivingLicenceNumber;

  /// No description provided for @licenceExpiry.
  ///
  /// In fr, this message translates to:
  /// **'Expiration du permis'**
  String get licenceExpiry;

  /// No description provided for @status.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get status;

  /// No description provided for @phoneOptional.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone (optionnel)'**
  String get phoneOptional;

  /// No description provided for @numberOfDriverHours.
  ///
  /// In fr, this message translates to:
  /// **'Nombre d’heures chauffeur'**
  String get numberOfDriverHours;

  /// No description provided for @todaySOperations.
  ///
  /// In fr, this message translates to:
  /// **'Opérations du jour'**
  String get todaySOperations;

  /// No description provided for @unableToLoadTodaySOperations.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les opérations du jour.'**
  String get unableToLoadTodaySOperations;

  /// No description provided for @todaySPriorities.
  ///
  /// In fr, this message translates to:
  /// **'À faire aujourd’hui'**
  String get todaySPriorities;

  /// No description provided for @handleReturnsAndBlockedVehiclesFirst.
  ///
  /// In fr, this message translates to:
  /// **'Traitez d’abord les retours et les véhicules bloqués.'**
  String get handleReturnsAndBlockedVehiclesFirst;

  /// No description provided for @pickupsToday.
  ///
  /// In fr, this message translates to:
  /// **'Départs aujourd’hui'**
  String get pickupsToday;

  /// No description provided for @noPickupsScheduledToday.
  ///
  /// In fr, this message translates to:
  /// **'Aucun départ prévu aujourd’hui.'**
  String get noPickupsScheduledToday;

  /// No description provided for @returnsToday.
  ///
  /// In fr, this message translates to:
  /// **'Retours aujourd’hui'**
  String get returnsToday;

  /// No description provided for @noReturnsScheduledToday.
  ///
  /// In fr, this message translates to:
  /// **'Aucun retour prévu aujourd’hui.'**
  String get noReturnsScheduledToday;

  /// No description provided for @lateReturns.
  ///
  /// In fr, this message translates to:
  /// **'Retours en retard'**
  String get lateReturns;

  /// No description provided for @noLateReturns.
  ///
  /// In fr, this message translates to:
  /// **'Aucun retour en retard.'**
  String get noLateReturns;

  /// No description provided for @amountsToCollect.
  ///
  /// In fr, this message translates to:
  /// **'Montants à encaisser'**
  String get amountsToCollect;

  /// No description provided for @noOutstandingAmounts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun montant en attente.'**
  String get noOutstandingAmounts;

  /// No description provided for @carsBlockedForMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Véhicules bloqués en entretien'**
  String get carsBlockedForMaintenance;

  /// No description provided for @noCarsAreBlockedForMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule bloqué en entretien.'**
  String get noCarsAreBlockedForMaintenance;

  /// No description provided for @expiringDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Documents à échéance'**
  String get expiringDocuments;

  /// No description provided for @noDocumentsNeedRenewal.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document à renouveler.'**
  String get noDocumentsNeedRenewal;

  /// No description provided for @paid.
  ///
  /// In fr, this message translates to:
  /// **'Réglé'**
  String get paid;

  /// No description provided for @blocked.
  ///
  /// In fr, this message translates to:
  /// **'Bloqué'**
  String get blocked;

  /// No description provided for @since.
  ///
  /// In fr, this message translates to:
  /// **'Depuis'**
  String get since;

  /// No description provided for @everythingIsInOrderToday.
  ///
  /// In fr, this message translates to:
  /// **'Tout est en ordre pour aujourd’hui.'**
  String get everythingIsInOrderToday;

  /// No description provided for @operationsToFollowUpToday.
  ///
  /// In fr, this message translates to:
  /// **'opérations à suivre aujourd’hui.'**
  String get operationsToFollowUpToday;

  /// No description provided for @globalSearch.
  ///
  /// In fr, this message translates to:
  /// **'Recherche globale'**
  String get globalSearch;

  /// No description provided for @collectedThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Encaissé ce mois-ci'**
  String get collectedThisMonth;

  /// No description provided for @last7Days.
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get last7Days;

  /// No description provided for @toHandle.
  ///
  /// In fr, this message translates to:
  /// **'À traiter'**
  String get toHandle;

  /// No description provided for @paymentsToCollect.
  ///
  /// In fr, this message translates to:
  /// **'Paiements à encaisser'**
  String get paymentsToCollect;

  /// No description provided for @maintenanceAndDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Entretien et documents'**
  String get maintenanceAndDocuments;

  /// No description provided for @everythingIsInOrderNoLateReturnsOutstanding.
  ///
  /// In fr, this message translates to:
  /// **'Tout est en ordre : aucun retard, aucun solde à encaisser et aucun document à renouveler.'**
  String get everythingIsInOrderNoLateReturnsOutstanding;

  /// No description provided for @yourAgency.
  ///
  /// In fr, this message translates to:
  /// **'Votre agence'**
  String get yourAgency;

  /// No description provided for @myAgency.
  ///
  /// In fr, this message translates to:
  /// **'Mon agence'**
  String get myAgency;

  /// No description provided for @manageDriversTheirHourlyRateAndAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les chauffeurs, leur prix par heure et leur disponibilité.'**
  String get manageDriversTheirHourlyRateAndAvailability;

  /// No description provided for @askAboutYourAgencyOfflineTheModelStays.
  ///
  /// In fr, this message translates to:
  /// **'Questions sur l’agence, hors ligne : le modèle reste sur le téléphone.'**
  String get askAboutYourAgencyOfflineTheModelStays;

  /// No description provided for @onlyToRenewOrAfterChangingDevices.
  ///
  /// In fr, this message translates to:
  /// **'Seulement pour prolonger ou après un changement d’appareil.'**
  String get onlyToRenewOrAfterChangingDevices;

  /// No description provided for @pasteTheKeySuppliedByYourProviderHere.
  ///
  /// In fr, this message translates to:
  /// **'Collez ici la clé fournie par votre fournisseur'**
  String get pasteTheKeySuppliedByYourProviderHere;

  /// No description provided for @requiresTheCurrentPINBeforeAnyChange.
  ///
  /// In fr, this message translates to:
  /// **'Demande le code actuel avant tout changement.'**
  String get requiresTheCurrentPINBeforeAnyChange;

  /// No description provided for @generateANewCodeTheOldOneWill.
  ///
  /// In fr, this message translates to:
  /// **'Générer un nouveau code. L’ancien sera annulé.'**
  String get generateANewCodeTheOldOneWill;

  /// No description provided for @useFingerprintOrFaceRecognitionInsteadOfThe.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser l’empreinte ou le visage à la place du code.'**
  String get useFingerprintOrFaceRecognitionInsteadOfThe;

  /// No description provided for @noFingerprintIsRegisteredOnThisDevice.
  ///
  /// In fr, this message translates to:
  /// **'Aucune empreinte enregistrée sur cet appareil.'**
  String get noFingerprintIsRegisteredOnThisDevice;

  /// No description provided for @backToDashboard.
  ///
  /// In fr, this message translates to:
  /// **'Retour au tableau de bord'**
  String get backToDashboard;

  /// No description provided for @returnReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de retour'**
  String get returnReminders;

  /// No description provided for @scheduledReturnsLateVehiclesPayments.
  ///
  /// In fr, this message translates to:
  /// **'Retours prévus, véhicules en retard, paiements'**
  String get scheduledReturnsLateVehiclesPayments;

  /// No description provided for @notifyBeforeTheDeadline.
  ///
  /// In fr, this message translates to:
  /// **'Prévenir avant l\'échéance'**
  String get notifyBeforeTheDeadline;

  /// No description provided for @paymentReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de paiement'**
  String get paymentReminders;

  /// No description provided for @whenABalanceRemainsDueAtTheDeadline.
  ///
  /// In fr, this message translates to:
  /// **'Quand un solde reste dû à l’échéance.'**
  String get whenABalanceRemainsDueAtTheDeadline;

  /// No description provided for @licenceExpiry70b960.
  ///
  /// In fr, this message translates to:
  /// **'Expiration de la licence'**
  String get licenceExpiry70b960;

  /// No description provided for @alertsAt307And1Days.
  ///
  /// In fr, this message translates to:
  /// **'Alertes à 30, 7 et 1 jour.'**
  String get alertsAt307And1Days;

  /// No description provided for @quietHours.
  ///
  /// In fr, this message translates to:
  /// **'Heures silencieuses'**
  String get quietHours;

  /// No description provided for @from.
  ///
  /// In fr, this message translates to:
  /// **'De'**
  String get from;

  /// No description provided for @to.
  ///
  /// In fr, this message translates to:
  /// **'À'**
  String get to;

  /// No description provided for @remindersAreWorking.
  ///
  /// In fr, this message translates to:
  /// **'Les rappels fonctionnent'**
  String get remindersAreWorking;

  /// No description provided for @scheduledReminderS.
  ///
  /// In fr, this message translates to:
  /// **'rappel(s) programmé(s)'**
  String get scheduledReminderS;

  /// No description provided for @remindersUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Rappels indisponibles'**
  String get remindersUnavailable;

  /// No description provided for @notificationsBlockedByAndroid.
  ///
  /// In fr, this message translates to:
  /// **'Notifications bloquées par Android'**
  String get notificationsBlockedByAndroid;

  /// No description provided for @remindersMayBeDelayed.
  ///
  /// In fr, this message translates to:
  /// **'Rappels possiblement en retard'**
  String get remindersMayBeDelayed;

  /// No description provided for @biometricsNotConfirmedOptionNotEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Biométrie non confirmée. Option non activée.'**
  String get biometricsNotConfirmedOptionNotEnabled;

  /// No description provided for @newRecoveryCode.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code de récupération'**
  String get newRecoveryCode;

  /// No description provided for @backupFailed.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde impossible :'**
  String get backupFailed;

  /// No description provided for @restoreThisBackup.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer cette sauvegarde ?'**
  String get restoreThisBackup;

  /// No description provided for @backupRestoredRemindersWereRecreated.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde restaurée. Les rappels ont été recréés.'**
  String get backupRestoredRemindersWereRecreated;

  /// No description provided for @restoreFailed.
  ///
  /// In fr, this message translates to:
  /// **'Restauration impossible :'**
  String get restoreFailed;

  /// No description provided for @deviceIDCopied.
  ///
  /// In fr, this message translates to:
  /// **'ID de l\'appareil copié !'**
  String get deviceIDCopied;

  /// No description provided for @statusd3b28a.
  ///
  /// In fr, this message translates to:
  /// **'État'**
  String get statusd3b28a;

  /// No description provided for @licensedTo.
  ///
  /// In fr, this message translates to:
  /// **'Licencié à'**
  String get licensedTo;

  /// No description provided for @expiresOn.
  ///
  /// In fr, this message translates to:
  /// **'Expire le'**
  String get expiresOn;

  /// No description provided for @thisDeviceID.
  ///
  /// In fr, this message translates to:
  /// **'ID de cet appareil'**
  String get thisDeviceID;

  /// No description provided for @busy.
  ///
  /// In fr, this message translates to:
  /// **'Occupé'**
  String get busy;

  /// No description provided for @noDrivers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun chauffeur.'**
  String get noDrivers;

  /// No description provided for @noDriversFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun chauffeur trouvé.'**
  String get noDriversFound;

  /// No description provided for @changeTheSearchOrFilter.
  ///
  /// In fr, this message translates to:
  /// **'Modifiez la recherche ou le filtre.'**
  String get changeTheSearchOrFilter;

  /// No description provided for @newDriver.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau chauffeur'**
  String get newDriver;

  /// No description provided for @deleteThisDriver.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le chauffeur ?'**
  String get deleteThisDriver;

  /// No description provided for @deleteDriver.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le chauffeur'**
  String get deleteDriver;

  /// No description provided for @identityAndDrivingLicence.
  ///
  /// In fr, this message translates to:
  /// **'Identité et permis'**
  String get identityAndDrivingLicence;

  /// No description provided for @youCanScanTheNationalIDOrDriving.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez scanner la CIN ou le permis.'**
  String get youCanScanTheNationalIDOrDriving;

  /// No description provided for @contactAndRate.
  ///
  /// In fr, this message translates to:
  /// **'Contact et tarif'**
  String get contactAndRate;

  /// No description provided for @availability.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilité'**
  String get availability;

  /// No description provided for @availabilityCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités'**
  String get availabilityCalendar;

  /// No description provided for @availabilityCalendarb8c1ea.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier des disponibilités'**
  String get availabilityCalendarb8c1ea;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui'**
  String get today;

  /// No description provided for @previousWeek.
  ///
  /// In fr, this message translates to:
  /// **'Semaine précédente'**
  String get previousWeek;

  /// No description provided for @nextWeek.
  ///
  /// In fr, this message translates to:
  /// **'Semaine suivante'**
  String get nextWeek;

  /// No description provided for @quote.
  ///
  /// In fr, this message translates to:
  /// **'Devis'**
  String get quote;

  /// No description provided for @maintenance799eec.
  ///
  /// In fr, this message translates to:
  /// **'Entretien'**
  String get maintenance799eec;

  /// No description provided for @newQuote.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau devis'**
  String get newQuote;

  /// No description provided for @startDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de départ'**
  String get startDate;

  /// No description provided for @returnDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de retour'**
  String get returnDate;

  /// No description provided for @clientOptional.
  ///
  /// In fr, this message translates to:
  /// **'Client (optionnel)'**
  String get clientOptional;

  /// No description provided for @noClient.
  ///
  /// In fr, this message translates to:
  /// **'Sans client'**
  String get noClient;

  /// No description provided for @estimatedTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total estimé'**
  String get estimatedTotal;

  /// No description provided for @saveQuote.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le devis'**
  String get saveQuote;

  /// No description provided for @thisQuoteBlocksTheVehicleUntilItIs.
  ///
  /// In fr, this message translates to:
  /// **'Ce devis bloque le véhicule jusqu’à sa conversion ou son annulation.'**
  String get thisQuoteBlocksTheVehicleUntilItIs;

  /// No description provided for @quoteSaved.
  ///
  /// In fr, this message translates to:
  /// **'Devis enregistré.'**
  String get quoteSaved;

  /// No description provided for @savedQuotes.
  ///
  /// In fr, this message translates to:
  /// **'Devis enregistrés'**
  String get savedQuotes;

  /// No description provided for @noSavedQuotes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun devis enregistré.'**
  String get noSavedQuotes;

  /// No description provided for @convertToContract.
  ///
  /// In fr, this message translates to:
  /// **'Convertir en contrat'**
  String get convertToContract;

  /// No description provided for @cancelReservation.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la réservation'**
  String get cancelReservation;

  /// No description provided for @reservationCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Réservation annulée.'**
  String get reservationCancelled;

  /// No description provided for @thisVehicleIsAlreadyReservedForThisPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Ce véhicule est déjà réservé sur cette période.'**
  String get thisVehicleIsAlreadyReservedForThisPeriod;

  /// No description provided for @thisVehicleIsUnavailableBecauseOfMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Ce véhicule est indisponible pour entretien.'**
  String get thisVehicleIsUnavailableBecauseOfMaintenance;

  /// No description provided for @chooseAReturnDateAfterTheStartDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une date de retour après la date de départ.'**
  String get chooseAReturnDateAfterTheStartDate;

  /// No description provided for @perHour.
  ///
  /// In fr, this message translates to:
  /// **'par heure'**
  String get perHour;

  /// No description provided for @importNationalID.
  ///
  /// In fr, this message translates to:
  /// **'Importer CIN'**
  String get importNationalID;

  /// No description provided for @importDrivingLicence.
  ///
  /// In fr, this message translates to:
  /// **'Importer Permis'**
  String get importDrivingLicence;

  /// No description provided for @informationExtractedSuccessfully.
  ///
  /// In fr, this message translates to:
  /// **'Informations extraites avec succès.'**
  String get informationExtractedSuccessfully;

  /// No description provided for @codeCopied.
  ///
  /// In fr, this message translates to:
  /// **'Code copié.'**
  String get codeCopied;

  /// No description provided for @importFromDevice.
  ///
  /// In fr, this message translates to:
  /// **'Importer depuis l\'appareil'**
  String get importFromDevice;

  /// No description provided for @clientNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Client introuvable.'**
  String get clientNotFound;

  /// No description provided for @thisClientMayHaveBeenDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Ce client a peut-être été supprimé.'**
  String get thisClientMayHaveBeenDeleted;

  /// No description provided for @vehicleNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule introuvable.'**
  String get vehicleNotFound;

  /// No description provided for @thisVehicleMayHaveBeenDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Ce véhicule a peut-être été supprimé.'**
  String get thisVehicleMayHaveBeenDeleted;

  /// No description provided for @contractNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Contrat introuvable.'**
  String get contractNotFound;

  /// No description provided for @thisContractMayHaveBeenDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Ce contrat a peut-être été supprimé.'**
  String get thisContractMayHaveBeenDeleted;

  /// No description provided for @nationalIDCard.
  ///
  /// In fr, this message translates to:
  /// **'Carte d’identité (CIN)'**
  String get nationalIDCard;

  /// No description provided for @drivingLicenceValidity.
  ///
  /// In fr, this message translates to:
  /// **'Validité du permis'**
  String get drivingLicenceValidity;

  /// No description provided for @contactDetails.
  ///
  /// In fr, this message translates to:
  /// **'Coordonnées'**
  String get contactDetails;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @documents.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @tapAnImageToEnlargeIt.
  ///
  /// In fr, this message translates to:
  /// **'Touchez une image pour l’agrandir.'**
  String get tapAnImageToEnlargeIt;

  /// No description provided for @contractHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des contrats'**
  String get contractHistory;

  /// No description provided for @historyIsUnavailableAtTheMoment.
  ///
  /// In fr, this message translates to:
  /// **'Historique indisponible pour le moment.'**
  String get historyIsUnavailableAtTheMoment;

  /// No description provided for @notAdded.
  ///
  /// In fr, this message translates to:
  /// **'Non ajouté'**
  String get notAdded;

  /// No description provided for @vehicleInformation.
  ///
  /// In fr, this message translates to:
  /// **'Informations du véhicule'**
  String get vehicleInformation;

  /// No description provided for @exteriorPhotosAndDamage.
  ///
  /// In fr, this message translates to:
  /// **'Photos extérieures et dégâts'**
  String get exteriorPhotosAndDamage;

  /// No description provided for @maintenanceAndLegalDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Entretien et documents légaux'**
  String get maintenanceAndLegalDocuments;

  /// No description provided for @rentalHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique de location'**
  String get rentalHistory;

  /// No description provided for @addedOn.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté le'**
  String get addedOn;

  /// No description provided for @editedOn.
  ///
  /// In fr, this message translates to:
  /// **'modifié le'**
  String get editedOn;

  /// No description provided for @features.
  ///
  /// In fr, this message translates to:
  /// **'Caractéristiques'**
  String get features;

  /// No description provided for @currentMileage.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage actuel'**
  String get currentMileage;

  /// No description provided for @insuranceExpiryDate.
  ///
  /// In fr, this message translates to:
  /// **'Assurance : date d’expiration'**
  String get insuranceExpiryDate;

  /// No description provided for @technicalInspectionExpiryDate.
  ///
  /// In fr, this message translates to:
  /// **'Visite technique : date d’expiration'**
  String get technicalInspectionExpiryDate;

  /// No description provided for @roadTaxDueDate.
  ///
  /// In fr, this message translates to:
  /// **'Vignette : date limite'**
  String get roadTaxDueDate;

  /// No description provided for @oilChangeNextDate.
  ///
  /// In fr, this message translates to:
  /// **'Vidange : prochaine date'**
  String get oilChangeNextDate;

  /// No description provided for @oilChangeNextMileage.
  ///
  /// In fr, this message translates to:
  /// **'Vidange : prochain kilométrage'**
  String get oilChangeNextMileage;

  /// No description provided for @beltChainNextDate.
  ///
  /// In fr, this message translates to:
  /// **'Courroie / chaîne : prochaine date'**
  String get beltChainNextDate;

  /// No description provided for @beltChainNextMileage.
  ///
  /// In fr, this message translates to:
  /// **'Courroie / chaîne : prochain kilométrage'**
  String get beltChainNextMileage;

  /// No description provided for @model.
  ///
  /// In fr, this message translates to:
  /// **'Modèle'**
  String get model;

  /// No description provided for @registrationNumber.
  ///
  /// In fr, this message translates to:
  /// **'Immatriculation'**
  String get registrationNumber;

  /// No description provided for @year.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get year;

  /// No description provided for @needsChecking.
  ///
  /// In fr, this message translates to:
  /// **'À contrôler'**
  String get needsChecking;

  /// No description provided for @lpg.
  ///
  /// In fr, this message translates to:
  /// **'GPL'**
  String get lpg;

  /// No description provided for @lastRateDay.
  ///
  /// In fr, this message translates to:
  /// **'Dernier tarif / jour'**
  String get lastRateDay;

  /// No description provided for @noVehicleIsAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule disponible.'**
  String get noVehicleIsAvailable;

  /// No description provided for @addAVehicleOrCloseAnExistingContract.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un véhicule ou libérez un contrat existant.'**
  String get addAVehicleOrCloseAnExistingContract;

  /// No description provided for @clientMainDriver.
  ///
  /// In fr, this message translates to:
  /// **'Client (conducteur principal)'**
  String get clientMainDriver;

  /// No description provided for @mainDriver.
  ///
  /// In fr, this message translates to:
  /// **'Conducteur principal'**
  String get mainDriver;

  /// No description provided for @agencyDriver.
  ///
  /// In fr, this message translates to:
  /// **'Chauffeur de l’agence'**
  String get agencyDriver;

  /// No description provided for @optional.
  ///
  /// In fr, this message translates to:
  /// **'Optionnel'**
  String get optional;

  /// No description provided for @optionalBilledHourly.
  ///
  /// In fr, this message translates to:
  /// **'Optionnel · facturé à l’heure'**
  String get optionalBilledHourly;

  /// No description provided for @noDriver.
  ///
  /// In fr, this message translates to:
  /// **'Sans chauffeur'**
  String get noDriver;

  /// No description provided for @none.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get none;

  /// No description provided for @rentalPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période de location'**
  String get rentalPeriod;

  /// No description provided for @start.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get start;

  /// No description provided for @pickup.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get pickup;

  /// No description provided for @expectedReturn.
  ///
  /// In fr, this message translates to:
  /// **'Retour prévu'**
  String get expectedReturn;

  /// No description provided for @actualReturn.
  ///
  /// In fr, this message translates to:
  /// **'Retour réel'**
  String get actualReturn;

  /// No description provided for @duration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get duration;

  /// No description provided for @quickDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée rapide'**
  String get quickDuration;

  /// No description provided for @payment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get payment;

  /// No description provided for @noDeposit.
  ///
  /// In fr, this message translates to:
  /// **'Aucun acompte'**
  String get noDeposit;

  /// No description provided for @theAmountPaidExceedsTheTotal.
  ///
  /// In fr, this message translates to:
  /// **'Le montant payé dépasse le total.'**
  String get theAmountPaidExceedsTheTotal;

  /// No description provided for @existingClient.
  ///
  /// In fr, this message translates to:
  /// **'Client existant'**
  String get existingClient;

  /// No description provided for @findByScanningNationalID.
  ///
  /// In fr, this message translates to:
  /// **'Retrouver par scan de CIN'**
  String get findByScanningNationalID;

  /// No description provided for @selectAVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un véhicule.'**
  String get selectAVehicle;

  /// No description provided for @selectAMainDriver.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un conducteur principal.'**
  String get selectAMainDriver;

  /// No description provided for @warnings.
  ///
  /// In fr, this message translates to:
  /// **'Avertissements'**
  String get warnings;

  /// No description provided for @doYouStillWantToContinue.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous quand même continuer ?'**
  String get doYouStillWantToContinue;

  /// No description provided for @cancele326f7.
  ///
  /// In fr, this message translates to:
  /// **'ANNULER'**
  String get cancele326f7;

  /// No description provided for @continue71e092.
  ///
  /// In fr, this message translates to:
  /// **'CONTINUER'**
  String get continue71e092;

  /// No description provided for @price.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get price;

  /// No description provided for @alreadyPaid.
  ///
  /// In fr, this message translates to:
  /// **'Déjà payé'**
  String get alreadyPaid;

  /// No description provided for @pickupInspection.
  ///
  /// In fr, this message translates to:
  /// **'État des lieux départ'**
  String get pickupInspection;

  /// No description provided for @pickupInspectiondc5650.
  ///
  /// In fr, this message translates to:
  /// **'État des lieux de départ'**
  String get pickupInspectiondc5650;

  /// No description provided for @returnInspection.
  ///
  /// In fr, this message translates to:
  /// **'État des lieux de retour'**
  String get returnInspection;

  /// No description provided for @unpaidBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde impayé'**
  String get unpaidBalance;

  /// No description provided for @rentalTracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de la location'**
  String get rentalTracking;

  /// No description provided for @signedContract.
  ///
  /// In fr, this message translates to:
  /// **'Contrat signé'**
  String get signedContract;

  /// No description provided for @inspections.
  ///
  /// In fr, this message translates to:
  /// **'États des lieux'**
  String get inspections;

  /// No description provided for @pdfAndSignature.
  ///
  /// In fr, this message translates to:
  /// **'PDF et signature'**
  String get pdfAndSignature;

  /// No description provided for @paymentHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des paiements'**
  String get paymentHistory;

  /// No description provided for @vehicleReturnDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de retour du véhicule'**
  String get vehicleReturnDate;

  /// No description provided for @balanceDue.
  ///
  /// In fr, this message translates to:
  /// **'Reste à payer :'**
  String get balanceDue;

  /// No description provided for @enterTheAmountPaidByTheClient.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le montant versé par le client.'**
  String get enterTheAmountPaidByTheClient;

  /// No description provided for @theAmountIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le montant est requis.'**
  String get theAmountIsRequired;

  /// No description provided for @invalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide.'**
  String get invalidAmount;

  /// No description provided for @noLATER.
  ///
  /// In fr, this message translates to:
  /// **'NON, PLUS TARD'**
  String get noLATER;

  /// No description provided for @yesPAYALL.
  ///
  /// In fr, this message translates to:
  /// **'OUI, PAYER TOUT'**
  String get yesPAYALL;

  /// No description provided for @pickupReading.
  ///
  /// In fr, this message translates to:
  /// **'Relevé au départ'**
  String get pickupReading;

  /// No description provided for @vehicleReading.
  ///
  /// In fr, this message translates to:
  /// **'Relevé du véhicule'**
  String get vehicleReading;

  /// No description provided for @photos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @requiredToValidateThePickup.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire pour valider le départ.'**
  String get requiredToValidateThePickup;

  /// No description provided for @theClientSignatureIsRequiredAtPickup.
  ///
  /// In fr, this message translates to:
  /// **'La signature du client est requise au départ.'**
  String get theClientSignatureIsRequiredAtPickup;

  /// No description provided for @inspectionSaved.
  ///
  /// In fr, this message translates to:
  /// **'État des lieux enregistré.'**
  String get inspectionSaved;

  /// No description provided for @chooseFromPhone.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis le téléphone'**
  String get chooseFromPhone;

  /// No description provided for @imageFromDevice.
  ///
  /// In fr, this message translates to:
  /// **'Image depuis l\'appareil'**
  String get imageFromDevice;

  /// No description provided for @noTextExtracted.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte extrait.'**
  String get noTextExtracted;

  /// No description provided for @noTextExtractedTryAnotherFile.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte extrait. Essayez un autre fichier.'**
  String get noTextExtractedTryAnotherFile;

  /// No description provided for @fieldsFilledFromTheDocument.
  ///
  /// In fr, this message translates to:
  /// **'Champs remplis selon le document.'**
  String get fieldsFilledFromTheDocument;

  /// No description provided for @nationalIDNotRecognised.
  ///
  /// In fr, this message translates to:
  /// **'CIN non reconnu.'**
  String get nationalIDNotRecognised;

  /// No description provided for @unableToSaveTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer. Réessayez.'**
  String get unableToSaveTryAgain;

  /// No description provided for @signWithYourFingerInTheWhiteArea.
  ///
  /// In fr, this message translates to:
  /// **'Signez avec votre doigt dans le cadre blanc.'**
  String get signWithYourFingerInTheWhiteArea;

  /// No description provided for @signatureDrawingArea.
  ///
  /// In fr, this message translates to:
  /// **'Zone de dessin de la signature'**
  String get signatureDrawingArea;

  /// No description provided for @clearAndStartAgain.
  ///
  /// In fr, this message translates to:
  /// **'Effacer et recommencer'**
  String get clearAndStartAgain;

  /// No description provided for @signatureAndSignedPDFSaved.
  ///
  /// In fr, this message translates to:
  /// **'Signature et PDF signés enregistrés.'**
  String get signatureAndSignedPDFSaved;

  /// No description provided for @signedPDFReceivedAndSaved.
  ///
  /// In fr, this message translates to:
  /// **'PDF signé reçu et enregistré.'**
  String get signedPDFReceivedAndSaved;

  /// No description provided for @sendToClientForSignature.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer au client pour signature'**
  String get sendToClientForSignature;

  /// No description provided for @importSignedPDF.
  ///
  /// In fr, this message translates to:
  /// **'Importer le PDF signé'**
  String get importSignedPDF;

  /// No description provided for @shareSignedPDF.
  ///
  /// In fr, this message translates to:
  /// **'Partager le PDF signé'**
  String get shareSignedPDF;

  /// No description provided for @viewOriginalPDF.
  ///
  /// In fr, this message translates to:
  /// **'Voir le PDF original'**
  String get viewOriginalPDF;

  /// No description provided for @selectGGUFFile.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner le fichier GGUF'**
  String get selectGGUFFile;

  /// No description provided for @forgetThisFile.
  ///
  /// In fr, this message translates to:
  /// **'Oublier ce fichier'**
  String get forgetThisFile;

  /// No description provided for @configureLocalModel.
  ///
  /// In fr, this message translates to:
  /// **'Configurer le modèle local'**
  String get configureLocalModel;

  /// No description provided for @send.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get send;

  /// No description provided for @writtenWithTheLocalModel.
  ///
  /// In fr, this message translates to:
  /// **'Rédigé avec le modèle local'**
  String get writtenWithTheLocalModel;

  /// No description provided for @currentPIN.
  ///
  /// In fr, this message translates to:
  /// **'Code actuel'**
  String get currentPIN;

  /// No description provided for @enterYourCurrentPINToContinue.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre code actuel pour continuer.'**
  String get enterYourCurrentPINToContinue;

  /// No description provided for @confirmPIN.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez le code'**
  String get confirmPIN;

  /// No description provided for @enterTheSamePINASecondTime.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le même code une seconde fois.'**
  String get enterTheSamePINASecondTime;

  /// No description provided for @pinChanged.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN modifié.'**
  String get pinChanged;

  /// No description provided for @forgotPINbeb8db.
  ///
  /// In fr, this message translates to:
  /// **'Code oublié ?'**
  String get forgotPINbeb8db;

  /// No description provided for @accessRestoredChooseANewPIN.
  ///
  /// In fr, this message translates to:
  /// **'Accès rétabli. Choisissez un nouveau code PIN.'**
  String get accessRestoredChooseANewPIN;

  /// No description provided for @licenceActivation.
  ///
  /// In fr, this message translates to:
  /// **'Activation de la licence'**
  String get licenceActivation;

  /// No description provided for @addADriver.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un chauffeur'**
  String get addADriver;

  /// No description provided for @addYourAgencyDriversSoTheyCanBe.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez les chauffeurs de votre agence pour les proposer dans les contrats.'**
  String get addYourAgencyDriversSoTheyCanBe;

  /// No description provided for @calculatedAutomaticallyYouCanEditItManually.
  ///
  /// In fr, this message translates to:
  /// **'Calculé automatiquement, modifiable à la main.'**
  String get calculatedAutomaticallyYouCanEditItManually;

  /// No description provided for @missingFuelCleaningRepair.
  ///
  /// In fr, this message translates to:
  /// **'Carburant manquant, nettoyage, réparation…'**
  String get missingFuelCleaningRepair;

  /// No description provided for @clientAndDrivers.
  ///
  /// In fr, this message translates to:
  /// **'Client et conducteurs'**
  String get clientAndDrivers;

  /// No description provided for @copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copy;

  /// No description provided for @copyID.
  ///
  /// In fr, this message translates to:
  /// **'Copier l\'ID'**
  String get copyID;

  /// No description provided for @copyCode.
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get copyCode;

  /// No description provided for @beltChain.
  ///
  /// In fr, this message translates to:
  /// **'Courroie / chaîne'**
  String get beltChain;

  /// No description provided for @unlockWithFingerprint.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller par empreinte'**
  String get unlockWithFingerprint;

  /// No description provided for @clear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get clear;

  /// No description provided for @thisDeviceIdentifier.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant de cet appareil'**
  String get thisDeviceIdentifier;

  /// No description provided for @licenceExpiringSoon.
  ///
  /// In fr, this message translates to:
  /// **'Licence bientôt expirée'**
  String get licenceExpiringSoon;

  /// No description provided for @editClient.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le client'**
  String get editClient;

  /// No description provided for @editVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le véhicule'**
  String get editVehicle;

  /// No description provided for @optionalDescribeScratchesDentsOrMissingItems.
  ///
  /// In fr, this message translates to:
  /// **'Optionnel. Décrivez rayures, chocs ou éléments manquants.'**
  String get optionalDescribeScratchesDentsOrMissingItems;

  /// No description provided for @openSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les paramètres'**
  String get openSettings;

  /// No description provided for @paymentPending.
  ///
  /// In fr, this message translates to:
  /// **'Paiement en attente'**
  String get paymentPending;

  /// No description provided for @payments.
  ///
  /// In fr, this message translates to:
  /// **'Paiements'**
  String get payments;

  /// No description provided for @drivingLicence.
  ///
  /// In fr, this message translates to:
  /// **'Permis'**
  String get drivingLicence;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre la photo'**
  String get takePhoto;

  /// No description provided for @preparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation...'**
  String get preparing;

  /// No description provided for @vehicleReturn.
  ///
  /// In fr, this message translates to:
  /// **'Retour du véhicule'**
  String get vehicleReturn;

  /// No description provided for @scanNationalIDe0c6e8.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le CIN'**
  String get scanNationalIDe0c6e8;

  /// No description provided for @onlyAvailableDriversAreOfferedForANew.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les chauffeurs disponibles sont proposés dans un nouveau contrat.'**
  String get onlyAvailableDriversAreOfferedForANew;

  /// No description provided for @trackingIsUnavailableAtTheMoment.
  ///
  /// In fr, this message translates to:
  /// **'Suivi indisponible pour le moment.'**
  String get trackingIsUnavailableAtTheMoment;

  /// No description provided for @deleteThisClienteb4aa3.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce client'**
  String get deleteThisClienteb4aa3;

  /// No description provided for @deleteThisContract893d83.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce contrat'**
  String get deleteThisContract893d83;

  /// No description provided for @deleteThisVehicle01bd94.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce véhicule'**
  String get deleteThisVehicle01bd94;

  /// No description provided for @deleteThisContractbe8a00.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le contrat ?'**
  String get deleteThisContractbe8a00;

  /// No description provided for @typeAtLeast2Characters.
  ///
  /// In fr, this message translates to:
  /// **'Tapez au moins 2 caractères...'**
  String get typeAtLeast2Characters;

  /// No description provided for @validate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get validate;

  /// No description provided for @viewContract.
  ///
  /// In fr, this message translates to:
  /// **'Voir le contrat'**
  String get viewContract;

  /// No description provided for @viewVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Voir le véhicule'**
  String get viewVehicle;

  /// No description provided for @viewDrivers.
  ///
  /// In fr, this message translates to:
  /// **'Voir les chauffeurs'**
  String get viewDrivers;

  /// No description provided for @viewClients.
  ///
  /// In fr, this message translates to:
  /// **'Voir les clients'**
  String get viewClients;

  /// No description provided for @viewContracts.
  ///
  /// In fr, this message translates to:
  /// **'Voir les contrats'**
  String get viewContracts;

  /// No description provided for @viewVehicles.
  ///
  /// In fr, this message translates to:
  /// **'Voir les véhicules'**
  String get viewVehicles;

  /// No description provided for @lateVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule en retard'**
  String get lateVehicle;

  /// No description provided for @lastRateDay205ab8.
  ///
  /// In fr, this message translates to:
  /// **'dernier tarif / jour'**
  String get lastRateDay205ab8;

  /// No description provided for @notProvided.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get notProvided;

  /// No description provided for @expiresToday.
  ///
  /// In fr, this message translates to:
  /// **'Expire aujourd’hui'**
  String get expiresToday;

  /// No description provided for @valid.
  ///
  /// In fr, this message translates to:
  /// **'Valide'**
  String get valid;

  /// No description provided for @oilChange.
  ///
  /// In fr, this message translates to:
  /// **'Vidange'**
  String get oilChange;

  /// No description provided for @insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get insurance;

  /// No description provided for @technicalInspection.
  ///
  /// In fr, this message translates to:
  /// **'Visite technique'**
  String get technicalInspection;

  /// No description provided for @roadTax.
  ///
  /// In fr, this message translates to:
  /// **'Vignette'**
  String get roadTax;

  /// No description provided for @timingBeltChain.
  ///
  /// In fr, this message translates to:
  /// **'Courroie / chaîne de distribution'**
  String get timingBeltChain;

  /// No description provided for @thisFieldIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est requis.'**
  String get thisFieldIsRequired;

  /// No description provided for @invalidNumericValue.
  ///
  /// In fr, this message translates to:
  /// **'Valeur numérique invalide.'**
  String get invalidNumericValue;

  /// No description provided for @theValueMustBePositive.
  ///
  /// In fr, this message translates to:
  /// **'La valeur doit être positive.'**
  String get theValueMustBePositive;

  /// No description provided for @theValueCannotBeNegative.
  ///
  /// In fr, this message translates to:
  /// **'La valeur ne peut pas être négative.'**
  String get theValueCannotBeNegative;

  /// No description provided for @minimum.
  ///
  /// In fr, this message translates to:
  /// **'Minimum'**
  String get minimum;

  /// No description provided for @maximum.
  ///
  /// In fr, this message translates to:
  /// **'Maximum'**
  String get maximum;

  /// No description provided for @phoneNumberIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le téléphone est requis.'**
  String get phoneNumberIsRequired;

  /// No description provided for @phoneNumberMustContainDigitsOnly.
  ///
  /// In fr, this message translates to:
  /// **'Le téléphone doit contenir uniquement des chiffres.'**
  String get phoneNumberMustContainDigitsOnly;

  /// No description provided for @phoneNumberIsTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone trop court.'**
  String get phoneNumberIsTooShort;

  /// No description provided for @phoneNumberIsTooLong.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone trop long.'**
  String get phoneNumberIsTooLong;

  /// No description provided for @invalidEmailAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse email invalide.'**
  String get invalidEmailAddress;

  /// No description provided for @invalidNationalIDLettersDigitsAndHyphenAllowed.
  ///
  /// In fr, this message translates to:
  /// **'CIN invalide (caractères autorisés: lettres, chiffres, tiret).'**
  String get invalidNationalIDLettersDigitsAndHyphenAllowed;

  /// No description provided for @firstNameIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le prénom est requis.'**
  String get firstNameIsRequired;

  /// No description provided for @lastNameIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis.'**
  String get lastNameIsRequired;

  /// No description provided for @nationalIDIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le CIN est requis.'**
  String get nationalIDIsRequired;

  /// No description provided for @drivingLicenceNumberIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro de permis est requis.'**
  String get drivingLicenceNumberIsRequired;

  /// No description provided for @brandIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'La marque est requise.'**
  String get brandIsRequired;

  /// No description provided for @invalidMileage.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage invalide.'**
  String get invalidMileage;

  /// No description provided for @modelIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le modèle est requis.'**
  String get modelIsRequired;

  /// No description provided for @registrationNumberIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'L’immatriculation est requise.'**
  String get registrationNumberIsRequired;

  /// No description provided for @yearIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'L’année est requise.'**
  String get yearIsRequired;

  /// No description provided for @invalidYear.
  ///
  /// In fr, this message translates to:
  /// **'Année invalide.'**
  String get invalidYear;

  /// No description provided for @licenceKeyIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'La clé de licence est requise.'**
  String get licenceKeyIsRequired;

  /// No description provided for @theAmountExceedsTheBalance.
  ///
  /// In fr, this message translates to:
  /// **'Le montant dépasse le reste'**
  String get theAmountExceedsTheBalance;

  /// No description provided for @markAsBusy.
  ///
  /// In fr, this message translates to:
  /// **'Marquer occupé'**
  String get markAsBusy;

  /// No description provided for @markAsAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Marquer disponible'**
  String get markAsAvailable;

  /// No description provided for @editDriver.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le chauffeur'**
  String get editDriver;

  /// No description provided for @saving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get saving;

  /// No description provided for @fieldRequired.
  ///
  /// In fr, this message translates to:
  /// **'Champ requis.'**
  String get fieldRequired;

  /// No description provided for @drivingLicenceIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le permis est requis.'**
  String get drivingLicenceIsRequired;

  /// No description provided for @expectedFormat33345678.
  ///
  /// In fr, this message translates to:
  /// **'Format attendu : 33/345678'**
  String get expectedFormat33345678;

  /// No description provided for @invalidPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix invalide.'**
  String get invalidPrice;

  /// No description provided for @noClientsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Aucun client enregistré.'**
  String get noClientsSaved;

  /// No description provided for @addAClientWithOrWithoutScanningTheir.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un client, avec ou sans scan de ses documents.'**
  String get addAClientWithOrWithoutScanningTheir;

  /// No description provided for @nationalIDScanned.
  ///
  /// In fr, this message translates to:
  /// **'CIN scannée'**
  String get nationalIDScanned;

  /// No description provided for @nationalIDMissing.
  ///
  /// In fr, this message translates to:
  /// **'CIN manquante'**
  String get nationalIDMissing;

  /// No description provided for @drivingLicenceScanned.
  ///
  /// In fr, this message translates to:
  /// **'Permis scanné'**
  String get drivingLicenceScanned;

  /// No description provided for @drivingLicenceMissing.
  ///
  /// In fr, this message translates to:
  /// **'Permis manquant'**
  String get drivingLicenceMissing;

  /// No description provided for @all.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get all;

  /// No description provided for @allContracts.
  ///
  /// In fr, this message translates to:
  /// **'Tous les contrats'**
  String get allContracts;

  /// No description provided for @noVehiclesFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule trouvé.'**
  String get noVehiclesFound;

  /// No description provided for @yourFleet.
  ///
  /// In fr, this message translates to:
  /// **'Votre flotte'**
  String get yourFleet;

  /// No description provided for @addAPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get addAPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la photo'**
  String get changePhoto;

  /// No description provided for @editVehicle10dfd7.
  ///
  /// In fr, this message translates to:
  /// **'Modifier un véhicule'**
  String get editVehicle10dfd7;

  /// No description provided for @editClient58dfe3.
  ///
  /// In fr, this message translates to:
  /// **'Modifier un client'**
  String get editClient58dfe3;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get create;

  /// No description provided for @active.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get active;

  /// No description provided for @completed.
  ///
  /// In fr, this message translates to:
  /// **'Terminés'**
  String get completed;

  /// No description provided for @createANewContractToGetStarted.
  ///
  /// In fr, this message translates to:
  /// **'Créez un nouveau contrat pour commencer.'**
  String get createANewContractToGetStarted;

  /// No description provided for @returnCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Retour fait'**
  String get returnCompleted;

  /// No description provided for @contractToSign.
  ///
  /// In fr, this message translates to:
  /// **'Contrat à signer'**
  String get contractToSign;

  /// No description provided for @continueAndSign.
  ///
  /// In fr, this message translates to:
  /// **'Continuer et signer'**
  String get continueAndSign;

  /// No description provided for @yourSignedRentalContract.
  ///
  /// In fr, this message translates to:
  /// **'Votre contrat de location signé.'**
  String get yourSignedRentalContract;

  /// No description provided for @saveSignedPDF.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le PDF signé'**
  String get saveSignedPDF;

  /// No description provided for @signed.
  ///
  /// In fr, this message translates to:
  /// **'Signé'**
  String get signed;

  /// No description provided for @toSign.
  ///
  /// In fr, this message translates to:
  /// **'À signer'**
  String get toSign;

  /// No description provided for @signedOnThisPhone.
  ///
  /// In fr, this message translates to:
  /// **'Signé sur ce téléphone'**
  String get signedOnThisPhone;

  /// No description provided for @pdfReadyAwaitingSignature.
  ///
  /// In fr, this message translates to:
  /// **'PDF prêt • en attente de signature'**
  String get pdfReadyAwaitingSignature;

  /// No description provided for @received.
  ///
  /// In fr, this message translates to:
  /// **'Reçu'**
  String get received;

  /// No description provided for @front.
  ///
  /// In fr, this message translates to:
  /// **'Avant'**
  String get front;

  /// No description provided for @back1a55ee.
  ///
  /// In fr, this message translates to:
  /// **'Arrière'**
  String get back1a55ee;

  /// No description provided for @left.
  ///
  /// In fr, this message translates to:
  /// **'Gauche'**
  String get left;

  /// No description provided for @right.
  ///
  /// In fr, this message translates to:
  /// **'Droite'**
  String get right;

  /// No description provided for @existingDamage.
  ///
  /// In fr, this message translates to:
  /// **'Dégât existant'**
  String get existingDamage;

  /// No description provided for @newDamage.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau dégât'**
  String get newDamage;

  /// No description provided for @inspectionPickup.
  ///
  /// In fr, this message translates to:
  /// **'État des lieux · départ'**
  String get inspectionPickup;

  /// No description provided for @inspectionReturn.
  ///
  /// In fr, this message translates to:
  /// **'État des lieux · retour'**
  String get inspectionReturn;

  /// No description provided for @saveInspection.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l’état des lieux'**
  String get saveInspection;

  /// No description provided for @whatYouObserveBeforeHandingOverTheKeys.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous constatez avant la remise des clés.'**
  String get whatYouObserveBeforeHandingOverTheKeys;

  /// No description provided for @whatYouObserveAtReturn.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous constatez au retour.'**
  String get whatYouObserveAtReturn;

  /// No description provided for @mileageAtPickup.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage au départ'**
  String get mileageAtPickup;

  /// No description provided for @mileageAtReturn.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage au retour'**
  String get mileageAtReturn;

  /// No description provided for @mileageIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage requis.'**
  String get mileageIsRequired;

  /// No description provided for @driven.
  ///
  /// In fr, this message translates to:
  /// **'parcourus'**
  String get driven;

  /// No description provided for @existingDamagef545de.
  ///
  /// In fr, this message translates to:
  /// **'Dégâts existants'**
  String get existingDamagef545de;

  /// No description provided for @newDamagefc6db9.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux dégâts'**
  String get newDamagefc6db9;

  /// No description provided for @notesOnNewDamage.
  ///
  /// In fr, this message translates to:
  /// **'Notes sur les nouveaux dégâts'**
  String get notesOnNewDamage;

  /// No description provided for @signatureAddedRedo.
  ///
  /// In fr, this message translates to:
  /// **'Signature ajoutée · refaire'**
  String get signatureAddedRedo;

  /// No description provided for @signatureForInspection.
  ///
  /// In fr, this message translates to:
  /// **'Signature pour l’état des lieux'**
  String get signatureForInspection;

  /// No description provided for @noModelLoaded.
  ///
  /// In fr, this message translates to:
  /// **'Aucun modèle chargé'**
  String get noModelLoaded;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get loading;

  /// No description provided for @loadModel.
  ///
  /// In fr, this message translates to:
  /// **'Charger le modèle'**
  String get loadModel;

  /// No description provided for @localQuickAnswersAddAGGUFModelTo.
  ///
  /// In fr, this message translates to:
  /// **'Réponses rapides locales. Ajoutez un modèle GGUF pour discuter hors ligne.'**
  String get localQuickAnswersAddAGGUFModelTo;

  /// No description provided for @iCouldNotReadTheDataTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Je n’ai pas pu lire les données. Réessayez dans un instant.'**
  String get iCouldNotReadTheDataTryAgain;

  /// No description provided for @enterYour.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre code à'**
  String get enterYour;

  /// No description provided for @digitPIN.
  ///
  /// In fr, this message translates to:
  /// **'chiffres'**
  String get digitPIN;

  /// No description provided for @newPIN.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code'**
  String get newPIN;

  /// No description provided for @createYourPIN.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre code'**
  String get createYourPIN;

  /// No description provided for @iNotedThisCode.
  ///
  /// In fr, this message translates to:
  /// **'J’ai noté ce code'**
  String get iNotedThisCode;

  /// No description provided for @expiresSoon.
  ///
  /// In fr, this message translates to:
  /// **'Expire bientôt'**
  String get expiresSoon;

  /// No description provided for @thisPlatformDoesNotSupportLocalReminders.
  ///
  /// In fr, this message translates to:
  /// **'Cette plateforme ne gère pas les rappels locaux.'**
  String get thisPlatformDoesNotSupportLocalReminders;

  /// No description provided for @noRemindersWillAppearNeitherVehicleReturnsNor.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rappel ne s’affichera : ni retours de véhicules, ni paiements.'**
  String get noRemindersWillAppearNeitherVehicleReturnsNor;

  /// No description provided for @allowNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser les notifications'**
  String get allowNotifications;

  /// No description provided for @withoutTheAlarmsRemindersPermissionAndroidMayDelay.
  ///
  /// In fr, this message translates to:
  /// **'Sans l’autorisation « Alarmes et rappels », Android peut retarder les rappels.'**
  String get withoutTheAlarmsRemindersPermissionAndroidMayDelay;

  /// No description provided for @allowExactAlarms.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser les alarmes exactes'**
  String get allowExactAlarms;

  /// No description provided for @remindersMaySoundDuringTheNight.
  ///
  /// In fr, this message translates to:
  /// **'Les rappels peuvent sonner la nuit.'**
  String get remindersMaySoundDuringTheNight;

  /// No description provided for @quietHoursStart.
  ///
  /// In fr, this message translates to:
  /// **'Début du silence'**
  String get quietHoursStart;

  /// No description provided for @quietHoursEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin du silence'**
  String get quietHoursEnd;

  /// No description provided for @confirmToEnableBiometricUnlocking.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez pour activer le déverrouillage biométrique'**
  String get confirmToEnableBiometricUnlocking;

  /// No description provided for @termsAreLockedCreateANewContractTo.
  ///
  /// In fr, this message translates to:
  /// **'Conditions figées — créez un nouveau contrat pour les modifier.'**
  String get termsAreLockedCreateANewContractTo;

  /// No description provided for @driverSelected.
  ///
  /// In fr, this message translates to:
  /// **'Conducteur sélectionné.'**
  String get driverSelected;

  /// No description provided for @clientNotFoundInTheDatabase.
  ///
  /// In fr, this message translates to:
  /// **'Client non trouvé dans la base.'**
  String get clientNotFoundInTheDatabase;

  /// No description provided for @dataExtractedVerifyItAndSelectTheClient.
  ///
  /// In fr, this message translates to:
  /// **'Données extraites. Vérifiez et sélectionnez le client si besoin.'**
  String get dataExtractedVerifyItAndSelectTheClient;

  /// No description provided for @textExtractedButNationalIDFormatWasNot.
  ///
  /// In fr, this message translates to:
  /// **'Texte extrait mais format CIN non reconnu. Vérifiez et complétez.'**
  String get textExtractedButNationalIDFormatWasNot;

  /// No description provided for @textExtractedButDrivingLicenceFormatWasNot.
  ///
  /// In fr, this message translates to:
  /// **'Texte extrait mais format permis non reconnu. Vérifiez et complétez.'**
  String get textExtractedButDrivingLicenceFormatWasNot;

  /// No description provided for @signWithYourFingerInTheWhiteArea6872ef.
  ///
  /// In fr, this message translates to:
  /// **'Signez avec votre doigt dans le cadre blanc. Cette signature sera ajoutée au contrat que vous venez de lire et accepter.'**
  String get signWithYourFingerInTheWhiteArea6872ef;

  /// No description provided for @message1DayBefore.
  ///
  /// In fr, this message translates to:
  /// **'1 jour avant'**
  String get message1DayBefore;

  /// No description provided for @immediately.
  ///
  /// In fr, this message translates to:
  /// **'Immédiatement'**
  String get immediately;

  /// No description provided for @after1MinuteInTheBackground.
  ///
  /// In fr, this message translates to:
  /// **'Après 1 minute en arrière-plan'**
  String get after1MinuteInTheBackground;

  /// No description provided for @upToDate.
  ///
  /// In fr, this message translates to:
  /// **'À jour'**
  String get upToDate;

  /// No description provided for @contractNoVehicleOrClient.
  ///
  /// In fr, this message translates to:
  /// **'N° contrat, véhicule ou client'**
  String get contractNoVehicleOrClient;

  /// No description provided for @goodMorning.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get goodMorning;

  /// No description provided for @goodEvening.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir'**
  String get goodEvening;

  /// No description provided for @paidfa02fd.
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get paidfa02fd;

  /// No description provided for @signedPDFImportedVerifiedByYou.
  ///
  /// In fr, this message translates to:
  /// **'PDF signé importé • vérifié par vous'**
  String get signedPDFImportedVerifiedByYou;

  /// No description provided for @thePDFWillBePreparedWhenItIs.
  ///
  /// In fr, this message translates to:
  /// **'Le PDF sera préparé à la première ouverture.'**
  String get thePDFWillBePreparedWhenItIs;

  /// No description provided for @theClientMustUseAPDFAppSuch.
  ///
  /// In fr, this message translates to:
  /// **'Le client doit utiliser une application PDF, comme Adobe Acrobat Reader (Remplir et signer). Envoyez le PDF par WhatsApp ou e-mail. Le client le signe et vous renvoie le fichier signé.'**
  String get theClientMustUseAPDFAppSuch;

  /// No description provided for @theFirstPreparedPDFIsKeptUnchangedCheck.
  ///
  /// In fr, this message translates to:
  /// **'Le premier PDF préparé est conservé tel quel. Vérifiez les informations avant de continuer. Les paiements et la clôture restent disponibles.'**
  String get theFirstPreparedPDFIsKeptUnchangedCheck;

  /// No description provided for @theSignedPDFKeepsTheAmountsFromWhen.
  ///
  /// In fr, this message translates to:
  /// **'Le PDF signé conserve les montants au moment de sa création. Consultez les paiements du contrat pour le solde actuel.'**
  String get theSignedPDFKeepsTheAmountsFromWhen;

  /// No description provided for @noRecoveryCodeHasBeenCreated.
  ///
  /// In fr, this message translates to:
  /// **'Aucun code de récupération n\'a été créé.'**
  String get noRecoveryCodeHasBeenCreated;

  /// No description provided for @incorrectRecoveryCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération incorrect.'**
  String get incorrectRecoveryCode;

  /// No description provided for @thisCodeWasGeneratedForAnotherDevice.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a été généré pour un autre appareil.'**
  String get thisCodeWasGeneratedForAnotherDevice;

  /// No description provided for @thisCodeHasExpiredAskYourProviderFor.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré. Demandez-en un nouveau au vendeur.'**
  String get thisCodeHasExpiredAskYourProviderFor;

  /// No description provided for @thisCodeHasAlreadyBeenUsedRequestA.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a déjà été utilisé. Demandez-en un nouveau.'**
  String get thisCodeHasAlreadyBeenUsedRequestA;

  /// No description provided for @thisCodeIsInvalidCheckWhatYouEntered.
  ///
  /// In fr, this message translates to:
  /// **'Ce code n\'est pas valide. Vérifiez la saisie.'**
  String get thisCodeIsInvalidCheckWhatYouEntered;

  /// No description provided for @unreadableCodeCopyTheEntireCodeAgain.
  ///
  /// In fr, this message translates to:
  /// **'Code illisible. Recopiez-le en entier.'**
  String get unreadableCodeCopyTheEntireCodeAgain;

  /// No description provided for @incorrectPIN.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect.'**
  String get incorrectPIN;

  /// No description provided for @unlockCarRentManager.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouillez CarRent Manager'**
  String get unlockCarRentManager;

  /// No description provided for @chooseAModelFileEndingInGguf.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un fichier modèle qui se termine par .gguf.'**
  String get chooseAModelFileEndingInGguf;

  /// No description provided for @theFileCannotBeAccessed.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n’est pas accessible.'**
  String get theFileCannotBeAccessed;

  /// No description provided for @modelFileCopiedIntoTheAppLoadIt.
  ///
  /// In fr, this message translates to:
  /// **'Fichier modèle copié dans l’application. Chargez-le maintenant.'**
  String get modelFileCopiedIntoTheAppLoadIt;

  /// No description provided for @theModelIsReadyToUse.
  ///
  /// In fr, this message translates to:
  /// **'Le modèle est prêt à être utilisé.'**
  String get theModelIsReadyToUse;

  /// No description provided for @importAGGUFChatModelEachImportReplaces.
  ///
  /// In fr, this message translates to:
  /// **'Importez un modèle conversationnel GGUF. Chaque import remplace le modèle actuellement chargé.'**
  String get importAGGUFChatModelEachImportReplaces;

  /// No description provided for @theModelIsStoredSeparatelyFromTheApp.
  ///
  /// In fr, this message translates to:
  /// **'Le modèle reste séparé de l’APK. Les grands modèles demandent beaucoup d’espace et de RAM. Les questions et les données de l’agence restent sur ce téléphone.'**
  String get theModelIsStoredSeparatelyFromTheApp;

  /// No description provided for @modelLoaded.
  ///
  /// In fr, this message translates to:
  /// **'Modèle chargé'**
  String get modelLoaded;

  /// No description provided for @selectAGgufFileDownloadedToYourPhone.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un fichier .gguf téléchargé sur le téléphone.'**
  String get selectAGgufFileDownloadedToYourPhone;

  /// No description provided for @helloISearchThisAgencySDataDirectly.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour. Je cherche dans les données de cette agence, directement sur ce téléphone.'**
  String get helloISearchThisAgencySDataDirectly;

  /// No description provided for @availableVehicles.
  ///
  /// In fr, this message translates to:
  /// **'Véhicules disponibles'**
  String get availableVehicles;

  /// No description provided for @overdueContracts.
  ///
  /// In fr, this message translates to:
  /// **'Contrats en retard'**
  String get overdueContracts;

  /// No description provided for @outstandingPayments.
  ///
  /// In fr, this message translates to:
  /// **'Paiements en attente'**
  String get outstandingPayments;

  /// No description provided for @maintenanceAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes entretien'**
  String get maintenanceAlerts;

  /// No description provided for @eGWhichContractsAreOverdue.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Quels contrats sont en retard ?'**
  String get eGWhichContractsAreOverdue;

  /// No description provided for @theLocalModel.
  ///
  /// In fr, this message translates to:
  /// **'Le modèle local'**
  String get theLocalModel;

  /// No description provided for @anErrorOccurred9a1331.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get anErrorOccurred9a1331;

  /// No description provided for @cameraUnavailableChooseAFileInstead.
  ///
  /// In fr, this message translates to:
  /// **'Caméra non disponible. Sélection depuis les fichiers.'**
  String get cameraUnavailableChooseAFileInstead;

  /// No description provided for @imagePDFOrWordFile.
  ///
  /// In fr, this message translates to:
  /// **'Fichier image, PDF ou Word'**
  String get imagePDFOrWordFile;

  /// No description provided for @noTextExtractedTryAClearerImageOr.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte extrait. Essayez une image plus nette ou un autre fichier.'**
  String get noTextExtractedTryAClearerImageOr;

  /// No description provided for @unableToSaveTheClient.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer le client'**
  String get unableToSaveTheClient;

  /// No description provided for @thisClientHasNoContractsYet.
  ///
  /// In fr, this message translates to:
  /// **'Ce client n’a pas encore de contrat.'**
  String get thisClientHasNoContractsYet;

  /// No description provided for @noClientsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun client trouvé.'**
  String get noClientsFound;

  /// No description provided for @checkTheSpellingOrTryTheNationalID.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez l’orthographe ou essayez le numéro de CIN.'**
  String get checkTheSpellingOrTryTheNationalID;

  /// No description provided for @somePermissionsAreStillDeniedOpenThisApp.
  ///
  /// In fr, this message translates to:
  /// **'Certaines autorisations sont encore refusées. Ouvrez les réglages Android de l\'application.'**
  String get somePermissionsAreStillDeniedOpenThisApp;

  /// No description provided for @noReturnOrPaymentRemindersWillAppearAllow.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rappel ne s’affichera : ni retours de véhicules, ni paiements. Autorisez les notifications pour cette application.'**
  String get noReturnOrPaymentRemindersWillAppearAllow;

  /// No description provided for @withoutTheAlarmsAndRemindersPermissionAndroidMay.
  ///
  /// In fr, this message translates to:
  /// **'Sans l’autorisation « Alarmes et rappels », Android peut retarder un rappel de 14h37 jusqu’au prochain réveil du téléphone.'**
  String get withoutTheAlarmsAndRemindersPermissionAndroidMay;

  /// No description provided for @noPendingRemindersThereAreNoUpcomingActive.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rappel en attente : aucun contrat en cours à venir.'**
  String get noPendingRemindersThereAreNoUpcomingActive;

  /// No description provided for @notificationsAreBlockedForThisAppEnableThem.
  ///
  /// In fr, this message translates to:
  /// **'Les notifications sont bloquées pour cette application. Activez-les dans les réglages Android.'**
  String get notificationsAreBlockedForThisAppEnableThem;

  /// No description provided for @aNewCodeWillBeGeneratedAndShown.
  ///
  /// In fr, this message translates to:
  /// **'Un nouveau code sera généré et affiché une seule fois. Votre code actuel cessera immédiatement de fonctionner.\n\nContinuer ?'**
  String get aNewCodeWillBeGeneratedAndShown;

  /// No description provided for @askForThePINAgainAfterEachDocument.
  ///
  /// In fr, this message translates to:
  /// **'Redemande le code après chaque scan de document.'**
  String get askForThePINAgainAfterEachDocument;

  /// No description provided for @carrentBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde CarRent'**
  String get carrentBackup;

  /// No description provided for @carrentManagerBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde CarRent Manager'**
  String get carrentManagerBackup;

  /// No description provided for @backupCreatedSaveTheZIPFileSomewhereSafe.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde créée. Enregistrez le fichier ZIP dans un endroit sûr.'**
  String get backupCreatedSaveTheZIPFileSomewhereSafe;

  /// No description provided for @theAppSCurrentDataAndDocumentsWill.
  ///
  /// In fr, this message translates to:
  /// **'Les données et documents actuels de cette application seront remplacés. Le code PIN et la licence de ce téléphone resteront en place.'**
  String get theAppSCurrentDataAndDocumentsWill;

  /// No description provided for @aZIPFileContainingYourDataAndDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Un fichier ZIP avec les données et les documents. Gardez-le hors du téléphone.'**
  String get aZIPFileContainingYourDataAndDocuments;

  /// No description provided for @replaceCurrentDataWithTheDataInA.
  ///
  /// In fr, this message translates to:
  /// **'Remplace les données actuelles par celles du fichier ZIP.'**
  String get replaceCurrentDataWithTheDataInA;

  /// No description provided for @licenceKeyIsRequired853b1e.
  ///
  /// In fr, this message translates to:
  /// **'La clé de licence est requise.'**
  String get licenceKeyIsRequired853b1e;

  /// No description provided for @noValidLicenceOnThisDevice.
  ///
  /// In fr, this message translates to:
  /// **'Aucune licence valide sur cet appareil.'**
  String get noValidLicenceOnThisDevice;

  /// No description provided for @licenceActivatedSuccessfully.
  ///
  /// In fr, this message translates to:
  /// **'Licence activée avec succès.'**
  String get licenceActivatedSuccessfully;

  /// No description provided for @enterYourLicenceKeyToActivateCarRentManager.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre clé de licence pour activer CarRent Manager.'**
  String get enterYourLicenceKeyToActivateCarRentManager;

  /// No description provided for @deviceIDRequiredForTheLicence.
  ///
  /// In fr, this message translates to:
  /// **'ID DE CET APPAREIL (Obligatoire pour la licence):'**
  String get deviceIDRequiredForTheLicence;

  /// No description provided for @licenceKey.
  ///
  /// In fr, this message translates to:
  /// **'Code de licence / License Key'**
  String get licenceKey;

  /// No description provided for @pasteYourBase64LicenceKeyHere.
  ///
  /// In fr, this message translates to:
  /// **'Collez ici votre code de licence Base64...'**
  String get pasteYourBase64LicenceKeyHere;

  /// No description provided for @validating.
  ///
  /// In fr, this message translates to:
  /// **'Validation en cours...'**
  String get validating;

  /// No description provided for @validateLicence.
  ///
  /// In fr, this message translates to:
  /// **'Valider la licence'**
  String get validateLicence;

  /// No description provided for @noVehicles.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule.'**
  String get noVehicles;

  /// No description provided for @addAVehicleToPlanReservations.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un véhicule pour planifier les réservations.'**
  String get addAVehicleToPlanReservations;

  /// No description provided for @editContract.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le contrat'**
  String get editContract;

  /// No description provided for @completeBeforeHandingOverTheKeys.
  ///
  /// In fr, this message translates to:
  /// **'À faire avant la remise des clés.'**
  String get completeBeforeHandingOverTheKeys;

  /// No description provided for @signedPDFSaved.
  ///
  /// In fr, this message translates to:
  /// **'PDF signé enregistré.'**
  String get signedPDFSaved;

  /// No description provided for @toBeSignedByTheClientSeeBelow.
  ///
  /// In fr, this message translates to:
  /// **'À signer par le client (voir plus bas).'**
  String get toBeSignedByTheClientSeeBelow;

  /// No description provided for @contractPaidInFull.
  ///
  /// In fr, this message translates to:
  /// **'Contrat entièrement payé.'**
  String get contractPaidInFull;

  /// No description provided for @viewOrRedo.
  ///
  /// In fr, this message translates to:
  /// **'Voir ou refaire'**
  String get viewOrRedo;

  /// No description provided for @noPaymentsRecordedForThisContract.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement enregistré pour ce contrat.'**
  String get noPaymentsRecordedForThisContract;

  /// No description provided for @selectAnAdditionalDriverOrTurnOffThe.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un conducteur secondaire, ou désactivez l’option.'**
  String get selectAnAdditionalDriverOrTurnOffThe;

  /// No description provided for @theTotalPriceMustBeGreaterThan0.
  ///
  /// In fr, this message translates to:
  /// **'Le prix total doit être supérieur à 0.'**
  String get theTotalPriceMustBeGreaterThan0;

  /// No description provided for @saveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get saveChanges;

  /// No description provided for @toRecordAPaymentUseAddAPayment.
  ///
  /// In fr, this message translates to:
  /// **'Pour enregistrer un versement, utilisez « Ajouter un paiement » sur la fiche du contrat.'**
  String get toRecordAPaymentUseAddAPayment;

  /// No description provided for @iHaveReadTheContractAndAcceptIts.
  ///
  /// In fr, this message translates to:
  /// **'J’ai lu le contrat et accepté ses conditions.'**
  String get iHaveReadTheContractAndAcceptIts;

  /// No description provided for @signatureIsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Signature vide.'**
  String get signatureIsEmpty;

  /// No description provided for @confirmMySignature.
  ///
  /// In fr, this message translates to:
  /// **'Valider ma signature'**
  String get confirmMySignature;

  /// No description provided for @clientAndDetailsFilledFromTheDocument.
  ///
  /// In fr, this message translates to:
  /// **'Client et données remplis à partir du document.'**
  String get clientAndDetailsFilledFromTheDocument;

  /// No description provided for @lastNameFirstNameNationalIDAndLicence.
  ///
  /// In fr, this message translates to:
  /// **'Nom, Prénom, CIN et Permis sont requis pour le conducteur principal.'**
  String get lastNameFirstNameNationalIDAndLicence;

  /// No description provided for @lastNameFirstNameNationalIDAndLicence40cf2a.
  ///
  /// In fr, this message translates to:
  /// **'Nom, Prénom, CIN et Permis sont requis pour le conducteur secondaire.'**
  String get lastNameFirstNameNationalIDAndLicence40cf2a;

  /// No description provided for @theMainAndAdditionalDriversAreTheSame.
  ///
  /// In fr, this message translates to:
  /// **'Le conducteur principal et secondaire sont identiques.'**
  String get theMainAndAdditionalDriversAreTheSame;

  /// No description provided for @paidInFull.
  ///
  /// In fr, this message translates to:
  /// **'Entièrement payé'**
  String get paidInFull;

  /// No description provided for @noContractsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contrat trouvé.'**
  String get noContractsFound;

  /// No description provided for @noOverdueReturns.
  ///
  /// In fr, this message translates to:
  /// **'Aucun retard.'**
  String get noOverdueReturns;

  /// No description provided for @noCompletedContracts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contrat terminé.'**
  String get noCompletedContracts;

  /// No description provided for @noActiveRentals.
  ///
  /// In fr, this message translates to:
  /// **'Aucune location en cours.'**
  String get noActiveRentals;

  /// No description provided for @noContracts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contrat.'**
  String get noContracts;

  /// No description provided for @tryAnotherNameVehicleOrNumber.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre nom, véhicule ou numéro.'**
  String get tryAnotherNameVehicleOrNumber;

  /// No description provided for @allVehiclesWereReturnedOnTime.
  ///
  /// In fr, this message translates to:
  /// **'Tous les véhicules sont rentrés à l’heure.'**
  String get allVehiclesWereReturnedOnTime;

  /// No description provided for @notesOnExistingDamage.
  ///
  /// In fr, this message translates to:
  /// **'Notes sur les dégâts existants'**
  String get notesOnExistingDamage;

  /// No description provided for @getTheClientSSignature.
  ///
  /// In fr, this message translates to:
  /// **'Faire signer le client'**
  String get getTheClientSSignature;

  /// No description provided for @unableToLoadDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les documents.'**
  String get unableToLoadDocuments;

  /// No description provided for @readTheContract.
  ///
  /// In fr, this message translates to:
  /// **'Lire le contrat'**
  String get readTheContract;

  /// No description provided for @pleaseReadThisContractSignItWithA.
  ///
  /// In fr, this message translates to:
  /// **'Merci de lire ce contrat, de le signer avec une application PDF comme Adobe Acrobat Reader (Remplir et signer), puis de nous renvoyer le PDF signé.'**
  String get pleaseReadThisContractSignItWithA;

  /// No description provided for @pdfTooLargeMaximum30MB.
  ///
  /// In fr, this message translates to:
  /// **'PDF trop volumineux (maximum 30 Mo).'**
  String get pdfTooLargeMaximum30MB;

  /// No description provided for @fileInaccessibleSaveItOnThePhone.
  ///
  /// In fr, this message translates to:
  /// **'Fichier inaccessible. Enregistrez-le sur le téléphone.'**
  String get fileInaccessibleSaveItOnThePhone;

  /// No description provided for @checkReceivedPDF.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier le PDF reçu'**
  String get checkReceivedPDF;

  /// No description provided for @iHaveCheckedTheClientDatesAmountTerms.
  ///
  /// In fr, this message translates to:
  /// **'J’ai vérifié le client, les dates, le montant, les conditions et la signature. L’application ne vérifie pas automatiquement l’identité du signataire.'**
  String get iHaveCheckedTheClientDatesAmountTerms;

  /// No description provided for @avoidAPINMadeOfTheSameDigit.
  ///
  /// In fr, this message translates to:
  /// **'Évitez un code composé du même chiffre.'**
  String get avoidAPINMadeOfTheSameDigit;

  /// No description provided for @avoidConsecutiveDigits.
  ///
  /// In fr, this message translates to:
  /// **'Évitez une suite de chiffres consécutifs.'**
  String get avoidConsecutiveDigits;

  /// No description provided for @currentPINIsIncorrect.
  ///
  /// In fr, this message translates to:
  /// **'Code actuel incorrect.'**
  String get currentPINIsIncorrect;

  /// No description provided for @theTwoPINsDoNotMatchTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Les deux codes ne correspondent pas. Recommencez.'**
  String get theTwoPINsDoNotMatchTryAgain;

  /// No description provided for @appLocked.
  ///
  /// In fr, this message translates to:
  /// **'Application verrouillée'**
  String get appLocked;

  /// No description provided for @pasteTheCodeSuppliedByYourProvider.
  ///
  /// In fr, this message translates to:
  /// **'Collez le code fourni par votre vendeur.'**
  String get pasteTheCodeSuppliedByYourProvider;

  /// No description provided for @invalidCode.
  ///
  /// In fr, this message translates to:
  /// **'Code invalide.'**
  String get invalidCode;

  /// No description provided for @yourDataWillNotBeDeletedOnlyThe.
  ///
  /// In fr, this message translates to:
  /// **'Vos données ne seront pas effacées. Seul le code PIN est réinitialisé.'**
  String get yourDataWillNotBeDeletedOnlyThe;

  /// No description provided for @iHaveMyRecoveryCode.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai mon code de récupération'**
  String get iHaveMyRecoveryCode;

  /// No description provided for @iLostMyRecoveryCode.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai perdu mon code de récupération'**
  String get iLostMyRecoveryCode;

  /// No description provided for @contactYourProviderAndGiveThemTheID.
  ///
  /// In fr, this message translates to:
  /// **'Contactez votre vendeur et communiquez-lui l\'identifiant ci-dessous. Il vous transmettra un code de déblocage valable 24 heures.'**
  String get contactYourProviderAndGiveThemTheID;

  /// No description provided for @idCopied.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant copié.'**
  String get idCopied;

  /// No description provided for @providerUnlockCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de déblocage du vendeur'**
  String get providerUnlockCode;

  /// No description provided for @pasteTheReceivedCodeHere.
  ///
  /// In fr, this message translates to:
  /// **'Collez ici le code reçu'**
  String get pasteTheReceivedCodeHere;

  /// No description provided for @noPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Aucune photo'**
  String get noPhoto;

  /// No description provided for @message1ItemNeedsAttention.
  ///
  /// In fr, this message translates to:
  /// **'1 point à traiter'**
  String get message1ItemNeedsAttention;

  /// No description provided for @mileage.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage'**
  String get mileage;

  /// No description provided for @transmissioncbe91c.
  ///
  /// In fr, this message translates to:
  /// **'Boîte'**
  String get transmissioncbe91c;

  /// No description provided for @frontRearSidesAndExistingDamage.
  ///
  /// In fr, this message translates to:
  /// **'Avant, arrière, côtés et dégâts existants.'**
  String get frontRearSidesAndExistingDamage;

  /// No description provided for @thisVehicleHasNotBeenRentedYet.
  ///
  /// In fr, this message translates to:
  /// **'Ce véhicule n’a pas encore été loué.'**
  String get thisVehicleHasNotBeenRentedYet;

  /// No description provided for @noVehiclesSaved.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule enregistré.'**
  String get noVehiclesSaved;

  /// No description provided for @addYourFirstVehicleToCreateContracts.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre premier véhicule pour créer des contrats.'**
  String get addYourFirstVehicleToCreateContracts;

  /// No description provided for @notProvidedd6a3c5.
  ///
  /// In fr, this message translates to:
  /// **'Non renseignée'**
  String get notProvidedd6a3c5;

  /// No description provided for @busy9fadb4.
  ///
  /// In fr, this message translates to:
  /// **'Occupés'**
  String get busy9fadb4;

  /// No description provided for @detailsFilledFromTheDocumentCheckThemBefore.
  ///
  /// In fr, this message translates to:
  /// **'Informations remplies depuis le document. Vérifiez-les avant d’enregistrer.'**
  String get detailsFilledFromTheDocumentCheckThemBefore;

  /// No description provided for @unableToReadTheDocumentEnterTheDetails.
  ///
  /// In fr, this message translates to:
  /// **'Lecture du document impossible. Saisissez les informations manuellement.'**
  String get unableToReadTheDocumentEnterTheDetails;

  /// No description provided for @madH.
  ///
  /// In fr, this message translates to:
  /// **'MAD / h'**
  String get madH;

  /// No description provided for @theVehicleWillBecomeAvailableAgain.
  ///
  /// In fr, this message translates to:
  /// **'Le véhicule redeviendra disponible.'**
  String get theVehicleWillBecomeAvailableAgain;

  /// No description provided for @anyPDFPreparedForThisContractWillBe.
  ///
  /// In fr, this message translates to:
  /// **'Le document PDF préparé pour ce contrat, s\'il existe, sera perdu.'**
  String get anyPDFPreparedForThisContractWillBe;

  /// No description provided for @completed3bc597.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get completed3bc597;

  /// No description provided for @noCameraAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caméra disponible.'**
  String get noCameraAvailable;

  /// No description provided for @cameraCapture.
  ///
  /// In fr, this message translates to:
  /// **'Capture Caméra'**
  String get cameraCapture;

  /// No description provided for @unableToOpenThisImage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir cette image.'**
  String get unableToOpenThisImage;

  /// No description provided for @writeThisCodeDownAndKeepItSomewhere.
  ///
  /// In fr, this message translates to:
  /// **'Notez ce code et rangez-le en lieu sûr. C\'est le seul moyen de récupérer vos données si vous oubliez votre code PIN.'**
  String get writeThisCodeDownAndKeepItSomewhere;

  /// No description provided for @itWillNeverBeShownAgain.
  ///
  /// In fr, this message translates to:
  /// **'Il ne vous sera plus jamais affiché.'**
  String get itWillNeverBeShownAgain;

  /// No description provided for @unableToCompleteThisActionTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de terminer cette opération. Réessayez.'**
  String get unableToCompleteThisActionTryAgain;

  /// No description provided for @continueAction.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueAction;

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez dans {p0}.'**
  String retryAfter(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule #{p0}'**
  String vehicleNumber(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Client #{p0}'**
  String clientNumber(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} est actif. Les données affichées restent celles de l’agence.'**
  String modelActive(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} copié.'**
  String copiedValue(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'CIN {p0}'**
  String nationalIdValue(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Permis · {p0}'**
  String licenceStatus(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'+ {p0} autre(s) contrat(s)'**
  String otherContracts(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir {p0}'**
  String enlargeImage(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} rappel(s) programmé(s).'**
  String scheduledReminderCount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} heure(s) avant'**
  String leadHours(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} minutes avant'**
  String leadMinutes(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'De {p0} à {p1} : reporté au matin.'**
  String quietHoursSummary(String p0, String p1);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Après {p0} minutes en arrière-plan'**
  String lockDelayMinutes(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Reste à payer : {p0}'**
  String balanceDueAmount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Il reste {p0} à payer. Voulez-vous enregistrer ce paiement avant la clôture ?'**
  String payBeforeClosing(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Le retour était prévu le {p0}.'**
  String returnWasDue(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Il reste {p0} à encaisser sur ce contrat terminé.'**
  String completedContractBalance(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Fait le {p0}'**
  String completedOn(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Reste {p0} à encaisser.'**
  String balanceToCollect(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} jour(s)'**
  String rentalDays(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Chauffeur #{p0}'**
  String driverNumber(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} versement(s)'**
  String paymentCount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Modifier {p0}'**
  String editRecord(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Durée : {p0} jour(s)'**
  String durationDays(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Le permis du conducteur principal est expiré ({p0}).'**
  String mainLicenceExpired(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Le permis du conducteur secondaire est expiré ({p0}).'**
  String additionalLicenceExpired(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Total {p0}'**
  String totalAmount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} disponible(s)'**
  String availableCount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} · carburant {p1} % · {p2}'**
  String departureReading(String p0, String p1, String p2);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} parcourus'**
  String distanceTravelled(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0}/{p1} prises · touchez une case pour photographier.'**
  String photosTaken(String p0, String p1);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un code à {p0} chiffres. Il protège vos clients, contrats et documents sur cet appareil.'**
  String choosePinDigits(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre code à {p0} chiffres'**
  String enterPinDigits(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Le code de récupération compte {p0} chiffres.'**
  String recoveryCodeDigits(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Les {p0} chiffres affichés lors de la création de votre code PIN.'**
  String recoveryCodeHint(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Voir les {p0}'**
  String seeCount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Année {p0}'**
  String vehicleYear(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} points à traiter'**
  String attentionCount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} point(s) à surveiller'**
  String monitorCount(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté le {p0} · modifié le {p1}'**
  String recordDates(String p0, String p1);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} véhicule(s) · {p2} disponible(s)'**
  String fleetSummary(String p0, String p2);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} sera retiré de la liste des chauffeurs. Les contrats existants ne sont pas modifiés.'**
  String removeDriverConfirmation(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Les {p0} de paiements enregistrés seront supprimés.'**
  String deletePaymentsConfirmation(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Le contrat n° {p0} sera supprimé définitivement. Cette action est irréversible.'**
  String deleteContractConfirmation(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Status: {p0}'**
  String searchStatus(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Image introuvable : {p0}'**
  String missingImage(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} j'**
  String dayShort(String p0);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} h × {p1}'**
  String hourlyDriverCost(String p0, String p1);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} → {p1} · {p2} j'**
  String rentalDateRange(String p0, String p1, String p2);

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'Reste {p0}'**
  String balanceAmount(String p0);

  /// No description provided for @remainingBalance.
  ///
  /// In fr, this message translates to:
  /// **'Reste à payer'**
  String get remainingBalance;

  /// Parameterized interface message. Values are provided by the presentation layer.
  ///
  /// In fr, this message translates to:
  /// **'{p0} j restants'**
  String remainingDayCount(String p0);

  /// No description provided for @daysRemaining.
  ///
  /// In fr, this message translates to:
  /// **'j restants'**
  String get daysRemaining;

  /// No description provided for @assistantWriteQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez votre question.'**
  String get assistantWriteQuestion;

  /// No description provided for @assistantNoAvailableCars.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule disponible actuellement.'**
  String get assistantNoAvailableCars;

  /// No description provided for @assistantNoCars.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule enregistré pour le moment.'**
  String get assistantNoCars;

  /// No description provided for @assistantNoClients.
  ///
  /// In fr, this message translates to:
  /// **'Aucun client enregistré pour le moment.'**
  String get assistantNoClients;

  /// No description provided for @assistantNoDrivers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun chauffeur enregistré pour le moment.'**
  String get assistantNoDrivers;

  /// No description provided for @assistantNoLate.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contrat actif en retard.'**
  String get assistantNoLate;

  /// No description provided for @assistantNoBalance.
  ///
  /// In fr, this message translates to:
  /// **'Aucun solde restant sur les contrats actifs.'**
  String get assistantNoBalance;

  /// No description provided for @assistantNoDeadline.
  ///
  /// In fr, this message translates to:
  /// **'Aucune échéance correspondante n’est renseignée ou proche.'**
  String get assistantNoDeadline;

  /// No description provided for @assistantBackupHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez Paramètres, puis Sauvegarde et restauration. La sauvegarde crée un ZIP avec les données et documents.'**
  String get assistantBackupHelp;

  /// No description provided for @assistantInspectionHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez le contrat concerné. Vous pouvez remplir l’état des lieux de départ ou de retour avec kilométrage, carburant, photos et dégâts.'**
  String get assistantInspectionHelp;

  /// No description provided for @assistantHelp.
  ///
  /// In fr, this message translates to:
  /// **'Je peux aider avec les véhicules disponibles, contrats en retard, paiements en attente, alertes d’entretien, sauvegardes et états des lieux.'**
  String get assistantHelp;

  /// No description provided for @assistantPendingSignature.
  ///
  /// In fr, this message translates to:
  /// **'Signature client : en attente'**
  String get assistantPendingSignature;

  /// No description provided for @assistantSavedSignature.
  ///
  /// In fr, this message translates to:
  /// **'Signature client : enregistrée'**
  String get assistantSavedSignature;

  /// No description provided for @assistantUnknown.
  ///
  /// In fr, this message translates to:
  /// **'inconnu'**
  String get assistantUnknown;

  /// No description provided for @assistantMore.
  ///
  /// In fr, this message translates to:
  /// **' et {p0} autre(s).'**
  String assistantMore(String p0);

  /// No description provided for @assistantFleet.
  ///
  /// In fr, this message translates to:
  /// **'{p0} véhicule(s) {p1} : {p2}{p3}'**
  String assistantFleet(String p0, String p1, String p2, String p3);

  /// No description provided for @assistantAvailable.
  ///
  /// In fr, this message translates to:
  /// **'disponible(s)'**
  String get assistantAvailable;

  /// No description provided for @assistantRecorded.
  ///
  /// In fr, this message translates to:
  /// **'enregistré(s)'**
  String get assistantRecorded;

  /// No description provided for @assistantClientList.
  ///
  /// In fr, this message translates to:
  /// **'{p0} client(s) enregistré(s) : {p1}{p2}'**
  String assistantClientList(String p0, String p1, String p2);

  /// No description provided for @assistantDriverList.
  ///
  /// In fr, this message translates to:
  /// **'{p0} chauffeur(s) enregistré(s) : {p1}{p2}'**
  String assistantDriverList(String p0, String p1, String p2);

  /// No description provided for @assistantLateList.
  ///
  /// In fr, this message translates to:
  /// **'{p0} contrat(s) en retard : {p1}'**
  String assistantLateList(String p0, String p1);

  /// No description provided for @assistantPaymentList.
  ///
  /// In fr, this message translates to:
  /// **'{p0} paiement(s) en attente, pour {p1} MAD : {p2}'**
  String assistantPaymentList(String p0, String p1, String p2);

  /// No description provided for @assistantVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule : {p0}'**
  String assistantVehicle(String p0);

  /// No description provided for @assistantClient.
  ///
  /// In fr, this message translates to:
  /// **'Client : {p0}'**
  String assistantClient(String p0);

  /// No description provided for @assistantStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut : {p0}'**
  String assistantStatus(String p0);

  /// No description provided for @assistantDeparture.
  ///
  /// In fr, this message translates to:
  /// **'Départ : {p0}'**
  String assistantDeparture(String p0);

  /// No description provided for @assistantReturn.
  ///
  /// In fr, this message translates to:
  /// **'Retour prévu : {p0}'**
  String assistantReturn(String p0);

  /// No description provided for @assistantTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total : {p0} MAD'**
  String assistantTotal(String p0);

  /// No description provided for @assistantPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payé : {p0} MAD'**
  String assistantPaid(String p0);

  /// No description provided for @assistantBalance.
  ///
  /// In fr, this message translates to:
  /// **'Reste : {p0} MAD'**
  String assistantBalance(String p0);

  /// No description provided for @assistantDriver.
  ///
  /// In fr, this message translates to:
  /// **'Chauffeur : {p0}'**
  String assistantDriver(String p0);

  /// No description provided for @assistantPayments.
  ///
  /// In fr, this message translates to:
  /// **'Paiements enregistrés : {p0}'**
  String assistantPayments(String p0);

  /// No description provided for @assistantInspections.
  ///
  /// In fr, this message translates to:
  /// **'États des lieux : {p0}'**
  String assistantInspections(String p0);

  /// No description provided for @assistantId.
  ///
  /// In fr, this message translates to:
  /// **'CIN : {p0}'**
  String assistantId(String p0);

  /// No description provided for @assistantLicence.
  ///
  /// In fr, this message translates to:
  /// **'Permis : {p0}'**
  String assistantLicence(String p0);

  /// No description provided for @assistantPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone : {p0}'**
  String assistantPhone(String p0);

  /// No description provided for @assistantEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email : {p0}'**
  String assistantEmail(String p0);

  /// No description provided for @assistantContracts.
  ///
  /// In fr, this message translates to:
  /// **'Contrats : {p0}, dont {p1} actif(s).'**
  String assistantContracts(String p0, String p1);

  /// No description provided for @assistantDriverDetails.
  ///
  /// In fr, this message translates to:
  /// **'{p0}\nCIN : {p1}\nPermis : {p2}\nTéléphone : {p3}\nStatut : {p4}\nPrix : {p5} MAD/heure\nContrats liés : {p6}'**
  String assistantDriverDetails(String p0, String p1, String p2, String p3,
      String p4, String p5, String p6);

  /// No description provided for @assistantVehicleNoContract.
  ///
  /// In fr, this message translates to:
  /// **'{p0} n’a pas de contrat actif.'**
  String assistantVehicleNoContract(String p0);

  /// No description provided for @assistantVehicleRental.
  ///
  /// In fr, this message translates to:
  /// **'{p0} est loué avec le contrat {p1}. Retour prévu : {p2}. Reste à encaisser : {p3} MAD. Client : {p4}.'**
  String assistantVehicleRental(
      String p0, String p1, String p2, String p3, String p4);

  /// No description provided for @assistantVehicleNoDeadline.
  ///
  /// In fr, this message translates to:
  /// **'{p0} : aucune échéance proche renseignée.'**
  String assistantVehicleNoDeadline(String p0);

  /// No description provided for @assistantYear.
  ///
  /// In fr, this message translates to:
  /// **'Année : {p0}'**
  String assistantYear(String p0);

  /// No description provided for @assistantMileage.
  ///
  /// In fr, this message translates to:
  /// **'Kilométrage : {p0} km'**
  String assistantMileage(String p0);

  /// No description provided for @assistantFuel.
  ///
  /// In fr, this message translates to:
  /// **'Carburant : {p0}'**
  String assistantFuel(String p0);

  /// No description provided for @assistantGearbox.
  ///
  /// In fr, this message translates to:
  /// **'Boîte : {p0}'**
  String assistantGearbox(String p0);

  /// No description provided for @assistantFuelLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau carburant : {p0}%'**
  String assistantFuelLevel(String p0);

  /// No description provided for @assistantCondition.
  ///
  /// In fr, this message translates to:
  /// **'État : {p0}'**
  String assistantCondition(String p0);

  /// No description provided for @assistantInsurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance : {p0}'**
  String assistantInsurance(String p0);

  /// No description provided for @assistantInspection.
  ///
  /// In fr, this message translates to:
  /// **'Visite technique : {p0}'**
  String assistantInspection(String p0);

  /// No description provided for @assistantTax.
  ///
  /// In fr, this message translates to:
  /// **'Vignette : {p0}'**
  String assistantTax(String p0);

  /// No description provided for @assistantWarning.
  ///
  /// In fr, this message translates to:
  /// **'{p0} — {p1} {p2}'**
  String assistantWarning(String p0, String p1, String p2);

  /// No description provided for @assistantLateDays.
  ///
  /// In fr, this message translates to:
  /// **'en retard de {p0} j'**
  String assistantLateDays(String p0);

  /// No description provided for @assistantInDays.
  ///
  /// In fr, this message translates to:
  /// **'dans {p0} j'**
  String assistantInDays(String p0);

  /// No description provided for @overdueHours.
  ///
  /// In fr, this message translates to:
  /// **'En retard de {p0} h'**
  String overdueHours(String p0);

  /// No description provided for @overdueDays.
  ///
  /// In fr, this message translates to:
  /// **'En retard de {p0} j'**
  String overdueDays(String p0);

  /// No description provided for @expiredDays.
  ///
  /// In fr, this message translates to:
  /// **'Expiré depuis {p0} j'**
  String expiredDays(String p0);

  /// No description provided for @expiresInDays.
  ///
  /// In fr, this message translates to:
  /// **'Expire dans {p0} j'**
  String expiresInDays(String p0);

  /// No description provided for @returnTodayAt.
  ///
  /// In fr, this message translates to:
  /// **'Retour aujourd’hui à {p0}'**
  String returnTodayAt(String p0);

  /// No description provided for @returnTomorrowAt.
  ///
  /// In fr, this message translates to:
  /// **'Retour demain à {p0}'**
  String returnTomorrowAt(String p0);

  /// No description provided for @returnInDays.
  ///
  /// In fr, this message translates to:
  /// **'Retour dans {p0} j'**
  String returnInDays(String p0);

  /// No description provided for @returnedOn.
  ///
  /// In fr, this message translates to:
  /// **'Rendu le {p0}'**
  String returnedOn(String p0);

  /// No description provided for @unpaidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Non payé · {p0}'**
  String unpaidAmount(String p0);

  /// No description provided for @fleetCount.
  ///
  /// In fr, this message translates to:
  /// **'{p0} véhicule(s) · {p1} disponible(s)'**
  String fleetCount(String p0, String p1);

  /// No description provided for @signedOnDate.
  ///
  /// In fr, this message translates to:
  /// **'Signé le {p0}'**
  String signedOnDate(String p0);

  /// No description provided for @receivedOnDate.
  ///
  /// In fr, this message translates to:
  /// **'Reçu le {p0}'**
  String receivedOnDate(String p0);

  /// No description provided for @overdueDistance.
  ///
  /// In fr, this message translates to:
  /// **'Dépassée de {p0}'**
  String overdueDistance(String p0);

  /// No description provided for @inDistance.
  ///
  /// In fr, this message translates to:
  /// **'Dans {p0}'**
  String inDistance(String p0);

  /// No description provided for @pinAttempts.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect. {p0} essai(s) restant(s).'**
  String pinAttempts(String p0);

  /// No description provided for @secondsUnit.
  ///
  /// In fr, this message translates to:
  /// **'{p0} s'**
  String secondsUnit(String p0);

  /// No description provided for @minutesUnit.
  ///
  /// In fr, this message translates to:
  /// **'{p0} min'**
  String minutesUnit(String p0);

  /// No description provided for @profitability.
  ///
  /// In fr, this message translates to:
  /// **'Rentabilité'**
  String get profitability;

  /// No description provided for @revenue.
  ///
  /// In fr, this message translates to:
  /// **'Revenu'**
  String get revenue;

  /// No description provided for @utilizationRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'utilisation'**
  String get utilizationRate;

  /// No description provided for @netProfit.
  ///
  /// In fr, this message translates to:
  /// **'Bénéfice net'**
  String get netProfit;

  /// No description provided for @totalExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get totalExpenses;

  /// No description provided for @expenseCategoryRepair.
  ///
  /// In fr, this message translates to:
  /// **'Réparation'**
  String get expenseCategoryRepair;

  /// No description provided for @expenseCategoryInsurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get expenseCategoryInsurance;

  /// No description provided for @expenseCategoryFine.
  ///
  /// In fr, this message translates to:
  /// **'Amende'**
  String get expenseCategoryFine;

  /// No description provided for @expenseCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get expenseCategoryOther;

  /// No description provided for @addAnExpense.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une dépense'**
  String get addAnExpense;

  /// No description provided for @expenseAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get expenseAmount;

  /// No description provided for @expenseDateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Date de la dépense'**
  String get expenseDateLabel;

  /// No description provided for @expenseCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get expenseCategoryLabel;

  /// No description provided for @expenseNoteOptional.
  ///
  /// In fr, this message translates to:
  /// **'Note (optionnel)'**
  String get expenseNoteOptional;

  /// No description provided for @noExpensesRecordedForThisVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dépense enregistrée pour ce véhicule.'**
  String get noExpensesRecordedForThisVehicle;

  /// No description provided for @fleetProfitability.
  ///
  /// In fr, this message translates to:
  /// **'Rentabilité de la flotte'**
  String get fleetProfitability;

  /// No description provided for @fleetTotalRevenue.
  ///
  /// In fr, this message translates to:
  /// **'Revenu total'**
  String get fleetTotalRevenue;

  /// No description provided for @fleetTotalExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses totales'**
  String get fleetTotalExpenses;

  /// No description provided for @fleetTotalNetProfit.
  ///
  /// In fr, this message translates to:
  /// **'Bénéfice net total'**
  String get fleetTotalNetProfit;

  /// No description provided for @noVehiclesToRank.
  ///
  /// In fr, this message translates to:
  /// **'Aucun véhicule à classer.'**
  String get noVehiclesToRank;

  /// No description provided for @expenseSaved.
  ///
  /// In fr, this message translates to:
  /// **'Dépense enregistrée.'**
  String get expenseSaved;

  /// No description provided for @expenseDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Dépense supprimée.'**
  String get expenseDeleted;

  /// No description provided for @notTrackedYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore suivi.'**
  String get notTrackedYet;

  /// No description provided for @deleteThisExpenseQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette dépense ?'**
  String get deleteThisExpenseQuestion;

  /// No description provided for @enterAValidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un montant valide.'**
  String get enterAValidAmount;

  /// No description provided for @rentalDaysLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jours loués'**
  String get rentalDaysLabel;

  /// No description provided for @includedFeatures.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalités incluses'**
  String get includedFeatures;

  /// No description provided for @customerHistoryFeatureLabel.
  ///
  /// In fr, this message translates to:
  /// **'Historique client avancé'**
  String get customerHistoryFeatureLabel;

  /// No description provided for @clientHistorySectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique client'**
  String get clientHistorySectionTitle;

  /// No description provided for @totalRentalsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Locations totales'**
  String get totalRentalsLabel;

  /// No description provided for @lateReturnsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Retours en retard'**
  String get lateReturnsLabel;

  /// No description provided for @unpaidBalanceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Solde impayé'**
  String get unpaidBalanceLabel;

  /// No description provided for @damageIncidentsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Incidents de dommages'**
  String get damageIncidentsLabel;

  /// No description provided for @requiresManagerApprovalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nécessite l\'approbation du gérant'**
  String get requiresManagerApprovalLabel;

  /// No description provided for @requiresManagerApprovalSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un rappel affiché à la prochaine location de ce client'**
  String get requiresManagerApprovalSubtitle;

  /// No description provided for @clientRequiresApprovalWarning.
  ///
  /// In fr, this message translates to:
  /// **'Ce client nécessite une validation du gérant avant la location.'**
  String get clientRequiresApprovalWarning;

  /// No description provided for @profitabilityFeatureLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rentabilité par véhicule'**
  String get profitabilityFeatureLabel;

  /// No description provided for @featureNotIncludedInLicence.
  ///
  /// In fr, this message translates to:
  /// **'Cette fonctionnalité n\'est pas incluse dans votre licence.'**
  String get featureNotIncludedInLicence;
}

class _AppMessagesDelegate extends LocalizationsDelegate<AppMessages> {
  const _AppMessagesDelegate();

  @override
  Future<AppMessages> load(Locale locale) {
    return SynchronousFuture<AppMessages>(lookupAppMessages(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppMessagesDelegate old) => false;
}

AppMessages lookupAppMessages(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppMessagesAr();
    case 'en':
      return AppMessagesEn();
    case 'fr':
      return AppMessagesFr();
  }

  throw FlutterError(
      'AppMessages.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
