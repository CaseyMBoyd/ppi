/**
 * Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jakub_cichacki/Forefront
 * @version 1.0
 * @description
 *
 * PURPOSE
 *
 *
 *
 * TEST CLASS
 *
 *
 *
 * ENTRY POINTS
 *
 *
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 13.03.2023; jakub_cichacki/Forefront; Initial Build
 *
 **/
public virtual with sharing class BuyerContext implements IBuyerContext {
    private static IBuyerContext instance;

    public static IBuyerContext getInstance() {
        if (instance == null) {
            instance = (IBuyerContext) ServiceFactory.get(BuyerContext.class);
        }
        return instance;
    }

    public static void overrideState(Id webstoreId, Id effectiveAccountId) {
        overrideWebstoreId = webstoreId;
        overrideEffectiveAccountId = effectiveAccountId;
    }

    @TestVisible
    private static Id overrideWebstoreId;

    @TestVisible
    private static Id overrideEffectiveAccountId;

    @TestVisible
    private static Contact testContact;
    @TestVisible
    private static Id mockCurrentEffectiveAccountId;
    @TestVisible
    private static Network testNetwork;

    private static Account currentEffectiveAccount {
        get {
            if (currentEffectiveAccount == null) {
                Id effectiveAccountId = currentContact.AccountId ?? overrideEffectiveAccountId;
                currentEffectiveAccount = [SELECT Id, Name, ParentId, Salesman_Text__c, Salesman_Email__c, Territory_Text__c, Territory_Email__c FROM Account WHERE Id = :effectiveAccountId];
            }
            return currentEffectiveAccount;
        }
        set;
    }

    private static Network currentNetwork {
        get {
            if (currentNetwork == null) {
                currentNetwork = Test.isRunningTest() ? testNetwork : [SELECT Id, Name, UrlPathPrefix FROM Network WHERE Id = :Network.getNetworkId()];
            }
            return currentNetwork;
        }
        private set;
    }


    private static Id currentEffectiveAccountId {
        get {
            if (Test.isRunningTest()) {
                return mockCurrentEffectiveAccountId;
            } else if (currentEffectiveAccountId == null) {
                currentEffectiveAccountId = isGuestUser(currentUser) ? [SELECT Id FROM GuestBuyerProfile LIMIT 1].Id : overrideEffectiveAccountId ?? currentContact?.AccountId;
            }
            return currentEffectiveAccountId;
        }
        set;
    }

    private static Contact currentContact {
        get {
            if (currentContact == null) {
                currentContact = Test.isRunningTest() ? testContact : [SELECT Id, FirstName, LastName, AccountId FROM Contact WHERE Id = :currentUser.ContactId];
            }
            return currentContact;
        }
        private set;
    }

    private static User currentUser {
        get {
            if (currentUser == null) {
                currentUser = [
                    SELECT Id, ContactId, Email, AccountId, Account.Name, Profile.Name, UserType
                    FROM User
                    WHERE Id = :UserInfo.getUserId()
                ];
            }
            return currentUser;
        }
        private set;
    }

    private static WebStore currentWebStore {
        get {
            if (currentWebStore == null) {
                Id webstoreId = !Test.isRunningTest() ? ([SELECT WebStoreId FROM WebStoreNetwork WHERE NetworkId = :Network.getNetworkId() LIMIT 1]?.WebStoreId ?? overrideWebstoreId) : overrideWebstoreId;

                currentWebStore = [
                    SELECT
                        DefaultLanguage,
                        Description,
                        MaxValuesPerFacet,
                        StrikethroughPricebookId,
                        PricingStrategy,
                        PaginationSize,
                        Name,
                        SupportedLanguages
                    FROM WebStore
                    WHERE Id = :webstoreId
                ];
            }

            return currentWebStore;
        }
        private set;
    }

    public virtual Id getEffectiveAccountId() {
        return currentEffectiveAccountId;
    }

    public virtual WebStore getWebstore() {
        return currentWebStore;
    }

    public virtual Account getEffectiveAccount() {
        return currentEffectiveAccount;
    }

    public virtual Contact getContact() {
        return currentContact;
    }

    public virtual User getUser() {
        return currentUser;
    }

    public virtual Network getNetwork() {
        return currentNetwork;
    }
    @TestVisible
    private static Boolean isGuestUser(User u) {
        return 'Guest'.equals(u.UserType);
    }
}