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
	*   Controller for CustomSatisfactionSurveyController
	* 
	* TEST CLASS 
	* 
	*   CustomSatisfactionSurveyController_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 3/22/2024; snguyen/Forefront; Initial Build
	* 
**/
public without sharing class CustomerSatisfactionSurveyCtrl {

    @AuraEnabled
    public static Boolean hasOrderAlreadyBeenReviewed(String orderNumber) {
        try {
            Id orderId = [SELECT OriginalOrderId FROM OrderSummary WHERE OrderNumber =: orderNumber].OriginalOrderId;

            return [SELECT COUNT() FROM Customer_Satisfaction__c WHERE Order__c =: orderId AND Contact__c =: BuyerService.currentContact.Id] > 0;
        } catch (Exception e) {
            throw new AuraHandledException(AuraHandledExceptionBuilder.buildClientMessage(e));
        }
    }

    @AuraEnabled
    public static void addCustomerSatisfaction(String orderNumber, Boolean isSatisfied, String comments) {
        try {
            Id orderId = [SELECT OriginalOrderId FROM OrderSummary WHERE OrderNumber =: orderNumber].OriginalOrderId;

            Customer_Satisfaction__c customerSatisfactionResponse = new Customer_Satisfaction__c(
                    Contact__c = BuyerService.currentContact.Id,
                    Order__c = orderId,
                    Comments__c = comments,
                    Satisfied__c = isSatisfied
            );
            insert customerSatisfactionResponse;
        } catch (Exception e) {
            throw new AuraHandledException(AuraHandledExceptionBuilder.buildClientMessage(e));
        }
    }
}