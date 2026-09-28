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
	*   Controller for AccountController
	* 
	* TEST CLASS 
	* 
	*   AccountController_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 4/19/2024; snguyen/Forefront; Initial Build
	* 
**/
public with sharing class AccountController {

    @AuraEnabled
    public static Account getCurrentUsersAccount() {
        try {
            return BuyerService.effectiveAccount;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}