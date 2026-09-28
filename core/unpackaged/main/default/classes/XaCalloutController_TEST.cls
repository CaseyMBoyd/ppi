/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 11.03.2024
 * @description Test suite
 *
 */

@IsTest
public class XaCalloutController_TEST {

	@IsTest
	static void testFetchInventory() {
		// given
		String mockResponse = [
			SELECT Body
			FROM StaticResource
			WHERE Name = 'MockXaResponseInventoryItem'
			LIMIT 1
		]?.Body.toString();


		Id mockProductId = b2btd.generateFakeId(Product2.SObjectType);

		Test.setMock(HttpCalloutMock.class, new HttpMock(200, mockResponse));

		// when
		Test.startTest();
		List<ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200> res =
			XaCalloutController.fetchInventory(mockProductId);
		Test.stopTest();

		// then
		Assert.areEqual(1, res.size());
		Assert.areEqual('Pella', res[0].warehouse.name);
	}

	@IsTest
	static void testCanFulfillOrder() {
		// given
		String mockResponse = [
			SELECT Body
			FROM StaticResource
			WHERE Name = 'MockXaResponseAvailableToAssemble'
			LIMIT 1
		]?.Body.toString();

		Test.setMock(HttpCalloutMock.class, new HttpMock(200, mockResponse));

		b2btd.xCart cart = new b2btd.xCart().withItem(new b2btd.xProduct().productCode('test'), 2000, 5);
		cart.persist();

		CartCheckoutSession checkoutSession = new CartCheckoutSession(
			Name = 'test',
			State = 'Start',
			WebCartId = cart.id
		);
		insert checkoutSession;

		// when
		Test.startTest();
		Boolean canFulfill =
			XaCalloutController.canFulfillOrder(checkoutSession.Id, new ExternalService.XaApiService_Address());
		Test.stopTest();

		// then
		Assert.isFalse(canFulfill);
	}

	@IsTest(SeeAllData=true) // due to connect api limitations
	static void testFetchInvoice() {
		// given
		String mockResponse = [
			SELECT Body
			FROM StaticResource
			WHERE Name = 'MockXaResponseInvoice'
			LIMIT 1
		]?.Body.toString();

		Test.setMock(HttpCalloutMock.class, new HttpMock(200, mockResponse));

		Id orderSummaryId = createOrderSummary();

		// when
		Test.startTest();
		String base64pdf = XaCalloutController.fetchInvoice(orderSummaryId);
		Test.stopTest();

		// then
		Assert.isNotNull(base64pdf);
	}


	@IsTest
	static void testCreateContact() {
		// given
		Contact contact = createContact();

		String mockedResponseBody = '"Successfully created contact"';
		Test.setMock(HttpCalloutMock.class, new HttpMock(201, mockedResponseBody));

		// when
		Test.startTest();
		String res = XaCalloutController.createContact(contact);
		Test.stopTest();

		// then
		Assert.areEqual(mockedResponseBody, res);
	}

	public static Contact createContact() {
		Account account = new Account(
			Name = 'test account',
			companyNumber__c = 10,
			externalId__c = 111111.00
		);
		insert account;

		Contact contact = new Contact(
			FirstName = 'test',
			LastName = 'contact',
			AccountId = account.Id,
			Email = 'test@email.com'
		);
		insert contact;

		return [
			SELECT Id,
				Name,
				Email,
				Account.companyNumber__c,
				Account.externalId__c
			FROM Contact
			WHERE Id = :contact.Id
		];
	}

	@IsTest
	static void testCreateOrder() {
		// given
		Id orderId = createOrder().id;
		Order order = XaCalloutController.fetchOrders(new Set<Id>{
			orderId
		})[0];

		String mockServerResponse = '{ "message": "Order Created Successfully" }';

		Test.setMock(HttpCalloutMock.class, new HttpMock(202, mockServerResponse));

		// when
		Test.startTest();
		ExternalService.XaApiService.putOrder_Response res = XaCalloutController.createOrder(order);
		Test.stopTest();

		// then
		Assert.areEqual('Order Created Successfully', res.Code202.message);
	}

	@IsTest
	static void testGetItemPricing() {
		List<String> productCodes = new List<String>();
		productCodes.add('test');

		String testMockResponse = '{ "items": [], "errors": []}';
		Test.setMock(HttpCalloutMock.class, new HttpMock(200, testMockResponse));

		Test.startTest();
		XaCalloutController.fetchBulkItemPricingByCustomerNumber('123', 1, productCodes);
		Test.stopTest();
	}

	public static Id createOrderSummary() {
		// given
		b2btd.xOrder order = createOrder();

		String orderNumber = 'test_order_number';
		ConnectApi.OrderSummaryInputRepresentation orderSummaryInput = new ConnectApi.OrderSummaryInputRepresentation();
		orderSummaryInput.NAME = orderNumber;
		orderSummaryInput.externalReferenceIdentifier = orderNumber;
		orderSummaryInput.orderId = order.Id;
		orderSummaryInput.orderLifeCycleType = 'MANAGED';
		orderSummaryInput.status = 'Created';

		ConnectApi.OrderSummaryOutputRepresentation summaryCreateResult =
			ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput);

		return summaryCreateResult.orderSummaryId;
	}

	public static b2btd.xOrder createOrder() {
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

	/**
	 * StaticResourceCalloutMock is not working for ExternalService invocations
	 * had to implement custom HttpCalloutMock class
	 */
	public class HttpMock implements HttpCalloutMock {
		private final Integer statusCode;
		private final String responseBody;

		public HttpMock(Integer statusCode, String responseBody) {
			this.statusCode = statusCode;
			this.responseBody = responseBody;
		}
		public HttpResponse respond(HttpRequest request) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(this.statusCode);
			res.setBody(this.responseBody);

			return res;
		}
	}
}