/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 13.03.2024
 * @description Test suite
 *
 */

@IsTest
private class OrderCreatedEventTriggerHandler_TEST {
	@IsTest(SeeAllData=true) // due to connect api limitations
	static void testBehavior() {
		// given
		Id orderSummaryId = XaCalloutController_TEST.createOrderSummary();
		Order order = [
			SELECT
				OriginalOrder.External_Id__c,
				OriginalOrder.Id
			FROM OrderSummary
			WHERE Id = :orderSummaryId
		].OriginalOrder;

		// external id and integrated field must be null
		// otherwise the order sending logic will not be triggered
		order.External_Id__c = null;
		order.Integrated__c = false;
		update order;

		// when
		Test.startTest();
		{
			EventBus.publish(new OrderSummaryCreatedEvent(
				OrderSummaryId = orderSummaryId,
				OrderId = order.Id
			));
		}
		Test.stopTest();

		// then
		OrderSummary updated = [
			SELECT Id,
				OriginalOrder.Integrated__c,
				OriginalOrder.Integration_Status__c
			FROM OrderSummary
			WHERE Id = :orderSummaryId
		];

		Assert.isFalse(updated.OriginalOrder.Integrated__c);
		Assert.isNotNull(updated.OriginalOrder.Integration_Status__c);
	}
}