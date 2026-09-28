/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 13.03.2024 <p/>
 * @test OrderCreatedEventTriggerHandler_TEST
 *
 */
public without sharing class OrderCreatedEventTriggerHandler extends TriggerHandler {
	protected override void afterInsert() {
		List<OrderSummaryCreatedEvent> created = Trigger.new;

		Set<Id> orderIds = Stream.of(created).ids(OrderSummaryCreatedEvent.OrderId);
		List<Order> orders = XaCalloutController.fetchOrders(orderIds);

		for(Order order : orders) {
			if(isOrderAlreadyIntegrated(order)) {
				continue;
			}

			try {
				ExternalService.XaApiService.putOrder_Response res = XaCalloutController.createOrder(order);

				order.Integrated__c = true;
				order.Integration_Status__c = res.Code202.message;
			}
			catch(Exception ex) {
				order.Integrated__c = false;
				order.Integration_Status__c = ex.getMessage() + '\n\n' + ex.getStackTraceString();
				Logger.error(ex.getMessage(), order, ex);
				Logger.saveLog();
			}
		}

		update orders;
	}

	private static Boolean isOrderAlreadyIntegrated(Order order) {
		return order.Integrated__c || String.isNotBlank(order.External_Id__c);
	}

}