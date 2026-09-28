/**
	* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author snguyen/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	* 
	*   Controller for AccountController_TEST
	* 
	* TEST CLASS 
	* 
	*   AccountController_TEST_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 4/19/2024; snguyen/Forefront; Initial Build
	* 
**/
@IsTest
private class AccountController_TEST {

    @IsTest
    static void testGetCurrentUsersAccount_success() {
        b2btd.xAccount testAccount = new b2btd.xAccount();
        testAccount.set('Salesman_Text__c', 'TestSalesman');
        testAccount.set('Territory_Text__c', 'TestTerritory');
        b2btd.xContact contact = new b2btd.xContact().withAccount(testAccount);
        contact.set('MailingCountryCode', 'US');
        contact.set('MailingCountry', 'United States');
        testAccount.persist();
        Contact con = (Contact) contact.persist();
        BuyerContext.testContact = con;

        Account expectedAccount = (Account) testAccount.getRecord();
        Account actualAccount = AccountController.getCurrentUsersAccount();

        Assert.areEqual(expectedAccount.Id, actualAccount.Id);
        Assert.areEqual(expectedAccount.Name, actualAccount.Name);
        Assert.areEqual(expectedAccount.Salesman_Text__c, actualAccount.Salesman_Text__c);
        Assert.areEqual(expectedAccount.Territory_Text__c, actualAccount.Territory_Text__c);
    }

    @IsTest
    static void testGetCurrentUsersAccount_failure() {
        Boolean exceptionThrown = false;
        try {
            AccountController.getCurrentUsersAccount();
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Assert.isTrue(exceptionThrown);
    }
}