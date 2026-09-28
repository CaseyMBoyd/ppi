/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 22.01.2024
 * @description Test suite
 *
 */

@IsTest
private class CommercePricingService_TEST {
	private static final Decimal PRODUCT_UNIT_PRICE = 100;
	private static final Decimal MULTIPLIER = 2;

	@TestSetup
	static void setup() {
		Account account = new Account(
			Name = 'test account',
			Drum_Multiplier__c = MULTIPLIER,
			Vulcanized_Lagging_Multiplier__c = MULTIPLIER,
			externalId__c = 123
		);
		insert account;

		Product2 product = new Product2(
			StockKeepingUnit = 'test_product_unique',
			Name = 'My_test_product',
			IsActive = true,
			XA_Product_Class__c = 'Drum'
		);
		insert product;

		update new Pricebook2(
			Id = Test.getStandardPricebookId(),
			IsActive = true
		);

		insert new PricebookEntry(
			Pricebook2Id = Test.getStandardPricebookId(),
			Product2Id = product.Id,
			UnitPrice = PRODUCT_UNIT_PRICE
		);
	}
	@IsTest
	static void testBehavior() {
		// given
		Account account = [SELECT Id FROM Account LIMIT 1];
		Product2 product = [SELECT Id FROM Product2 LIMIT 1];

		CommerceStorePricing.PricingRequest request = new CommerceStorePricing.PricingRequest();
		request.setEffectiveAccountId(account.Id);

		CommerceStorePricing.PricingRequestItem requestItem = new CommerceStorePricing.PricingRequestItem(product.Id);
		request.addPricingRequestItem(requestItem);

		CommerceStorePricing.PricingResponse mockPricingResponse = new CommerceStorePricing.PricingResponse('USD');
		CommerceStorePricing.PricingResponseItem responseItem = new CommerceStorePricing.PricingResponseItem(
			product.Id, null, null, PRODUCT_UNIT_PRICE, PRODUCT_UNIT_PRICE
		);
		mockPricingResponse.addPricingResponseItem(responseItem);

		CommercePricingService.mockPricingResponse = mockPricingResponse;
		String testMockResponse = '{ "items": [], "errors": []}';
		Test.setMock(HttpCalloutMock.class, new XaCalloutController_TEST.HttpMock(200, testMockResponse));

		// when
		Test.startTest();
		CommerceStorePricing.PricingResponse pricingResponse = new CommercePricingService().processPrice(request);
		Test.stopTest();

		// then
		Assert.isTrue(pricingResponse.isSuccess());

		CommerceStorePricing.PricingResponseItem pricedItem = pricingResponse.getPricingResponseItems().get(0);
		Assert.areEqual(MULTIPLIER * PRODUCT_UNIT_PRICE, pricedItem.getListPrice());
		Assert.areEqual(MULTIPLIER * PRODUCT_UNIT_PRICE, pricedItem.getNegotiatedPrice());
	}

	@IsTest
	static void testProcessTransactionalPrice() {
		// given
		final Decimal quantity = 10;

		Account account = [SELECT Id FROM Account LIMIT 1];
		Product2 product = [SELECT Id FROM Product2 LIMIT 1];

		CommerceStorePricing.TransactionalPricingRequest request = new CommerceStorePricing.TransactionalPricingRequest();
		request.setEffectiveAccountId(account.Id);

		CommerceStorePricing.TransactionalPricingRequestItem requestItem =
			new CommerceStorePricing.TransactionalPricingRequestItem('test', product.Id, 10);

		request.addTxnPricingRequestItem(requestItem);

		CommerceStorePricing.TransactionalPricingResponse mockPricingResponse =
			new CommerceStorePricing.TransactionalPricingResponse(null, null, null, null, 'USD');

		CommerceStorePricing.TransactionalPricingResponseItem responseItem =
			new CommerceStorePricing.TransactionalPricingResponseItem(
				'test',
				product.Id,
				null,
				PRODUCT_UNIT_PRICE,
				PRODUCT_UNIT_PRICE,
				PRODUCT_UNIT_PRICE * quantity,
				PRODUCT_UNIT_PRICE * quantity,
				0,
				0,
				PRODUCT_UNIT_PRICE * quantity,
				quantity,
				'USD'
			);
		mockPricingResponse.addTxnPricingResponseItem(responseItem);

		CommercePricingService.mockTransactionalPricingResponse = mockPricingResponse;
		String testMockResponse = '{ "items": [], "errors": []}';
		Test.setMock(HttpCalloutMock.class, new XaCalloutController_TEST.HttpMock(200, testMockResponse));

		// when
		Test.startTest();
		CommerceStorePricing.TransactionalPricingResponse pricingResponse =
			new CommercePricingService().processTransactionalPrice(request);
		Test.stopTest();
		// then
		Assert.isTrue(pricingResponse.isSuccess());

		CommerceStorePricing.TransactionalPricingResponseItem pricedItem = pricingResponse.getTxnPricingResponseItems().get(0);
		Assert.areEqual(MULTIPLIER * PRODUCT_UNIT_PRICE, pricedItem.getListPrice());
		Assert.areEqual(MULTIPLIER * PRODUCT_UNIT_PRICE, pricedItem.getUnitPrice());

		Assert.areEqual(MULTIPLIER * PRODUCT_UNIT_PRICE * quantity, pricedItem.getTotalLineAmount());
		Assert.areEqual(MULTIPLIER * PRODUCT_UNIT_PRICE * quantity, pricedItem.getTotalListPrice());
		Assert.areEqual(MULTIPLIER * PRODUCT_UNIT_PRICE * quantity, pricedItem.getTotalPrice());
	}
}