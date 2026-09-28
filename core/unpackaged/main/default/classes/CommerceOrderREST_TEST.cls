/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 14.03.2024
 * @description Test suite
 *
 */

@IsTest(SeeAllData=true) // due to connect api limitations
private class CommerceOrderREST_TEST {

	@IsTest
	static void testDoDeleteOrderSuccess() {
		// given
		b2btd.xAccount account = new b2btd.xAccount();
		account.persist();

		Order testOrder = new Order(
			Status = 'Draft',
			External_Id__c = 'EXT123',
			AccountId = account.id,
			EffectiveDate = Date.today()
		);
		insert testOrder;


		RestRequest req = new RestRequest();
		req.requestURI = '/commerce/order/' + testOrder.External_Id__c;

		RestContext.request = req;

		// when
		CommerceOrderREST.OperationResult result = CommerceOrderREST.doDelete();

		// then
		Assert.isTrue(result.success, 'Expected success to be true');
		Assert.areEqual(testOrder.Id, result.orderId, 'Order ID should match');

		List<Order> orders = [SELECT Id FROM Order WHERE Id = :testOrder.Id];
		Assert.areEqual(0, orders.size(), 'Order should be deleted');

		List<OrderSummary> orderSummaries = [SELECT Id FROM OrderSummary WHERE OriginalOrderId = :testOrder.Id];
		Assert.areEqual(0, orderSummaries.size(), 'Order summary should be deleted');
	}

	@IsTest
	static void testDoDeleteOrderNotFound() {
		// given
		RestRequest req = new RestRequest();
		req.requestURI = '/commerce/order/NON_EXISTENT';
		RestContext.request = req;

		// when
		CommerceOrderREST.OperationResult result = CommerceOrderREST.doDelete();


		// then
		Assert.isTrue(!result.success, 'Expected success to be false');
		Assert.areEqual(
			'Order with external or sf id of: \'NON_EXISTENT\' not found in the org.',
			result.error,
			'Error message should indicate order not found'
		);
	}

	@IsTest
	static void testChangeLine_success() {
		// given
		TestUtils.assignPermissionSetToCurrentUser('PPI_Commerce_Admin');

		System.runAs(new User(Id = UserInfo.getUserId())) {

			TestData data = setupOrderData(false);

			Order orderChange = new Order();
			orderChange.put(CommerceOrderREST.EXTERNAL_ID_ORDER, data.order.get(CommerceOrderREST.EXTERNAL_ID_ORDER));

			OrderItem lineChange = new OrderItem(
				Quantity = 10,
				UnitPrice = 200,
				TotalLineAmount = 2000
			);

			lineChange.put(
				CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM,
				data.orderItem.get(CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM)
			);

			orderChange = addItemsToOrder(orderChange, new List<OrderItem>{
				lineChange
			});
			data.input.orderChange = orderChange;

			RestContext.request = new RestRequest();
			RestContext.request.requestBody = Blob.valueOf(JSON.serialize(data.input));

			// when
			CommerceOrderREST.OperationResult operationResult = CommerceOrderREST.process();
			// then
			Assert.isTrue(operationResult.success);
			OrderItem updateOrderItem = [
				SELECT Id,
					UnitPrice,
					Quantity,
					TotalLineAmount
				FROM OrderItem
				WHERE Id = :data.orderItem.Id
			];

			Assert.areEqual(lineChange.UnitPrice, updateOrderItem.UnitPrice);
			Assert.areEqual(lineChange.Quantity, updateOrderItem.Quantity);
			Assert.areEqual(lineChange.TotalLineAmount, updateOrderItem.TotalLineAmount);

			assertOrderSummaryWasRegenerated(data);

		}

	}

	@IsTest
	static void testAddLine_success() {
		// given
		TestUtils.assignPermissionSetToCurrentUser('PPI_Commerce_Admin');

		System.runAs(new User(Id = UserInfo.getUserId())) {

			TestData data = setupOrderData(false);

			Order orderChange = new Order();
			orderChange.put(CommerceOrderREST.EXTERNAL_ID_ORDER, data.order.get(CommerceOrderREST.EXTERNAL_ID_ORDER));


			OrderItem newLine = new OrderItem(
				UnitPrice = 500,
				ListPrice = 500,
				TotalLineAmount = 500,
				Quantity = 2
			);
			newLine.put(
				CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM,
				'ab123fab'
			);

			newLine.putSObject(OrderItem.OrderId, orderChange);

			Product2 product = new Product2();
			product.put(
				CommerceOrderREST.EXTERNAL_ID_PRODUCT,
				data.product.get(CommerceOrderREST.EXTERNAL_ID_PRODUCT)
			);
			newLine.putSObject(OrderItem.Product2Id, product);

			OrderItem existingLine = new OrderItem();
			existingLine.put(
				CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM,
				data.orderItem.get(CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM)
			);

			orderChange = addItemsToOrder(orderChange, new List<OrderItem>{
				newLine, existingLine
			});
			data.input.orderChange = orderChange;

			RestContext.request = new RestRequest();
			RestContext.request.requestBody = Blob.valueOf(JSON.serialize(data.input));

			// when
			CommerceOrderREST.OperationResult operationResult = CommerceOrderREST.process();

			// then
			Assert.isTrue(operationResult.success);

			List<OrderItem> allOrderItems = [
				SELECT Id,
					ListPrice,
					UnitPrice,
					Quantity,
					TotalLineAmount
				FROM OrderItem
				WHERE OrderId = :data.order.Id
				ORDER BY CreatedDate DESC
			];

			Assert.areEqual(2, allOrderItems.size(), 'should create one more item');

			OrderItem lastCreatedItem = allOrderItems[0];
			Assert.areEqual(newLine.UnitPrice, lastCreatedItem.UnitPrice);
			Assert.areEqual(newLine.ListPrice, lastCreatedItem.ListPrice);
			Assert.areEqual(newLine.Quantity, lastCreatedItem.Quantity);
			Assert.areEqual(newLine.TotalLineAmount, lastCreatedItem.TotalLineAmount);

			assertOrderSummaryWasRegenerated(data);
		}
	}

	@IsTest
	static void testRemoveLine_success() {
		// given
		TestUtils.assignPermissionSetToCurrentUser('PPI_Commerce_Admin');

		System.runAs(new User(Id = UserInfo.getUserId())) {
			TestData data = setupOrderData(true);

			Order orderChange = new Order();
			orderChange.put(CommerceOrderREST.EXTERNAL_ID_ORDER, data.order.get(CommerceOrderREST.EXTERNAL_ID_ORDER));

			OrderItem itemToRetain = new OrderItem();
			itemToRetain.put(
				CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM,
				data.additionalItem.get(CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM)
			);

			orderChange = addItemsToOrder(orderChange, new List<OrderItem>{
				itemToRetain
			});
			data.input.orderChange = orderChange;

			RestContext.request = new RestRequest();
			RestContext.request.requestBody = Blob.valueOf(JSON.serialize(data.input));

			Assert.areEqual(2, [SELECT COUNT() FROM OrderItem WHERE OrderId = :data.order.Id], 'order should have 2 items before processing');

			// when
			CommerceOrderREST.OperationResult operationResult = CommerceOrderREST.process();

			// then
			Assert.isTrue(operationResult.success);
			List<OrderItem> remainingItems = [
				SELECT Id
				FROM OrderItem
				WHERE OrderId = :data.order.Id
			];
			Assert.areEqual(1, remainingItems.size(), 'order should have only 1 remaining item after processing');
			Assert.areEqual(data.additionalItem.Id, remainingItems[0].Id);

			assertOrderSummaryWasRegenerated(data);
		}
	}

	@IsTest
	static void testExternalOrderCreation() {
		// given
		TestUtils.assignPermissionSetToCurrentUser('PPI_Commerce_Admin');

		System.runAs(new User(Id = UserInfo.getUserId())) {
			insert new OrderDeliveryMethod(Name = 'test');

			List<String> productExternalIds = new List<String>{
				'54520',
				'30463',
				'39305',
				'40015',
				'41513'
			};

			List<Product2> productsToUpsert = new List<Product2>();

			for (String productExternalId : productExternalIds) {
				Product2 testProduct = new Product2(
					StockKeepingUnit = '' + productExternalId,
					Name = '' + productExternalId
				);
				testProduct.put(
					CommerceOrderREST.EXTERNAL_ID_PRODUCT, productExternalId
				);
				productsToUpsert.add(testProduct);
			}

			Database.upsert(productsToUpsert, CommerceOrderREST.EXTERNAL_ID_PRODUCT, false);

			Decimal accountExternalId = 111111.0;

			Account buyerAccount = new Account(
				Name = 'test'
			);
			buyerAccount.put(CommerceOrderREST.EXTERNAL_ID_ACCOUNT, accountExternalId);
			Database.upsert(buyerAccount, CommerceOrderREST.EXTERNAL_ID_ACCOUNT);

			Database.insert(new BuyerAccount(
				Name = 'BuyerAccount',
				BuyerId = buyerAccount.Id,
				IsActive = true
			), false);

			Database.upsert(buyerAccount, CommerceOrderREST.EXTERNAL_ID_ACCOUNT, true);

			String externalOrderPayload = [
				SELECT Id,
					Body
				FROM StaticResource
				WHERE Name = 'MockCommerceRestExternalOrder'
				LIMIT 1
			]?.Body.toString();

			RestContext.request = new RestRequest();
			RestContext.request.requestBody = Blob.valueOf(externalOrderPayload);

			final Integer beforeOrderSummaryCount = [SELECT COUNT() FROM OrderSummary];

			// when
			CommerceOrderREST.OperationResult operationResult = CommerceOrderREST.process();

			// then
			Assert.isTrue(operationResult.success);
			Assert.isNotNull(operationResult.orderSummaryId);

			final Integer afterOrderSummaryCount = [SELECT COUNT() FROM OrderSummary];

			Assert.areEqual(beforeOrderSummaryCount + 1, afterOrderSummaryCount);
		}
	}

	private static void assertOrderSummaryWasRegenerated(TestData data) {
		Id oldOrderSummaryId = [
			SELECT
				Id
			FROM OrderSummary
			WHERE Id = :data.orderSummaryId
		]?.Id;

		Assert.isNull(oldOrderSummaryId, 'old order summary should be removed');

		Id newOrderSummaryId = Database.queryWithBinds(
			String.format(
				'SELECT Id FROM OrderSummary WHERE {0} =: orderExternalId',
				new List<String>{
					'OriginalOrder.' + String.valueOf(CommerceOrderREST.EXTERNAL_ID_ORDER)
				}
			),
			new Map<String, Object>{
				'orderExternalId' => data.order.get(CommerceOrderREST.EXTERNAL_ID_ORDER)
			},
			AccessLevel.SYSTEM_MODE
		)[0].Id;

		Assert.isNotNull(newOrderSummaryId);
		Assert.areNotEqual(data.orderSummaryId, newOrderSummaryId, 'regenerated order summary should have different ID');
	}

	static TestData setupOrderData(Boolean insertSecondItem) {

		TestData data = new TestData();

		CommerceOrderREST.OrderRequest input = new CommerceOrderREST.OrderRequest();
		data.input = input;

		Account account = new Account(Name = 'test_account');
		insert account;

		Product2 testProduct = new Product2(
			StockKeepingUnit = 'test_product_12345',
			Name = 'test_product_12345'
		);
		testProduct.put(
			CommerceOrderREST.EXTERNAL_ID_PRODUCT, '111111'
		);
		insert testProduct;

		data.product = testProduct;

		Product2 testProduct2 = new Product2(
			StockKeepingUnit = 'test_product_1234569',
			Name = 'test_product_1234569'
		);
		testProduct2.put(
			CommerceOrderREST.EXTERNAL_ID_PRODUCT, '222222'
		);
		insert testProduct2;

		data.additionalProduct = testProduct2;

		Order order = new Order(
			AccountId = account.Id,
			Status = 'Draft',
			PoDate = Date.today(),
			EffectiveDate = Date.today()
		);
		order.put(CommerceOrderREST.EXTERNAL_ID_ORDER, '111111');
		insert order;

		data.order = order;

		OrderDeliveryMethod odm = new OrderDeliveryMethod(
			Name = 'TestMethod', IsActive = true
		);
		insert odm;

		OrderDeliveryGroup odg = new OrderDeliveryGroup(
			OrderDeliveryMethodId = odm.Id,
			OrderId = order.Id,
			DeliverToName = 'Test Delivery',
			DeliverToStreet = '800 River Rd',
			DeliverToCity = 'Fair Haven',
			DeliverToStateCode = 'NJ',
			DeliverToCountryCode = 'US'
		);
		insert odg;

		OrderItem item = new OrderItem(
			OrderId = order.Id,
			Product2Id = testProduct.Id,
			UnitPrice = 10,
			ListPrice = 10,
			TotalLineAmount = 100,
			Quantity = 1,
			OrderDeliveryGroupId = odg.Id
		);
		item.put(CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM, 'a623f21c');
		insert item;

		data.orderItem = item;

		OrderItem additionalItem = new OrderItem(
			OrderId = order.Id,
			Product2Id = testProduct2.Id,
			UnitPrice = 10,
			ListPrice = 10,
			TotalLineAmount = 100,
			Quantity = 1,
			OrderDeliveryGroupId = odg.Id
		);
		additionalItem.put(CommerceOrderREST.EXTERNAL_ID_ORDER_ITEM, '43d03042');
		data.additionalItem = additionalItem;

		if (insertSecondItem) {
			insert additionalItem;
		}

		order.Status = 'Activated';
		update order;

		ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
		orderSummaryInput.name = order.PoNumber;
		orderSummaryInput.orderId = order.Id;
		orderSummaryInput.orderLifeCycleType = 'UNMANAGED';
		orderSummaryInput.status = 'Created';
		ConnectApi.OrderSummaryOutputRepresentation output = ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);

		data.orderSummaryId = output.orderSummaryId;

		return data;
	}

	@IsTest
	static void testCreateNewOrderAndUpdateOldOne() {
		// given
		TestUtils.assignPermissionSetToCurrentUser('PPI_Commerce_Admin');

		System.runAs(new User(Id = UserInfo.getUserId())) {
			insert new OrderDeliveryMethod(Name = 'test');

			List<String> productExternalIds = new List<String>{
					'54520',
					'30463',
					'39305',
					'40015',
					'41513'
			};

			List<Product2> productsToUpsert = new List<Product2>();

			for (String productExternalId : productExternalIds) {
				Product2 testProduct = new Product2(
						StockKeepingUnit = '' + productExternalId,
						Name = '' + productExternalId
				);
				testProduct.put(
						CommerceOrderREST.EXTERNAL_ID_PRODUCT, productExternalId
				);
				productsToUpsert.add(testProduct);
			}

			Database.upsert(productsToUpsert, CommerceOrderREST.EXTERNAL_ID_PRODUCT, false);

			Decimal accountExternalId = 111111.0;

			Account buyerAccount = new Account(
					Name = 'test'
			);
			buyerAccount.put(CommerceOrderREST.EXTERNAL_ID_ACCOUNT, accountExternalId);
			Database.upsert(buyerAccount, CommerceOrderREST.EXTERNAL_ID_ACCOUNT);

			Database.insert(new BuyerAccount(
					Name = 'BuyerAccount',
					BuyerId = buyerAccount.Id,
					IsActive = true
			), false);

			Database.upsert(buyerAccount, CommerceOrderREST.EXTERNAL_ID_ACCOUNT, true);

			String externalOrderPayload = [
					SELECT Id,
							Body
					FROM StaticResource
					WHERE Name = 'MockCommerceRestBulkExternalOrders'
					LIMIT 1
			]?.Body.toString();

			RestContext.request = new RestRequest();
			RestContext.request.requestBody = Blob.valueOf(externalOrderPayload);

			final Integer beforeOrderSummaryCount = [SELECT COUNT() FROM OrderSummary];

			// when
			List<CommerceOrderREST.OperationResult> operationResult = CommerceOrderREST.doPatch();

			// then
			Assert.isTrue(operationResult[0].success);
			Assert.isTrue(operationResult[1].success);
			Assert.isNotNull(operationResult[0].orderSummaryId);
			Assert.isNotNull(operationResult[1].orderSummaryId);

			final Integer afterOrderSummaryCount = [SELECT COUNT() FROM OrderSummary];
			Assert.areEqual(beforeOrderSummaryCount + 2, afterOrderSummaryCount);
		}

	}


	private static Order addItemsToOrder(Order order, List<OrderItem> items) {
		Map<String, Object> untypedOrder = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(order));

		untypedOrder.put('OrderItems', new Map<String, Object>{
			'records' => items,
			'totalSize' => items.size(),
			'done' => true
		});

		return (Order) JSON.deserialize(JSON.serialize(untypedOrder), Order.class);
	}

	private class TestData {
		public Order order { get; set; }
		public OrderItem orderItem { get; set; }
		public Id orderSummaryId { get; set; }
		public CommerceOrderREST.OrderRequest input { get ; set; }
		public Product2 product { get; set; }
		public Product2 additionalProduct { get; set; }
		public OrderItem additionalItem { get; set; }
	}
}