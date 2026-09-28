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
	*   Controller for CustomerSatisfactionSurveyCtrl_TEST
	* 
	* TEST CLASS 
	* 
	*   CustomerSatisfactionSurveyCtrl_TEST_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 3/29/2024; snguyen/Forefront; Initial Build
	* 
**/
@IsTest
private class CustomerSatisfactionSurveyCtrl_TEST {
    @IsTest(SeeAllData = true)
    static void testHasOrderAlreadyBeenReviewed_success() {
        Id orderSummaryId = createOrderSummary();

        OrderSummary testOrderSummary = [SELECT OrderNumber, OriginalOrderId FROM OrderSummary WHERE Id = :orderSummaryId];

        b2btd.xContact contact = new b2btd.xContact();
        Contact testContact = (Contact) contact.persist();
        BuyerContext.testContact = testContact;

        Customer_Satisfaction__c testCustomerSatisfaction = new Customer_Satisfaction__c(
                Contact__c = testContact.Id,
                Order__c = testOrderSummary.OriginalOrderId,
                Comments__c = 'Test Comments',
                Satisfied__c = true
        );
        insert testCustomerSatisfaction;

        Test.startTest();
        Boolean hasOrderBeenReviewed = CustomerSatisfactionSurveyCtrl.hasOrderAlreadyBeenReviewed(testOrderSummary.OrderNumber);
        Test.stopTest();

        Assert.isTrue(hasOrderBeenReviewed);
    }

    @IsTest
    static void testHasOrderAlreadyBeenReviewed_failure() {
        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            CustomerSatisfactionSurveyCtrl.hasOrderAlreadyBeenReviewed(null);
            Test.stopTest();
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Assert.isTrue(exceptionThrown);
    }

    @IsTest(SeeAllData = true)
    static void testAddCustomerSatisfaction_success() {
        Id orderSummaryId = createOrderSummary();

        OrderSummary testOrderSummary = [SELECT OrderNumber, OriginalOrderId FROM OrderSummary WHERE Id = :orderSummaryId];

        b2btd.xContact contact = new b2btd.xContact();
        Contact testContact = (Contact) contact.persist();
        BuyerContext.testContact = testContact;

        String comments = 'Test Comments';

        Test.startTest();
        CustomerSatisfactionSurveyCtrl.addCustomerSatisfaction(
                testOrderSummary.OrderNumber,
                true,
                comments
        );
        Test.stopTest();

        List<Customer_Satisfaction__c> actualResult = [
                SELECT Comments__c,
                        Satisfied__c
                FROM Customer_Satisfaction__c
                WHERE Contact__c = :testContact.Id
                AND Order__c = :testOrderSummary.OriginalOrderId
        ];

        Assert.areEqual(comments, actualResult.get(0).Comments__c);
        Assert.isTrue(actualResult.get(0).Satisfied__c);
    }

    @IsTest
    static void testAddCustomerSatisfaction_failure() {
        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            CustomerSatisfactionSurveyCtrl.addCustomerSatisfaction(null, null, null);
            Test.stopTest();
        } catch (Exception e) {
            exceptionThrown = true;
        }

        Assert.isTrue(exceptionThrown);
    }

    public static Id createOrderSummary() {
        // given
        b2btd.xOrder order = createOrder();

        String orderNumber = 'test_order_number';
        ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
        orderSummaryInput.name = orderNumber;
        orderSummaryInput.externalReferenceIdentifier = orderNumber;
        orderSummaryInput.orderId = order.id;
        orderSummaryInput.orderLifeCycleType = 'MANAGED';
        orderSummaryInput.status = 'Created';

        ConnectApi.OrderSummaryOutputRepresentation summaryCreateResult =
                ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);

        return summaryCreateResult.orderSummaryId;
    }

    private static b2btd.xOrder createOrder() {
        b2btd.xOrder order = new b2btd.xOrder();

        order.persist();

        new b2btd.xOrderDeliveryMethod().persist();

        b2btd.xOrderDeliveryGroup deliveryGroup = new b2btd.xOrderDeliveryGroup()
                .withOrder(order);

        deliveryGroup.persist();

        b2btd.xOrderItem item = new b2btd.xOrderItem()
                .orderDeliveryGroup(deliveryGroup.Id)
                .withOrder(order);

        item.persist();

        update new Order(
                Id = order.Id,
                Status = 'Activated',
                OrderedDate = Date.today(),
                External_Id__c = '201111230112'
        );
        return order;
    }
}