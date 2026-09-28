/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 22.10.2024
 * @test SendOrderToXaController_TEST_TEST
 * 
 **/

@IsTest
private class SendOrderToXaController_TEST {
	@IsTest
	static void testSending_failure() {
        // given
        b2btd.xOrder order = new b2btd.xOrder();
        order.persist();

        // when
        SendOrderToXaController.sendOrderToXa(order.id);

        // then
        Assert.areEqual(
            false,
            [SELECT Integrated__c FROM Order WHERE Id = :order.id].Integrated__c,
            'Order should not be integrated'
        );
	}


    @IsTest
    static void testSending_success() {
        // given
        b2btd.xOrder order = XaCalloutController_TEST.createOrder();

        String mockServerResponse = '{ "message": "Order Created Successfully" }';

        Test.setMock(HttpCalloutMock.class, new XaCalloutController_TEST.HttpMock(202, mockServerResponse));

        // when
        Test.startTest();
        SendOrderToXaController.sendOrderToXa(order.id);
        Test.stopTest();

        // then
        Assert.areEqual(
            true,
            [SELECT Integrated__c FROM Order WHERE Id = :order.id].Integrated__c,
            'Order should be integrated'
        );
    }
}