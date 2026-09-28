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
	*   Controller for OrderConfirmationEmailItemsCtrl_TEST
	* 
	* TEST CLASS 
	* 
	*   OrderConfirmationEmailItemsCtrl_TEST_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 3/27/2024; snguyen/Forefront; Initial Build
	* 
**/
@IsTest
private class OrderConfirmationEmailItemsCtrl_TEST {
    @IsTest(SeeAllData=true)
    static void testOrderConfirmationEmailItems() {
        // given
        b2btd.xProduct product = new b2btd.xProduct();
        product.persist();

        List<OrderItemSummary> items = new List<OrderItemSummary>{
                new OrderItemSummary(Product2Id = product.id, Quantity = 10)
        };

        b2btd.xAccount account = (b2btd.xAccount) new b2btd.xAccount();
        account.persist();

        b2btd.xContact contact = new b2btd.xContact().withAccount(account);
        contact.persist();

        b2btd.xBuyerGroup buyerGroup = new b2btd.xBuyerGroup().name('Test bg');
        buyerGroup.persist();

        b2btd.xEntitlementPolicy policy = new b2btd.xEntitlementPolicy()
                .name('TEST policy')
                .canViewProduct(true)
                .canViewPrice(true)
                .active(true);
        policy.persist();

        new b2btd.xStandardPricebookEntry(product).price(100).active().persist();

        b2btd.xEntitlementProduct entitlementProduct = new b2btd.xEntitlementProduct(product, policy);
        entitlementProduct.persist();

        new b2btd.xEntitlementBuyerGroup(buyerGroup, policy).persist();

        b2btd.xPricebook pricebook = new b2btd.xPricebook().name('TEST PB').active(true);
        pricebook.persist();

        new b2btd.xPricebookEntry(product, pricebook).price(100).active().persist();

        b2btd.xOrder order = new b2btd.xOrder().account(account);
        Order orderInserted = (Order) order.persist();

        b2btd.xOrderItem orderItem = new b2btd.xOrderItem().withOrder(orderInserted.Id);
        OrderItem oi = (OrderItem) orderItem.persist();

        b2btd.xOrderDeliveryMethod orderDeliveryMethod = new b2btd.xOrderDeliveryMethod();
        orderDeliveryMethod.persist();

        b2btd.xOrderDeliveryGroup orderDeliveryGroup = (b2btd.xOrderDeliveryGroup) new b2btd.xOrderDeliveryGroup()
                .withOrder(orderInserted.Id)
                .set(OrderDeliveryGroup.DeliverToCountry, 'United States')
                .set(OrderDeliveryGroup.DeliverToState, 'New York');
        OrderDeliveryGroup odg = (OrderDeliveryGroup) orderDeliveryGroup.persist();

        oi.OrderDeliveryGroupId = odg.Id;
        update oi;

        orderInserted.Status = 'Activated';
        update orderInserted;

        ConnectApi.OrderSummaryInputRepresentation osir = new ConnectApi.OrderSummaryInputRepresentation();
        osir.orderId = orderInserted.Id;
        osir.orderLifeCycleType = 'UNMANAGED';
        ConnectApi.OrderSummaryOutputRepresentation osor = ConnectApi.OrderSummaryCreation.createOrderSummary(osir);

        // when
        OrderConfirmationEmailItemsController oceic = new OrderConfirmationEmailItemsController();
        oceic.orderSummaryId = osor.orderSummaryId;
        List<OrderConfirmationEmailItemsController.EmailOrderItem> actual = oceic.getEmailOrderItemList();

        // then
        Assert.areEqual(1, actual.size(), 'There should be 1 EmailOrderItems.');
        Assert.areEqual(1, actual[0].Quantity, 'Quantity should be 1.');
    }
}