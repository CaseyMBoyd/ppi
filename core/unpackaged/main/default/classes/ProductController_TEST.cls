/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 01.07.2024
 **/

@IsTest
private class ProductController_TEST {
	@IsTest
	static void testBehavior() {
		// given
		b2btd.xAccount account = new b2btd.xAccount();
		account.persist();

		b2btd.xWebstore store = new b2btd.xWebstore();
		store.persist();

		b2btd.xProduct masterProduct = new b2btd.xProduct().productCode('MASTER_12345');
		masterProduct.set('Hub_Series__c', 'PXT30');
		masterProduct.persist();

		b2btd.xProduct bushingProduct = new b2btd.xProduct()
			.name('BUSHING_12345')
			.productCode('BUSHING_12345');

		bushingProduct.set('Material__c', 'Rubber')
				.set('Hub_Series__c', 'PXT30')
				.set('Bore__c', 1.00);

		b2btd.xEntitlementPolicy policy = new b2btd.xEntitlementPolicy();
		b2btd.xEntitlementProduct entitlementProduct = new b2btd.xEntitlementProduct(bushingProduct, policy);
		entitlementProduct.persist();

		b2btd.xProductCatalog catalog = new b2btd.xProductCatalog();
		catalog.persist();

		b2btd.xProductCategory category = new b2btd.xProductCategory(catalog.id)
			.name(ProductController.BUSHINGS_CATEGORY_NAME);
		category.persist();

		b2btd.xProductCategory categoryBushingsRelated = new b2btd.xProductCategory(catalog.id)
			.name('Drum Pulleys');

		categoryBushingsRelated.persist();

		insert new ProductCategoryProduct(
			ProductId = bushingProduct.id,
			ProductCategoryId = category.id
		);
		insert new ProductCategoryProduct(
			ProductId = masterProduct.id,
			ProductCategoryId = categoryBushingsRelated.id
		);

		DI.Mock mock = DI.mock(BuyerContext.class);
		mock.startStubbing();
		mock.when(BuyerContext.getInstance().getEffectiveAccountId()).thenReturn(account.id);
		mock.when(BuyerContext.getInstance().getEffectiveAccount()).thenReturn(account.getRecord());
		mock.when(BuyerContext.getInstance().getWebstore()).thenReturn(store.getRecord());
		mock.stopStubbing();

		EntitledProductService.BuyerRecords mockBuyerRecords = new EntitledProductService.BuyerRecords();
		mockBuyerRecords.policies = new List<CommerceEntitlementBuyerGroup>{
			new CommerceEntitlementBuyerGroup(
				PolicyId = policy.id
			)
		};

		mock = DI.mock(EntitledProductService.class);
		mock.startStubbing();
		mock.when(EntitledProductService.getInstance().fetchBuyerRecords(store.id, account.id)).thenReturn(mockBuyerRecords);
		mock.stopStubbing();

		// when
		List<ProductController.PicklistWrapper> actualResults = ProductController.getBushingsForProduct(masterProduct.id);

		// then
		Assert.areEqual(1, actualResults.size());
		Assert.areEqual(bushingProduct.getRecord().get('Material__c'), actualResults[0].material);
		Assert.areEqual(bushingProduct.getRecord().get('Bore__c'), actualResults[0].bore);
		Assert.areEqual(bushingProduct.id, actualResults[0].value);
	}
}