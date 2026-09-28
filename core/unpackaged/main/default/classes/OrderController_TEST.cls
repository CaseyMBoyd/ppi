/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jakub_cichacki/Forefront
 * @date 18.06.2024
 * @test 
 **/
@IsTest
private class OrderController_TEST {
    @IsTest(SeeAllData=true) // due to connect api limitations
    static void testGetOrderSummaries() {
        //given
        b2btd.xAccount account = new b2btd.xAccount();
        account.set('Name', 'TestAccountForUnitTestWithSeeAllData');
        account.set('externalId__c', 1235645987.54);
        account.set('Salesman_Text__c', 'TestSalesman');
        account.set('Territory_Text__c', 'TestTerritory');
        Account acc = (Account) account.persist();

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
                AccountId = acc.Id,
                OrderedDate = Date.today(),
                External_Id__c = '201111230112'
        );

        String orderNumber = 'test_order_number';
        ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
        orderSummaryInput.NAME = orderNumber;
        orderSummaryInput.externalReferenceIdentifier = orderNumber;
        orderSummaryInput.orderId = order.Id;
        orderSummaryInput.orderLifeCycleType = 'MANAGED';
        orderSummaryInput.status = 'Created';

        ConnectApi.OrderSummaryOutputRepresentation summaryCreateResult =
                ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);

        BuyerContext.mockCurrentEffectiveAccountId = acc.Id;

        //when
        List<OrderSummary> orderSummaries = OrderController.getOrderSummaries(
                new Map<String, String>{
                        'OrderNumber' => 'test_order_number',
                        'startDate' => Datetime.now().addDays(-1).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                        'endDate' => Datetime.now().addDays(1).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                },
                25, 'OrderedDate', 'DESC');

        //then
        Assert.areEqual(1, orderSummaries.size());
    }

    @IsTest(SeeAllData=true) // due to connect api limitations
    static void testPossibilityToReorder() {
        //given
        b2btd.xAccount account = new b2btd.xAccount();
        account.set('Name', 'TestAccountForUnitTestWithSeeAllData');
        account.set('externalId__c', 1235645987.54);
        account.set('Salesman_Text__c', 'TestSalesman');
        account.set('Territory_Text__c', 'TestTerritory');
        Account acc = (Account) account.persist();

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
                AccountId = acc.Id,
                OrderedDate = Date.today(),
                External_Id__c = '201111230112'
        );

        String orderNumber = 'test_order_number';
        ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
        orderSummaryInput.NAME = orderNumber;
        orderSummaryInput.externalReferenceIdentifier = orderNumber;
        orderSummaryInput.orderId = order.Id;
        orderSummaryInput.orderLifeCycleType = 'MANAGED';
        orderSummaryInput.status = 'Created';

        ConnectApi.OrderSummaryOutputRepresentation summaryCreateResult =
                ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);

        BuyerContext.mockCurrentEffectiveAccountId = acc.Id;

        //when
        Boolean reorderPossible = OrderController.isReorderPossible(summaryCreateResult.orderSummaryId);

        //then
        Assert.isTrue(reorderPossible);
    }


    @IsTest(SeeAllData=true) // due to connect api limitations
    static void testFetchingOrderItemSummaries() {
        //given
        b2btd.xAccount account = new b2btd.xAccount();
        account.set('Name', 'TestAccountForUnitTestWithSeeAllData');
        account.set('externalId__c', 1235645987.54);
        account.set('Salesman_Text__c', 'TestSalesman');
        account.set('Territory_Text__c', 'TestTerritory');
        Account acc = (Account) account.persist();

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
                AccountId = acc.Id,
                OrderedDate = Date.today(),
                External_Id__c = '201111230112'
        );

        String orderNumber = 'test_order_number';
        ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
        orderSummaryInput.NAME = orderNumber;
        orderSummaryInput.externalReferenceIdentifier = orderNumber;
        orderSummaryInput.orderId = order.Id;
        orderSummaryInput.orderLifeCycleType = 'MANAGED';
        orderSummaryInput.status = 'Created';

        ConnectApi.OrderSummaryOutputRepresentation summaryCreateResult =
                ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);

        //when
        List<OrderItemSummary> orderItemSummaries = OrderController.getOrderItemSummaries(summaryCreateResult.orderSummaryId, new List<String> {'Id'});

        //then
        Assert.areEqual(1, orderItemSummaries.size());
    }

    @IsTest(SeeAllData=true) // due to connect api limitations
    static void testFetchingDeliveryMethod() {
        //given
        b2btd.xAccount account = new b2btd.xAccount();
        account.set('Name', 'TestAccountForUnitTestWithSeeAllData');
        account.set('externalId__c', 1235645987.54);
        account.set('Salesman_Text__c', 'TestSalesman');
        account.set('Territory_Text__c', 'TestTerritory');
        Account acc = (Account) account.persist();

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
                AccountId = acc.Id,
                OrderedDate = Date.today(),
                External_Id__c = '201111230112'
        );

        String orderNumber = 'test_order_number';
        ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
        orderSummaryInput.NAME = orderNumber;
        orderSummaryInput.externalReferenceIdentifier = orderNumber;
        orderSummaryInput.orderId = order.Id;
        orderSummaryInput.orderLifeCycleType = 'MANAGED';
        orderSummaryInput.status = 'Created';

        ConnectApi.OrderSummaryOutputRepresentation summaryCreateResult =
                ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);

        //when
        OrderController.OrderDeliveryMethodWrapper orderDeliveryMethodWrapper = OrderController.getOrderDeliveryMethod(summaryCreateResult.orderSummaryId);

        //then
        Assert.isNotNull(orderDeliveryMethodWrapper);
    }


}