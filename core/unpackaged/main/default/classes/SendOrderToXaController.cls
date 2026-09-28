/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 22.10.2024
 * @test SendOrderToXaController_TEST
 * 
 **/

public with sharing class SendOrderToXaController {

	@AuraEnabled
	public static Boolean sendOrderToXa(Id orderId) {
		Order order = XaCalloutController.fetchOrder(orderId);

		try {
			ExternalService.XaApiService.putOrder_Response xaRes = XaCalloutController.createOrder(order);

			order.Integrated__c = true;
			order.Integration_Status__c = xaRes.Code202.message;

			update as system order;
			return true;

		} catch (Exception ex) {
			order.Integrated__c = false;
			order.Integration_Status__c = ex.getMessage() + '\n\n' + ex.getStackTraceString();

			update as system order;
			return false;
		}
	}
}