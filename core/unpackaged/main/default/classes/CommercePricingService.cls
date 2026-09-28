/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 11.01.2024 <p/>
 * @test CommercePricingService_TEST
 *
 */

public without sharing class CommercePricingService extends CommerceStorePricing.PricingService {
	@TestVisible private static CommerceStorePricing.PricingResponse mockPricingResponse;
	@TestVisible private static CommerceStorePricing.TransactionalPricingResponse mockTransactionalPricingResponse;

	/*
		This will only update the price in the catalog pages, so the price will be altered in both:
		- PDP and PLP pages, but it won't be applied when adding the product to cart
	 */
	public override CommerceStorePricing.PricingResponse processPrice(
		CommerceStorePricing.PricingRequest request
	) {

		Iterator<CommerceStorePricing.PricingRequestItem> requestItemsIterator = request.getPricingRequestItems().iterator();

		Set<Id> productIds = new Set<Id>();

		while (requestItemsIterator.hasNext()) {
			CommerceStorePricing.PricingRequestItem item = requestItemsIterator.next();
			productIds.add(item.getProductId());
		}

		Map<Id, Product2> products = fetchProductsById(productIds);
		Map<Id, XaCalloutController.BulkItemPricing> pricingResponseItems = new Map<Id, XaCalloutController.BulkItemPricing>();
		Account currentAccount = [SELECT Id, externalId__c, Indirect_Customer_No__c, Parent.externalId__c, Drum_Multiplier__c, Vulcanized_Lagging_Multiplier__c FROM Account WHERE Id =: request.getEffectiveAccountId()];
		if(currentAccount?.externalId__c != null || currentAccount?.Parent?.externalId__c != null) {
			Map<String, Id> productsWithCodes = new Map<String, Id>();
			for(Product2 prod : products.values()) {
				if(prod.ProductCode != null) {
					productsWithCodes.put(prod.ProductCode, prod.Id);
				}
			}
			String customerNumber = XaCalloutController.createCustomerNumberFromAccount(currentAccount);
			List<String> productCodes = new List<String>();
			for(Product2 prod : products.values()) {
				if(prod.ProductCode != null) {
					productCodes.add(prod.ProductCode);
				}
			}

			XaCalloutController.BulkItemPricingResponse pricingCalloutResponse = XaCalloutController.fetchBulkItemPricingByCustomerNumber(customerNumber, currentAccount.Indirect_Customer_No__c, productCodes);
			for (XaCalloutController.BulkItemPricing pricingResponse : pricingCalloutResponse.items) {
				if(productsWithCodes.containsKey(pricingResponse.itemNumber)) {
					pricingResponseItems.put(productsWithCodes.get(pricingResponse.itemNumber), pricingResponse);
				}
			}
		}

		CommerceStorePricing.PricingResponse response = Test.isRunningTest()
			? mockPricingResponse
			: super.processPrice(request);

		Iterator<CommerceStorePricing.PricingResponseItem> pricedItemsIterator = response.getPricingResponseItems().iterator();

		CommercePricingService.PriceMultiplierMatrix priceMultiplierMatrix =
			new PriceMultiplierMatrix(request.getEffectiveAccountId());

		while (pricedItemsIterator.hasNext()) {
			CommerceStorePricing.PricingResponseItem item = pricedItemsIterator.next();

			Product2 product = products.get(item.getProductId());
			Decimal multiplier = priceMultiplierMatrix.getMultiplier(product.XA_Product_Class__c);
			if(product.Family == 'Lagged Pro Duty Drum'){
				if(currentAccount.Drum_Multiplier__c == null || currentAccount.Vulcanized_Lagging_Multiplier__c == null){
					item.setListPrice(0);
					item.setNegotiatedPrice(0);
				} else {
					item.setListPrice((((product.Drum_List_Price__c ?? 0) * currentAccount.Drum_Multiplier__c) + ((product.Lagging_List_Price__c ?? 0) * currentAccount.Vulcanized_Lagging_Multiplier__c)).setScale(2));
					item.setNegotiatedPrice((((product.Drum_List_Price__c ?? 0) * currentAccount.Drum_Multiplier__c) + ((product.Lagging_List_Price__c ?? 0) * currentAccount.Vulcanized_Lagging_Multiplier__c)).setScale(2));
				}
			}
			else if(pricingResponseItems.containsKey(item.getProductId()) && pricingResponseItems.get(item.getProductId()).sellPrice != null) {
				item.setListPrice(pricingResponseItems.get(item.getProductId()).listPrice);
				item.setNegotiatedPrice(pricingResponseItems.get(item.getProductId()).sellPrice);
			} else {
				item.setListPrice(((item.getListPrice() ?? 0) * multiplier).setScale(2));
				item.setNegotiatedPrice(((item.getNegotiatedPrice() ?? 0) * multiplier).setScale(2));
			}
		}

		return response;
	}

	/*
		This gets applied to cart level calculations
	 */
	public override CommerceStorePricing.TransactionalPricingResponse processTransactionalPrice(
		CommerceStorePricing.TransactionalPricingRequest request
	) {

		Iterator<CommerceStorePricing.TransactionalPricingRequestItem> requestItemsIterator =
			request.getTxnPricingRequestItems().iterator();

		Set<Id> productIds = new Set<Id>();

		while (requestItemsIterator.hasNext()) {
			CommerceStorePricing.TransactionalPricingRequestItem item = requestItemsIterator.next();
			productIds.add(item.getProductId());
		}

		CommerceStorePricing.TransactionalPricingResponse txnResponse = Test.isRunningTest()
			? mockTransactionalPricingResponse
			: super.processTransactionalPrice(request);

		Map<Id, Product2> products = fetchProductsById(productIds);
		Map<Id, XaCalloutController.BulkItemPricing> pricingResponseItems = new Map<Id, XaCalloutController.BulkItemPricing>();
		Account currentAccount = [SELECT Id, externalId__c, Indirect_Customer_No__c, Parent.externalId__c, Drum_Multiplier__c, Vulcanized_Lagging_Multiplier__c FROM Account WHERE Id =: request.getEffectiveAccountId()];
		if(currentAccount?.externalId__c != null || currentAccount?.Parent?.externalId__c != null) {
			Map<String, Id> productsWithCodes = new Map<String, Id>();
			for(Product2 prod : products.values()) {
				if(prod.ProductCode != null) {
					productsWithCodes.put(prod.ProductCode, prod.Id);
				}
			}
			String customerNumber = XaCalloutController.createCustomerNumberFromAccount(currentAccount);
			List<String> productCodes = new List<String>();
			for(Product2 prod : products.values()) {
				if(prod.ProductCode != null) {
					productCodes.add(prod.ProductCode);
				}
			}

			XaCalloutController.BulkItemPricingResponse pricingCalloutResponse = XaCalloutController.fetchBulkItemPricingByCustomerNumber(customerNumber, currentAccount.Indirect_Customer_No__c, productCodes);
			for (XaCalloutController.BulkItemPricing pricingResponse : pricingCalloutResponse.items) {
				if(productsWithCodes.containsKey(pricingResponse.itemNumber)) {
					pricingResponseItems.put(productsWithCodes.get(pricingResponse.itemNumber), pricingResponse);
				}
			}
		}
		PriceMultiplierMatrix priceMatrix = new PriceMultiplierMatrix(request.getEffectiveAccountId());

		Iterator<CommerceStorePricing.TransactionalPricingResponseItem> pricedItemsIterator =
			txnResponse.getTxnPricingResponseItems().iterator();

		while (pricedItemsIterator.hasNext()) {
			CommerceStorePricing.TransactionalPricingResponseItem txnItem = pricedItemsIterator.next();

			Product2 product = products.get(txnItem.getProductId());
			Decimal multiplier = priceMatrix.getMultiplier(product.XA_Product_Class__c);

			if(product.Family == 'Lagged Pro Duty Drum'){
				if(currentAccount.Drum_Multiplier__c == null || currentAccount.Vulcanized_Lagging_Multiplier__c == null){
					txnItem.setListPrice(0);
					txnItem.setUnitPrice(0);
				} else {
					txnItem.setListPrice((((product.Drum_List_Price__c ?? 0) * currentAccount.Drum_Multiplier__c) + ((product.Lagging_List_Price__c ?? 0) * currentAccount.Vulcanized_Lagging_Multiplier__c)).setScale(2));
					txnItem.setUnitPrice((((product.Drum_List_Price__c ?? 0) * currentAccount.Drum_Multiplier__c) + ((product.Lagging_List_Price__c ?? 0) * currentAccount.Vulcanized_Lagging_Multiplier__c)).setScale(2));
				}
			}
			else if(pricingResponseItems.containsKey(txnItem.getProductId()) && pricingResponseItems.get(txnItem.getProductId()).sellPrice != null) {
				txnItem.setListPrice(pricingResponseItems.get(txnItem.getProductId()).listPrice);
				txnItem.setUnitPrice(pricingResponseItems.get(txnItem.getProductId()).sellPrice);
			} else {
				txnItem.setListPrice(((txnItem.getUnitPrice() ?? 0) * multiplier).setScale(2));
				txnItem.setUnitPrice(((txnItem.getUnitPrice() ?? 0) * multiplier).setScale(2));
			}

			Decimal total = (txnItem.getUnitPrice() * txnItem.getQuantity()).setScale(2);

			txnItem.setTotalLineAmount(total);
			txnItem.setTotalListPrice(total);
			txnItem.setTotalPrice(total);
		}

		return txnResponse;
	}

	private static Map<Id, Product2> fetchProductsById(Set<Id> productIds) {
		Map<Id, Product2> products = new Map<Id, Product2>([
			SELECT Id,
				XA_Product_Class__c,
				Family,
				Lagging_List_Price__c,
				Drum_List_Price__c,
				ProductCode
			FROM Product2
			WHERE Id IN :productIds
			WITH SYSTEM_MODE
		]);
		return products;
	}


	private without sharing class PriceMultiplierMatrix {
		private Map<String, Decimal> matrix;
		public PriceMultiplierMatrix(Id accountId) {
			this.createMatrix(accountId);
		}

		public Decimal getMultiplier(String partClass) {
			return Optional.of(this.matrix.get(normalizePartClass(partClass)), 1);
		}

		/**
		 * Part class will come in as "Take-up Frame" or "E Bearing" we need to process it
		 * to match the API field formats on account with is "Take_up_Frame_Multiplier__c" or "E_Bearing_Multiplier__c"
		 *
		 * @param partClass
		 *
		 * @return
		 */
		private String normalizePartClass(String partClass) {
			return Optional.of(partClass, '').replaceAll('-', '_').replaceAll(' ', '_').toLowerCase() + '_multiplier__c';
		}

		private void createMatrix(Id accountId) {
			Set<String> allFields = Account.SObjectType.getDescribe().fields.getMap().keySet();

			Set<String> multipliers = new Set<String>();

			for (String field : allFields) {
				if (field.endsWith('_multiplier__c')) {
					multipliers.add(field);
				}
			}


			String accountQuery = String.format(
				'SELECT {0} FROM Account WHERE Id =: id',
				new List<String>{
					String.join(multipliers, ',')
				}
			);

			Account account = Database.queryWithBinds(
				accountQuery,
				new Map<String, Object>{
					'id' => accountId
				},
				AccessLevel.SYSTEM_MODE
			);

			this.matrix = new Map<String, Decimal>();

			for(String multiplierField : multipliers) {
				Decimal multiplierValue = (Decimal) account.get(multiplierField);

				this.matrix.put(
					multiplierField,
					Optional.of(multiplierValue, 1)
				);
			}
		}
	}
}